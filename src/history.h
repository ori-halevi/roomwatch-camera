// Event history kept in its own flash partition, so it survives a flat battery and
// reboots. Records are appended to a ring; the oldest sector is erased when it fills.
#pragma once

#include <stdbool.h>
#include <stdint.h>
#include "esp_http_server.h"

typedef enum {
    EV_BOOT = 1,       // a = reset reason, b = firmware build (unix time)
    EV_VIEW = 2,       // a = seconds watched, b = frames sent
    EV_CAPTURE = 3,    // b = JPEG bytes
    EV_BATTERY = 4,    // a = battery mV (0 = no probe), b = sleep share over the period, per mille
    EV_WIFI_DOWN = 5,  // a = disconnect reason
    EV_CHARGED = 6,    // a = battery mV; b = 1 when marked by hand from the page
    EV_UPDATE = 7,     // b = bytes of the new firmware
} event_type_t;

bool history_init(void);
void history_add(event_type_t type, uint16_t a, uint32_t b);
uint32_t history_count(void);

// Streams every stored record, oldest first, as a JSON array of
// [seq, unix_time, type, a, b]. unix_time is 0 before the clock was set.
esp_err_t history_send_json(httpd_req_t *req);
