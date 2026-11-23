#include "history.h"

#include <stdio.h>
#include <string.h>
#include <time.h>
#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"
#include "esp_heap_caps.h"
#include "esp_log.h"
#include "esp_partition.h"

static const char *TAG = "history";

#define PARTITION_SUBTYPE 0x40  // "history" in partitions.csv
#define SECTOR_SIZE       4096
#define EMPTY_SEQ         0xFFFFFFFF  // erased flash

typedef struct {
    uint32_t seq;   // increases forever; the highest one is the newest record
    uint32_t time;  // unix seconds, 0 if the clock wasn't set yet
    uint8_t type;
    uint8_t reserved;
    uint16_t a;
    uint32_t b;
} record_t;

_Static_assert(sizeof(record_t) == 16, "records must tile flash sectors exactly");

#define RECORDS_PER_SECTOR (SECTOR_SIZE / sizeof(record_t))

static const esp_partition_t *s_part;
static uint32_t s_capacity;  // records
static uint32_t s_head;      // next slot to write
static uint32_t s_next_seq = 1;
static uint32_t s_count;
static SemaphoreHandle_t s_mutex;

static bool valid(const record_t *r) { return r->seq != EMPTY_SEQ && r->seq != 0; }

bool history_init(void) {
    s_part = esp_partition_find_first(ESP_PARTITION_TYPE_DATA, PARTITION_SUBTYPE, NULL);
    if (!s_part) {
        ESP_LOGE(TAG, "No history partition");
        return false;
    }
    s_mutex = xSemaphoreCreateMutex();
    s_capacity = s_part->size / sizeof(record_t);

    // Find the newest record; writing resumes in the slot after it.
    record_t *buf = heap_caps_malloc(SECTOR_SIZE, MALLOC_CAP_SPIRAM);
    if (!buf) return false;
    uint32_t newest_seq = 0, newest_slot = 0;
    for (uint32_t off = 0; off < s_part->size; off += SECTOR_SIZE) {
        esp_partition_read(s_part, off, buf, SECTOR_SIZE);
        for (uint32_t i = 0; i < RECORDS_PER_SECTOR; i++) {
            if (!valid(&buf[i])) continue;
            s_count++;
            if (buf[i].seq > newest_seq) {
                newest_seq = buf[i].seq;
                newest_slot = off / sizeof(record_t) + i;
            }
        }
    }
    heap_caps_free(buf);

    if (newest_seq) {
        s_head = (newest_slot + 1) % s_capacity;
        s_next_seq = newest_seq + 1;
    }
    ESP_LOGI(TAG, "%lu records, next seq %lu", (unsigned long)s_count, (unsigned long)s_next_seq);
    return true;
}

void history_add(event_type_t type, uint16_t a, uint32_t b) {
    if (!s_part) return;
    time_t now = time(NULL);
    record_t r = {
        .seq = s_next_seq,
        .time = now > 1700000000 ? (uint32_t)now : 0,  // before SNTP the clock starts at 1970
        .type = type,
        .a = a,
        .b = b,
    };

    xSemaphoreTake(s_mutex, portMAX_DELAY);
    if (s_head % RECORDS_PER_SECTOR == 0) {
        // Entering a sector: erase it, dropping the oldest records it held.
        // Static, not on the stack: callers include small-stack tasks.
        static record_t old[RECORDS_PER_SECTOR];
        uint32_t off = s_head * sizeof(record_t);
        uint32_t dropped = 0;
        if (esp_partition_read(s_part, off, old, sizeof(old)) == ESP_OK) {
            for (uint32_t i = 0; i < RECORDS_PER_SECTOR; i++) dropped += valid(&old[i]);
        }
        esp_partition_erase_range(s_part, off, SECTOR_SIZE);
        s_count -= dropped;
    }
    if (esp_partition_write(s_part, s_head * sizeof(record_t), &r, sizeof(r)) == ESP_OK) {
        s_head = (s_head + 1) % s_capacity;
        s_next_seq++;
        s_count++;
    }
    xSemaphoreGive(s_mutex);
}

uint32_t history_count(void) { return s_count; }

esp_err_t history_send_json(httpd_req_t *req) {
    if (!s_part) return httpd_resp_send_500(req);
    record_t *buf = heap_caps_malloc(SECTOR_SIZE, MALLOC_CAP_SPIRAM);
    char *out = heap_caps_malloc(SECTOR_SIZE, MALLOC_CAP_SPIRAM);
    if (!buf || !out) {
        heap_caps_free(buf);
        heap_caps_free(out);
        return httpd_resp_send_500(req);
    }

    httpd_resp_set_type(req, "application/json");
    httpd_resp_send_chunk(req, "[", 1);
    bool first = true;
    esp_err_t res = ESP_OK;

    // Oldest first: start at the write head (the oldest surviving sector) and wrap.
    xSemaphoreTake(s_mutex, portMAX_DELAY);
    uint32_t start_sector = s_head / RECORDS_PER_SECTOR;
    uint32_t sectors = s_part->size / SECTOR_SIZE;
    xSemaphoreGive(s_mutex);

    for (uint32_t n = 0; n <= sectors && res == ESP_OK; n++) {
        uint32_t sector = (start_sector + n) % sectors;
        xSemaphoreTake(s_mutex, portMAX_DELAY);
        esp_partition_read(s_part, sector * SECTOR_SIZE, buf, SECTOR_SIZE);
        uint32_t head = s_head;
        xSemaphoreGive(s_mutex);

        // The head sector is visited twice: its older tail first, then (after the
        // wrap) its newer start, so the output stays in order.
        uint32_t from = 0, to = RECORDS_PER_SECTOR;
        if (sector == start_sector) {
            uint32_t split = head % RECORDS_PER_SECTOR;
            if (n == 0) from = split;
            else to = split;
        }

        size_t len = 0;
        for (uint32_t i = from; i < to; i++) {
            if (!valid(&buf[i])) continue;
            len += snprintf(out + len, SECTOR_SIZE - len, "%s[%lu,%lu,%u,%u,%lu]", first ? "" : ",",
                            (unsigned long)buf[i].seq, (unsigned long)buf[i].time, buf[i].type,
                            buf[i].a, (unsigned long)buf[i].b);
            first = false;
            if (len > SECTOR_SIZE - 64) {
                res = httpd_resp_send_chunk(req, out, len);
                len = 0;
                if (res != ESP_OK) break;
            }
        }
        if (len && res == ESP_OK) res = httpd_resp_send_chunk(req, out, len);
    }

    if (res == ESP_OK) res = httpd_resp_send_chunk(req, "]", 1);
    if (res == ESP_OK) res = httpd_resp_send_chunk(req, NULL, 0);
    heap_caps_free(buf);
    heap_caps_free(out);
    return res;
}
