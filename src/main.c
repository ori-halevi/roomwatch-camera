// Stage 2b: same behaviour as the Arduino stage 2a firmware, rebuilt on ESP-IDF
// so the chip can use automatic light sleep between Wi-Fi beacons.
// - Wi-Fi stays associated in min modem sleep, waking for every DTIM beacon.
// - Between beacons the CPU light-sleeps; a PM lock keeps it awake only while streaming.
// - Camera is powered up only for a viewer, then put in standby with XCLK stopped.
// - A stream ends on its own after STREAM_MAX_SECONDS (forgotten tab guard).
// - The LED stays dark (it would glow through the enclosure's slit). For
//   diagnostics /set?led=1 turns the heartbeat back on (saved): a flash every
//   HEARTBEAT_SECONDS, once if Wi-Fi is connected, three times if not, and the LED
//   stays on for BRIDGE_SECONDS after boot.
// - USB is dead while the chip light-sleeps, so recent log lines are also kept in
//   RAM and served at /log.
// - Events (boots, views, battery readings...) go to a flash history that survives a
//   flat battery; the dashboard page at / reads it from /api/events.
// - New firmware can be pushed over Wi-Fi: POST the .bin to /update?key=OTA_KEY.
//   A build that never reaches Wi-Fi is rolled back on the next reset.

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "esp_log.h"
#include "esp_event.h"
#include "esp_netif.h"
#include "esp_wifi.h"
#include "esp_pm.h"
#include "esp_system.h"
#include "esp_timer.h"
#include "esp_psram.h"
#include "esp_heap_caps.h"
#include "nvs_flash.h"
#include "nvs.h"
#include "driver/gpio.h"
#include "driver/ledc.h"
#include "driver/temperature_sensor.h"
#include "esp_adc/adc_oneshot.h"
#include "esp_adc/adc_cali.h"
#include "esp_adc/adc_cali_scheme.h"
#include "esp_camera.h"
#include "esp_http_server.h"
#include "esp_netif_sntp.h"
#include "esp_ota_ops.h"
#include "lwip/sockets.h"
#include "history.h"
#include "secrets.h"

static const char *TAG = "camera";

// XIAO ESP32S3 Sense camera pins (from Seeed's wiki).
#define PWDN_GPIO_NUM  -1
#define RESET_GPIO_NUM -1
#define XCLK_GPIO_NUM  10
#define SIOD_GPIO_NUM  40
#define SIOC_GPIO_NUM  39
#define Y9_GPIO_NUM    48
#define Y8_GPIO_NUM    11
#define Y7_GPIO_NUM    12
#define Y6_GPIO_NUM    14
#define Y5_GPIO_NUM    16
#define Y4_GPIO_NUM    18
#define Y3_GPIO_NUM    17
#define Y2_GPIO_NUM    15
#define VSYNC_GPIO_NUM 38
#define HREF_GPIO_NUM  47
#define PCLK_GPIO_NUM  13

#define USER_LED_GPIO 21  // active low

// Battery voltage through a 1:2 divider (two equal resistors) on D0 = GPIO1 = ADC1 ch0.
// With no divider fitted the reading is rejected and the page shows "no probe".
#define BATTERY_ADC_CHANNEL ADC_CHANNEL_0
#define BATTERY_DIVIDER     2
#define BATTERY_LOG_SECONDS 3600
#define CHARGE_JUMP_MV      150  // a rise this big between readings means it was charged

#define FW_VERSION "2d.9"
#define FW_BUILD   31  // bump with FW_VERSION; stored in boot events

#define STREAM_MAX_SECONDS 180
#define TEMP_LIMIT_C 75  // a stream stops if the chip gets this hot
#define LISTEN_INTERVAL    10  // only used if /set switches to max modem (ps=2)
#define BRIDGE_SECONDS     10
#define STATUS_SECONDS     30
#define HEARTBEAT_SECONDS  30
#define IDLE_MAX_FREQ_MHZ   80
#define CAMERA_MAX_FREQ_MHZ 240
#define WARMUP_FRAMES      5   // first frames after power-up are green: auto white balance not settled

// 0 for USB debugging (the "debug" env): the chip never light-sleeps, so the USB
// console keeps working. USB stops working whenever the chip light-sleeps.
#ifndef USE_LIGHT_SLEEP
#define USE_LIGHT_SLEEP 1
#endif

#ifndef OTA_KEY
#error "Define OTA_KEY in include/secrets.h"
#endif

#define BOUNDARY "frame"
static const char *STREAM_CONTENT_TYPE = "multipart/x-mixed-replace;boundary=" BOUNDARY;
static const char *STREAM_PART = "\r\n--" BOUNDARY "\r\nContent-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n";

// The dashboard page, embedded from src/index.html (see src/CMakeLists.txt).
extern const char index_html_start[] asm("_binary_index_html_start");
extern const char index_html_end[] asm("_binary_index_html_end");

#define WIFI_CONNECTED_BIT BIT0
static EventGroupHandle_t s_wifi_events;
static int s_disconnects;
static int s_retries;  // consecutive failed connects, for backoff
static int64_t s_offline_since;  // esp_timer time of the last drop, 0 while online
static esp_timer_handle_t s_reconnect_timer;

static adc_oneshot_unit_handle_t s_adc;
static adc_cali_handle_t s_adc_cali;
static int s_last_battery_mv;

// How the picture should be turned for viewing, as an EXIF orientation (1 = as is,
// 2-8 = mirrored and/or rotated). The page applies it to the live view; single
// photos carry it as an EXIF tag, which browsers and Telegram honour.
static uint8_t s_orient = 1;

// Held while the camera runs: keeps CPU/APB at max (XCLK is derived from APB)
// and blocks light sleep.
static esp_pm_lock_handle_t s_camera_lock;
static bool s_camera_on;
// A stream runs in its own task so the web server keeps answering other requests
// (status, log, the page itself) while someone watches. Only one stream at a time.
static volatile bool s_streaming;

// Light sleep turns GPIOs off, so the LED would go dark mid-flash. Stay awake
// while it is lit.
static esp_pm_lock_handle_t s_led_lock;
static bool s_led_on;
static bool s_led_enabled;  // diagnostics only; off in normal use (NVS "cam"/"led")

static void set_led(bool on) {
    if (on == s_led_on) return;
    if (on) esp_pm_lock_acquire(s_led_lock);
    gpio_set_level(USER_LED_GPIO, on ? 0 : 1);
    if (!on) esp_pm_lock_release(s_led_lock);
    s_led_on = on;
}

// Ring buffer of recent log output, readable over HTTP at /log.
#define LOG_RING_SIZE 8192
static char s_log_ring[LOG_RING_SIZE];
static size_t s_log_head;  // next write position
static bool s_log_wrapped;
static portMUX_TYPE s_log_mux = portMUX_INITIALIZER_UNLOCKED;
static vprintf_like_t s_console_vprintf;

static int log_tee_vprintf(const char *fmt, va_list args) {
    char line[256];
    va_list copy;
    va_copy(copy, args);
    int len = vsnprintf(line, sizeof(line), fmt, copy);
    va_end(copy);
    if (len > (int)sizeof(line) - 1) len = sizeof(line) - 1;

    portENTER_CRITICAL(&s_log_mux);
    for (int i = 0; i < len; i++) {
        s_log_ring[s_log_head++] = line[i];
        if (s_log_head == LOG_RING_SIZE) {
            s_log_head = 0;
            s_log_wrapped = true;
        }
    }
    portEXIT_CRITICAL(&s_log_mux);

    return s_console_vprintf(fmt, args);
}

static esp_err_t log_handler(httpd_req_t *req) {
    // Copy out under the lock so concurrent logging can't tear the snapshot.
    char *copy = heap_caps_malloc(LOG_RING_SIZE, MALLOC_CAP_SPIRAM);
    if (!copy) return httpd_resp_send_500(req);
    size_t len;
    portENTER_CRITICAL(&s_log_mux);
    if (s_log_wrapped) {
        size_t tail = LOG_RING_SIZE - s_log_head;
        memcpy(copy, s_log_ring + s_log_head, tail);
        memcpy(copy + tail, s_log_ring, s_log_head);
        len = LOG_RING_SIZE;
    } else {
        memcpy(copy, s_log_ring, s_log_head);
        len = s_log_head;
    }
    portEXIT_CRITICAL(&s_log_mux);

    httpd_resp_set_type(req, "text/plain; charset=utf-8");
    esp_err_t res = httpd_resp_send(req, copy, len);
    heap_caps_free(copy);
    return res;
}

// Time spent in each power mode since boot (CONFIG_PM_PROFILING). The meter can't
// average light sleep's short wake pulses; the SLEEP share here is the real figure.
static esp_err_t stats_handler(httpd_req_t *req) {
    char *buf = NULL;
    size_t len = 0;
    FILE *f = open_memstream(&buf, &len);
    if (!f) return httpd_resp_send_500(req);
    wifi_ps_type_t ps;
    esp_wifi_get_ps(&ps);
    wifi_config_t cfg;
    esp_wifi_get_config(WIFI_IF_STA, &cfg);
    fprintf(f, "Wi-Fi power save %d (0 none, 1 min, 2 max), listen interval %u\n", ps,
            cfg.sta.listen_interval);
    esp_pm_dump_locks(f);
    fclose(f);
    httpd_resp_set_type(req, "text/plain; charset=utf-8");
    esp_err_t res = httpd_resp_send(req, buf, len);
    free(buf);
    return res;
}

// Idle wake-ups (beacons, heartbeat) don't need 240MHz; the camera does.
static void set_max_freq(int mhz) {
    esp_pm_config_t pm = {.max_freq_mhz = mhz, .min_freq_mhz = 40, .light_sleep_enable = USE_LIGHT_SLEEP};
    ESP_ERROR_CHECK(esp_pm_configure(&pm));
}

// Total light-sleep time since boot, parsed from the PM profiling dump.
static int64_t pm_sleep_us(void) {
    char *buf = NULL;
    size_t len = 0;
    FILE *f = open_memstream(&buf, &len);
    if (!f) return 0;
    esp_pm_dump_locks(f);
    fclose(f);
    long long us = 0;
    char *line = strstr(buf, "\nSLEEP");
    if (line) sscanf(line, "\nSLEEP %*d M %lld", &us);
    free(buf);
    return us;
}

static void battery_init(void) {
    adc_oneshot_unit_init_cfg_t unit = {.unit_id = ADC_UNIT_1};
    if (adc_oneshot_new_unit(&unit, &s_adc) != ESP_OK) return;
    adc_oneshot_chan_cfg_t chan = {.atten = ADC_ATTEN_DB_12, .bitwidth = ADC_BITWIDTH_DEFAULT};
    adc_oneshot_config_channel(s_adc, BATTERY_ADC_CHANNEL, &chan);
    adc_cali_curve_fitting_config_t cali = {
        .unit_id = ADC_UNIT_1, .chan = BATTERY_ADC_CHANNEL, .atten = ADC_ATTEN_DB_12,
        .bitwidth = ADC_BITWIDTH_DEFAULT};
    adc_cali_create_scheme_curve_fitting(&cali, &s_adc_cali);
}

// Battery mV, or 0 if there's no divider (reading outside a LiPo's range).
static int battery_mv(void) {
    if (!s_adc || !s_adc_cali) return 0;
    int sum = 0;
    // 256 samples: the hourly battery-drain test needs a few-mV resolution.
    for (int i = 0; i < 256; i++) {
        int raw = 0, mv = 0;
        adc_oneshot_read(s_adc, BATTERY_ADC_CHANNEL, &raw);
        adc_cali_raw_to_voltage(s_adc_cali, raw, &mv);
        sum += mv;
    }
    int mv = sum * BATTERY_DIVIDER / 256;
    return (mv > 2800 && mv < 4500) ? mv : 0;
}

// CPU time per task since boot - what keeps the chip awake.
static esp_err_t tasks_handler(httpd_req_t *req) {
    char *buf = malloc(2048);
    if (!buf) return httpd_resp_send_500(req);
    vTaskGetRunTimeStats(buf);
    httpd_resp_set_type(req, "text/plain; charset=utf-8");
    esp_err_t res = httpd_resp_sendstr(req, buf);
    free(buf);
    return res;
}

// Power-save tuning without reflashing: /set?ps=0|1|2&li=<beacons>. Not saved -
// a reboot returns to the compiled defaults. /set?led=0|1 switches the diagnostic
// LED heartbeat and is saved.
static esp_err_t set_handler(httpd_req_t *req) {
    char query[64], value[8];
    if (httpd_req_get_url_query_str(req, query, sizeof(query)) != ESP_OK) query[0] = 0;

    if (httpd_query_key_value(query, "led", value, sizeof(value)) == ESP_OK) {
        s_led_enabled = atoi(value) != 0;
        if (!s_led_enabled) set_led(false);
        nvs_handle_t nvs;
        if (nvs_open("cam", NVS_READWRITE, &nvs) == ESP_OK) {
            nvs_set_u8(nvs, "led", s_led_enabled);
            nvs_commit(nvs);
            nvs_close(nvs);
        }
        ESP_LOGI(TAG, "Diagnostic LED %s", s_led_enabled ? "on" : "off");
    }

    if (httpd_query_key_value(query, "ps", value, sizeof(value)) == ESP_OK) {
        int ps = atoi(value);
        if (ps < WIFI_PS_NONE || ps > WIFI_PS_MAX_MODEM) return httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "ps 0-2");
        esp_wifi_set_ps((wifi_ps_type_t)ps);
        ESP_LOGI(TAG, "Power save set to %d", ps);
    }
    if (httpd_query_key_value(query, "li", value, sizeof(value)) == ESP_OK) {
        int li = atoi(value);
        if (li < 1 || li > 100) return httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "li 1-100");
        wifi_config_t cfg;
        esp_wifi_get_config(WIFI_IF_STA, &cfg);
        cfg.sta.listen_interval = li;
        esp_wifi_set_config(WIFI_IF_STA, &cfg);
        ESP_LOGI(TAG, "Listen interval set to %d, reconnecting", li);
        // The listen interval is sent at association, so it needs a reconnect;
        // the disconnect handler reconnects. Reply first - the link drops.
        httpd_resp_sendstr(req, "OK, reconnecting\n");
        vTaskDelay(pdMS_TO_TICKS(200));
        esp_wifi_disconnect();
        return ESP_OK;
    }
    return httpd_resp_sendstr(req, "OK\n");
}

static bool start_camera(void) {
    if (s_camera_on) return true;
    set_max_freq(CAMERA_MAX_FREQ_MHZ);
    esp_pm_lock_acquire(s_camera_lock);

    camera_config_t config = {
        .pin_pwdn = PWDN_GPIO_NUM,
        .pin_reset = RESET_GPIO_NUM,
        .pin_xclk = XCLK_GPIO_NUM,
        .pin_sccb_sda = SIOD_GPIO_NUM,
        .pin_sccb_scl = SIOC_GPIO_NUM,
        .pin_d7 = Y9_GPIO_NUM,
        .pin_d6 = Y8_GPIO_NUM,
        .pin_d5 = Y7_GPIO_NUM,
        .pin_d4 = Y6_GPIO_NUM,
        .pin_d3 = Y5_GPIO_NUM,
        .pin_d2 = Y4_GPIO_NUM,
        .pin_d1 = Y3_GPIO_NUM,
        .pin_d0 = Y2_GPIO_NUM,
        .pin_vsync = VSYNC_GPIO_NUM,
        .pin_href = HREF_GPIO_NUM,
        .pin_pclk = PCLK_GPIO_NUM,
        .xclk_freq_hz = 20000000,
        .ledc_timer = LEDC_TIMER_0,
        .ledc_channel = LEDC_CHANNEL_0,
        .pixel_format = PIXFORMAT_JPEG,
        .frame_size = FRAMESIZE_VGA,  // 640x480 is plenty to see the room
        .jpeg_quality = 12,           // 0-63, lower = better quality
        .fb_count = 2,
        .fb_location = CAMERA_FB_IN_PSRAM,
        .grab_mode = CAMERA_GRAB_LATEST,
    };

    esp_err_t err = esp_camera_init(&config);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Camera init FAILED: 0x%x", err);
        esp_pm_lock_release(s_camera_lock);
        set_max_freq(IDLE_MAX_FREQ_MHZ);
        return false;
    }
    s_camera_on = true;

    sensor_t *s = esp_camera_sensor_get();
    ESP_LOGI(TAG, "Camera ON, sensor PID: 0x%x", s->id.PID);

    for (int i = 0; i < WARMUP_FRAMES; i++) {
        camera_fb_t *fb = esp_camera_fb_get();
        if (fb) esp_camera_fb_return(fb);
    }
    return true;
}

static void stop_camera(void) {
    if (!s_camera_on) return;

    // The XIAO Sense has no PWDN pin, so put the sensor in software standby.
    // esp_camera_init() soft-resets the sensor, which clears this again.
    sensor_t *s = esp_camera_sensor_get();
    // OV2640: COM2 standby hangs the sensor and holds the SCCB bus until power is
    // removed (seen 2026-11-17, also esp32-camera #101/#672). Without it the used
    // sensor idles at ~+30 mA, while a never-started one is near zero - so soft-reset
    // it (COM7 SRST, the same write esp_camera_init() does) back to power-on defaults.
    if (s->id.PID == OV2640_PID) {
        s->set_reg(s, 0x112, 0xFF, 0x80);  // sensor bank COM7: SRST
        vTaskDelay(pdMS_TO_TICKS(10));
    } else if (s->id.PID == OV3660_PID) {
        s->set_reg(s, 0x3008, 0x40, 0x40);  // SYSTEM CTROL0: power down
    }

    esp_camera_deinit();
    // On the ESP32-S3 XCLK comes from the LCD_CAM peripheral, not LEDC, so the
    // driver's ledc_stop() does nothing and the sensor keeps getting its clock
    // (~+30 mA measured 2026-11-18). Unhook the pin and hold it low; the next
    // esp_camera_init() routes it back.
    gpio_reset_pin(XCLK_GPIO_NUM);
    gpio_set_direction(XCLK_GPIO_NUM, GPIO_MODE_OUTPUT);
    gpio_set_level(XCLK_GPIO_NUM, 0);
    s_camera_on = false;
    esp_pm_lock_release(s_camera_lock);
    set_max_freq(IDLE_MAX_FREQ_MHZ);
    ESP_LOGI(TAG, "Camera OFF");
}

// Chip temperature from the built-in sensor (about +-1 C), switched on only for a
// reading. s_temp_peak is the highest value seen since boot.
static temperature_sensor_handle_t s_tsens;
static float s_temp_peak;

static void temp_init(void) {
    temperature_sensor_config_t cfg = TEMPERATURE_SENSOR_CONFIG_DEFAULT(10, 80);
    if (temperature_sensor_install(&cfg, &s_tsens) != ESP_OK) s_tsens = NULL;
}

static float chip_temp(void) {
    float t = 0;
    if (s_tsens && temperature_sensor_enable(s_tsens) == ESP_OK) {
        temperature_sensor_get_celsius(s_tsens, &t);
        temperature_sensor_disable(s_tsens);
    }
    if (t > s_temp_peak) s_temp_peak = t;
    return t;
}

// Last byte of the client's IPv4 address, to tell the viewing devices apart in the
// history (e.g. the PC, a phone, the Telegram script). 0 if unknown.
static uint8_t client_id(httpd_req_t *req) {
    struct sockaddr_storage addr;
    socklen_t len = sizeof(addr);
    if (getpeername(httpd_req_to_sockfd(req), (struct sockaddr *)&addr, &len) != 0) return 0;
    if (addr.ss_family == AF_INET) {
        return ntohl(((struct sockaddr_in *)&addr)->sin_addr.s_addr) & 0xFF;
    }
#if CONFIG_LWIP_IPV6
    if (addr.ss_family == AF_INET6) return ((struct sockaddr_in6 *)&addr)->sin6_addr.s6_addr[15];
#endif
    return 0;
}

static esp_err_t index_handler(httpd_req_t *req) {
    httpd_resp_set_type(req, "text/html; charset=utf-8");
    return httpd_resp_send(req, index_html_start, index_html_end - index_html_start - 1);
}

static esp_err_t status_handler(httpd_req_t *req) {
    wifi_ap_record_t ap;
    int rssi = esp_wifi_sta_get_ap_info(&ap) == ESP_OK ? ap.rssi : 0;
    int64_t up = esp_timer_get_time();
    char json[360];
    snprintf(json, sizeof(json),
             "{\"fw\":\"%s\",\"uptime\":%lld,\"time\":%lld,\"rssi\":%d,\"mv\":%d,"
             "\"sleep\":%.1f,\"disconnects\":%d,\"events\":%lu,\"stream_max\":%d,"
             "\"reset\":%d,\"orient\":%d,\"temp\":%.1f,\"temp_peak\":%.1f,\"led\":%d}",
             FW_VERSION, (long long)(up / 1000000), (long long)time(NULL), rssi, battery_mv(),
             up ? 100.0 * pm_sleep_us() / up : 0.0, s_disconnects,
             (unsigned long)history_count(), STREAM_MAX_SECONDS, esp_reset_reason(), s_orient, chip_temp(), s_temp_peak, s_led_enabled);
    httpd_resp_set_type(req, "application/json");
    return httpd_resp_sendstr(req, json);
}

static esp_err_t events_handler(httpd_req_t *req) { return history_send_json(req); }

// "Battery was just charged" from the page, for when there's no voltage probe.
static esp_err_t mark_handler(httpd_req_t *req) {
    history_add(EV_CHARGED, battery_mv(), 1);
    return httpd_resp_sendstr(req, "OK\n");
}

// Firmware over Wi-Fi: curl --data-binary @firmware.bin "http://<ip>/update?key=<OTA_KEY>"
static esp_err_t update_handler(httpd_req_t *req) {
    char query[96], key[64];
    if (httpd_req_get_url_query_str(req, query, sizeof(query)) != ESP_OK ||
        httpd_query_key_value(query, "key", key, sizeof(key)) != ESP_OK || strcmp(key, OTA_KEY)) {
        return httpd_resp_send_err(req, HTTPD_403_FORBIDDEN, "bad key");
    }

    const esp_partition_t *target = esp_ota_get_next_update_partition(NULL);
    esp_ota_handle_t ota;
    if (esp_ota_begin(target, OTA_WITH_SEQUENTIAL_WRITES, &ota) != ESP_OK) {
        return httpd_resp_send_500(req);
    }
    ESP_LOGI(TAG, "Firmware update: %d bytes to %s", req->content_len, target->label);

    // Full speed and no sleep while receiving - same lock the camera uses.
    set_max_freq(CAMERA_MAX_FREQ_MHZ);
    esp_pm_lock_acquire(s_camera_lock);

    char *buf = malloc(4096);
    int remaining = req->content_len;
    esp_err_t err = buf ? ESP_OK : ESP_ERR_NO_MEM;
    while (remaining > 0 && err == ESP_OK) {
        int got = httpd_req_recv(req, buf, remaining < 4096 ? remaining : 4096);
        if (got == HTTPD_SOCK_ERR_TIMEOUT) continue;
        if (got <= 0) {
            err = ESP_FAIL;
            break;
        }
        err = esp_ota_write(ota, buf, got);
        remaining -= got;
    }
    free(buf);
    if (err == ESP_OK) err = esp_ota_end(ota);
    else esp_ota_abort(ota);
    if (err == ESP_OK) err = esp_ota_set_boot_partition(target);

    esp_pm_lock_release(s_camera_lock);
    set_max_freq(IDLE_MAX_FREQ_MHZ);

    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Firmware update failed: %s", esp_err_to_name(err));
        return httpd_resp_send_err(req, HTTPD_500_INTERNAL_SERVER_ERROR, esp_err_to_name(err));
    }
    history_add(EV_UPDATE, 0, req->content_len);
    httpd_resp_sendstr(req, "OK, restarting\n");
    ESP_LOGI(TAG, "Firmware update done, restarting");
    vTaskDelay(pdMS_TO_TICKS(500));
    esp_restart();
    return ESP_OK;
}

static void load_orient(void) {
    nvs_handle_t nvs;
    if (nvs_open("cam", NVS_READONLY, &nvs) != ESP_OK) return;
    uint8_t v;
    if (nvs_get_u8(nvs, "orient", &v) == ESP_OK && v >= 1 && v <= 8) s_orient = v;
    if (nvs_get_u8(nvs, "led", &v) == ESP_OK) s_led_enabled = v != 0;
    nvs_close(nvs);
}

// POST /api/orient?o=1..8
static esp_err_t orient_handler(httpd_req_t *req) {
    char query[16], value[4];
    if (httpd_req_get_url_query_str(req, query, sizeof(query)) != ESP_OK ||
        httpd_query_key_value(query, "o", value, sizeof(value)) != ESP_OK) {
        return httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "o=1..8");
    }
    int o = atoi(value);
    if (o < 1 || o > 8) return httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "o=1..8");
    s_orient = o;
    nvs_handle_t nvs;
    if (nvs_open("cam", NVS_READWRITE, &nvs) == ESP_OK) {
        nvs_set_u8(nvs, "orient", s_orient);
        nvs_commit(nvs);
        nvs_close(nvs);
    }
    return httpd_resp_sendstr(req, "OK\n");
}

// Sends a JPEG, inserting an EXIF orientation tag right after the SOI marker when
// the picture needs turning.
static esp_err_t send_jpeg(httpd_req_t *req, const uint8_t *buf, size_t len) {
    if (s_orient == 1 || len < 4 || buf[0] != 0xFF || buf[1] != 0xD8) {
        return httpd_resp_send(req, (const char *)buf, len);
    }
    uint8_t exif[] = {
        0xFF, 0xE1, 0x00, 0x22,                     // APP1, 34 bytes
        'E', 'x', 'i', 'f', 0, 0,
        'M', 'M', 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08,  // big-endian TIFF, IFD at 8
        0x00, 0x01,                                 // one entry
        0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x00, s_orient, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,                     // no next IFD
    };
    esp_err_t res = httpd_resp_send_chunk(req, (const char *)buf, 2);
    if (res == ESP_OK) res = httpd_resp_send_chunk(req, (const char *)exif, sizeof(exif));
    if (res == ESP_OK) res = httpd_resp_send_chunk(req, (const char *)buf + 2, len - 2);
    if (res == ESP_OK) res = httpd_resp_send_chunk(req, NULL, 0);
    return res;
}

static esp_err_t capture_handler(httpd_req_t *req) {
    if (s_streaming) {  // the stream task owns the camera
        httpd_resp_set_status(req, "503 Service Unavailable");
        return httpd_resp_sendstr(req, "Camera busy: a live view is open");
    }
    esp_err_t res = ESP_FAIL;
    if (start_camera()) {
        camera_fb_t *fb = esp_camera_fb_get();
        if (fb) {
            httpd_resp_set_type(req, "image/jpeg");
            res = send_jpeg(req, fb->buf, fb->len);
            history_add(EV_CAPTURE, client_id(req), fb->len);
            esp_camera_fb_return(fb);
        }
    }
    if (res != ESP_OK) httpd_resp_send_500(req);
    stop_camera();
    return res;
}

static void stream_task(void *arg) {
    httpd_req_t *req = arg;
    esp_err_t res = httpd_resp_set_type(req, STREAM_CONTENT_TYPE);
    ESP_LOGI(TAG, "Stream client connected");
    int64_t started = esp_timer_get_time();
    int64_t temp_checked = started;
    unsigned frames = 0;
    uint8_t client = client_id(req);
    float temp_peak = 0;
    char part[128];
    while (res == ESP_OK) {
        int64_t now = esp_timer_get_time();
        if (now - started > (int64_t)STREAM_MAX_SECONDS * 1000000) {
            ESP_LOGI(TAG, "Stream time limit reached");
            break;
        }
        if (now - temp_checked > 5000000) {
            temp_checked = now;
            float t = chip_temp();
            if (t > temp_peak) temp_peak = t;
            if (t >= TEMP_LIMIT_C) {
                ESP_LOGW(TAG, "Stream stopped: chip at %.1f C", t);
                break;
            }
        }
        camera_fb_t *fb = esp_camera_fb_get();
        if (!fb) {
            ESP_LOGE(TAG, "Frame capture failed");
            res = ESP_FAIL;
            break;
        }
        size_t hlen = snprintf(part, sizeof(part), STREAM_PART, (unsigned)fb->len);
        res = httpd_resp_send_chunk(req, part, hlen);
        if (res == ESP_OK) res = httpd_resp_send_chunk(req, (const char *)fb->buf, fb->len);
        esp_camera_fb_return(fb);
        frames++;
    }
    if (res == ESP_OK) httpd_resp_send_chunk(req, NULL, 0);  // end the response cleanly

    unsigned secs = (unsigned)((esp_timer_get_time() - started) / 1000000);
    ESP_LOGI(TAG, "Stream ended: %u frames in %u s", frames, secs);
    history_add(EV_VIEW, secs, frames);
    // Battery voltage while the camera and radio are still busy: the sag against the
    // idle readings shows the battery's internal resistance, i.e. its health over time.
    int load_mv = battery_mv();
    float t_end = chip_temp();
    if (t_end > temp_peak) temp_peak = t_end;
    history_add(EV_VIEW_LOAD, client, (uint32_t)load_mv | (uint32_t)(temp_peak * 10) << 16);
    stop_camera();
    httpd_req_async_handler_complete(req);
    s_streaming = false;
    vTaskDelete(NULL);
}

static esp_err_t stream_handler(httpd_req_t *req) {
    if (s_streaming) {
        httpd_resp_set_status(req, "503 Service Unavailable");
        return httpd_resp_sendstr(req, "Someone is already watching");
    }
    if (!start_camera()) {
        httpd_resp_send_500(req);
        return ESP_FAIL;
    }
    httpd_req_t *copy = NULL;
    if (httpd_req_async_handler_begin(req, &copy) != ESP_OK) {
        stop_camera();
        httpd_resp_send_500(req);
        return ESP_FAIL;
    }
    s_streaming = true;
    if (xTaskCreate(stream_task, "stream", 6144, copy, 5, NULL) != pdPASS) {
        s_streaming = false;
        stop_camera();
        httpd_req_async_handler_complete(copy);
        return ESP_FAIL;
    }
    return ESP_OK;
}

static void start_server(void) {
    httpd_config_t config = HTTPD_DEFAULT_CONFIG();
    config.stack_size = 8192;
    config.max_uri_handlers = 16;
    config.lru_purge_enable = true;  // a stream left open must not lock out new clients
    httpd_handle_t server = NULL;
    if (httpd_start(&server, &config) != ESP_OK) {
        ESP_LOGE(TAG, "HTTP server start FAILED");
        return;
    }
    httpd_uri_t index = {.uri = "/", .method = HTTP_GET, .handler = index_handler};
    httpd_uri_t capture = {.uri = "/capture", .method = HTTP_GET, .handler = capture_handler};
    httpd_uri_t stream = {.uri = "/stream", .method = HTTP_GET, .handler = stream_handler};
    httpd_uri_t log = {.uri = "/log", .method = HTTP_GET, .handler = log_handler};
    httpd_uri_t stats = {.uri = "/stats", .method = HTTP_GET, .handler = stats_handler};
    httpd_uri_t set = {.uri = "/set", .method = HTTP_GET, .handler = set_handler};
    httpd_uri_t tasks = {.uri = "/tasks", .method = HTTP_GET, .handler = tasks_handler};
    httpd_register_uri_handler(server, &index);
    httpd_register_uri_handler(server, &capture);
    httpd_register_uri_handler(server, &stream);
    httpd_register_uri_handler(server, &log);
    httpd_register_uri_handler(server, &stats);
    httpd_register_uri_handler(server, &set);
    httpd_register_uri_handler(server, &tasks);

    httpd_uri_t api[] = {
        {.uri = "/api/status", .method = HTTP_GET, .handler = status_handler},
        {.uri = "/api/events", .method = HTTP_GET, .handler = events_handler},
        {.uri = "/api/charged", .method = HTTP_POST, .handler = mark_handler},
        {.uri = "/api/orient", .method = HTTP_POST, .handler = orient_handler},
        {.uri = "/update", .method = HTTP_POST, .handler = update_handler},
    };
    for (int i = 0; i < sizeof(api) / sizeof(api[0]); i++) httpd_register_uri_handler(server, &api[i]);
}

static void reconnect(void *arg) { esp_wifi_connect(); }

static void wifi_event_handler(void *arg, esp_event_base_t base, int32_t id, void *data) {
    if (base == WIFI_EVENT && id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
    } else if (base == WIFI_EVENT && id == WIFI_EVENT_STA_DISCONNECTED) {
        bool was_connected = xEventGroupGetBits(s_wifi_events) & WIFI_CONNECTED_BIT;
        xEventGroupClearBits(s_wifi_events, WIFI_CONNECTED_BIT);
        wifi_event_sta_disconnected_t *event = (wifi_event_sta_disconnected_t *)data;
        s_disconnects++;
        if (was_connected) {
            history_add(EV_WIFI_DOWN, event->reason, 0);
            s_offline_since = esp_timer_get_time();
        }

        // Back off while the router is away (2, 4, 8 ... 60 s) instead of retrying
        // flat out on battery.
        int delay_s = s_retries < 5 ? 2 << s_retries : 60;
        s_retries++;
        ESP_LOGW(TAG, "Wi-Fi disconnected (reason %d), retry in %d s", event->reason, delay_s);
        esp_timer_stop(s_reconnect_timer);
        esp_timer_start_once(s_reconnect_timer, (uint64_t)delay_s * 1000000);
    } else if (base == IP_EVENT && id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t *event = (ip_event_got_ip_t *)data;
        ESP_LOGI(TAG, "Open in browser: http://" IPSTR "/", IP2STR(&event->ip_info.ip));
        if (s_offline_since) {
            int64_t secs = (esp_timer_get_time() - s_offline_since) / 1000000;
            history_add(EV_WIFI_UP, secs > 65535 ? 65535 : (uint16_t)secs, s_retries);
            s_offline_since = 0;
        }
        s_retries = 0;
        xEventGroupSetBits(s_wifi_events, WIFI_CONNECTED_BIT);
    }
}

static void start_wifi(void) {
    s_wifi_events = xEventGroupCreate();
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_sta();
    esp_timer_create_args_t timer = {.callback = reconnect, .name = "reconnect"};
    ESP_ERROR_CHECK(esp_timer_create(&timer, &s_reconnect_timer));

    // Wall-clock time for the history; syncs once the network is up.
    esp_sntp_config_t sntp = ESP_NETIF_SNTP_DEFAULT_CONFIG("pool.ntp.org");
    esp_netif_sntp_init(&sntp);

    wifi_init_config_t init = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&init));
    ESP_ERROR_CHECK(esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, wifi_event_handler, NULL));
    ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, wifi_event_handler, NULL));

    wifi_config_t config = {0};
    strlcpy((char *)config.sta.ssid, WIFI_SSID, sizeof(config.sta.ssid));
    strlcpy((char *)config.sta.password, WIFI_PASSWORD, sizeof(config.sta.password));
    config.sta.listen_interval = LISTEN_INTERVAL;

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &config));
    ESP_ERROR_CHECK(esp_wifi_start());
    // Measured next to the router: min modem (wake every DTIM, ~7ms each) slept 85% of
    // the time vs. 76-84% for max modem with listen interval 3-20 (26-56ms per wake),
    // and answers in 0.15s instead of 1-3s.
    ESP_ERROR_CHECK(esp_wifi_set_ps(WIFI_PS_MIN_MODEM));
    ESP_LOGI(TAG, "Connecting to Wi-Fi \"%s\"", WIFI_SSID);
}

// Diagnostic heartbeat (only with /set?led=1): every HEARTBEAT_SECONDS the LED
// flashes once if Wi-Fi is connected, three times if not. No flashing at all means
// the chip is hung.
static void blink(int times) {
    if (!s_led_enabled) return;
    for (int i = 0; i < times; i++) {
        set_led(true);
        vTaskDelay(pdMS_TO_TICKS(40));
        set_led(false);
        vTaskDelay(pdMS_TO_TICKS(250));
    }
}

// Hourly battery reading plus the sleep share over that hour.
static void log_battery(void) {
    static int64_t last_us, last_sleep_us;
    int64_t now_us = esp_timer_get_time(), sleep_us = pm_sleep_us();
    int permille = now_us > last_us ? (int)(1000 * (sleep_us - last_sleep_us) / (now_us - last_us)) : 0;
    last_us = now_us;
    last_sleep_us = sleep_us;

    int mv = battery_mv();
    if (mv && s_last_battery_mv && mv - s_last_battery_mv > CHARGE_JUMP_MV) {
        history_add(EV_CHARGED, mv, 0);
    }
    if (mv) s_last_battery_mv = mv;
    history_add(EV_BATTERY, mv, permille);

    // Conditions over the same hour: signal, chip temperature, Wi-Fi drops.
    static int last_disconnects;
    wifi_ap_record_t ap;
    int rssi = esp_wifi_sta_get_ap_info(&ap) == ESP_OK ? ap.rssi : 0;
    int temp_dc = (int)(chip_temp() * 10);
    int drops = s_disconnects - last_disconnects;
    last_disconnects = s_disconnects;
    history_add(EV_HOURLY, (uint16_t)(int16_t)rssi,
                (uint32_t)(temp_dc < 0 ? 0 : temp_dc) | (uint32_t)(drops > 65535 ? 65535 : drops) << 16);
}

static void status_task(void *arg) {
    int beats = 0;
    int64_t next_battery_us = 60 * 1000000LL;  // first reading a minute after boot
    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(HEARTBEAT_SECONDS * 1000));
        bool connected = xEventGroupGetBits(s_wifi_events) & WIFI_CONNECTED_BIT;
        blink(connected ? 1 : 3);

        if (esp_timer_get_time() >= next_battery_us) {
            log_battery();
            next_battery_us += BATTERY_LOG_SECONDS * 1000000LL;
        }

        if (++beats * HEARTBEAT_SECONDS < STATUS_SECONDS) continue;
        beats = 0;
        wifi_ap_record_t ap;
        int rssi = esp_wifi_sta_get_ap_info(&ap) == ESP_OK ? ap.rssi : 0;
        ESP_LOGI(TAG, "[%lld s] Wi-Fi %s, RSSI %d dBm, camera %s, disconnects %d",
                 (long long)(esp_timer_get_time() / 1000000),
                 connected ? "connected" : "DISCONNECTED", rssi, s_camera_on ? "on" : "off",
                 s_disconnects);
    }
}

void app_main(void) {
    s_console_vprintf = esp_log_set_vprintf(log_tee_vprintf);

    gpio_config_t led = {.pin_bit_mask = 1ULL << USER_LED_GPIO, .mode = GPIO_MODE_OUTPUT};
    gpio_config(&led);
    gpio_set_level(USER_LED_GPIO, 1);  // LED off
    ESP_ERROR_CHECK(esp_pm_lock_create(ESP_PM_NO_LIGHT_SLEEP, 0, "led", &s_led_lock));

    ESP_LOGI(TAG, "=== Camera " FW_VERSION " (ESP-IDF, light sleep) ===");
    ESP_LOGI(TAG, "PSRAM: %u bytes, reset reason %d", (unsigned)esp_psram_get_size(),
             esp_reset_reason());

    esp_err_t err = nvs_flash_init();
    if (err == ESP_ERR_NVS_NO_FREE_PAGES || err == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        err = nvs_flash_init();
    }
    ESP_ERROR_CHECK(err);
    history_init();
    load_orient();
    temp_init();
    battery_init();
    s_last_battery_mv = battery_mv();

    set_max_freq(IDLE_MAX_FREQ_MHZ);
    ESP_ERROR_CHECK(esp_pm_lock_create(ESP_PM_CPU_FREQ_MAX, 0, "camera", &s_camera_lock));

    // No boot probe: a started OV2640 can't be put back into standby (see stop_camera),
    // so don't touch the camera until someone actually views it. A bad ribbon shows up
    // in /log on the first capture instead.

    start_wifi();
    start_server();
    xTaskCreate(status_task, "status", 3072, NULL, 1, NULL);

    xEventGroupWaitBits(s_wifi_events, WIFI_CONNECTED_BIT, pdFALSE, pdTRUE, portMAX_DELAY);
    // Reached the network: this firmware is good, don't roll back.
    esp_ota_mark_app_valid_cancel_rollback();
    esp_netif_sntp_sync_wait(pdMS_TO_TICKS(15000));  // so the boot event gets a timestamp
    history_add(EV_BOOT, esp_reset_reason(), FW_BUILD);
    if (s_led_enabled) {
        set_led(true);
        vTaskDelay(pdMS_TO_TICKS(BRIDGE_SECONDS * 1000));
        set_led(false);
    }
    ESP_LOGI(TAG, "Ready");
}
