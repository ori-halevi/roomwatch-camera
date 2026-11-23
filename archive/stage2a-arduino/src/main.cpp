// Stage 2a: power-saving firmware on the stock Arduino libs.
// - Wi-Fi stays associated in max modem sleep (wakes every 3rd beacon).
// - CPU idles at 80MHz, boosts to 240MHz only while streaming.
// - Camera is initialized only for a viewer and de-initialized afterwards.
// - A stream ends on its own after STREAM_MAX_SECONDS (forgotten tab guard).
// Open http://<ip>/ in a browser; click the image to resume after a timeout.

#include <Arduino.h>
#include <WiFi.h>
#include "esp_camera.h"
#include "esp_http_server.h"
#include "esp_wifi.h"
#include "driver/ledc.h"
#include "secrets.h"

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

#define USER_LED_PIN 21  // active low

static const uint32_t STREAM_MAX_SECONDS = 180;
static const uint32_t IDLE_CPU_MHZ = 80;  // lowest speed Wi-Fi allows
static const uint32_t STREAM_CPU_MHZ = 240;

#define BOUNDARY "frame"
static const char *STREAM_CONTENT_TYPE = "multipart/x-mixed-replace;boundary=" BOUNDARY;
static const char *STREAM_PART = "\r\n--" BOUNDARY "\r\nContent-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n";

static const char INDEX_HTML[] =
    "<!doctype html><html><head><meta name=viewport content='width=device-width'>"
    "<title>Living Room</title></head>"
    "<body style='margin:0;background:#000'>"
    "<img id=v src='/stream' title='Click to resume' "
    "style='width:100%;height:100vh;object-fit:contain;cursor:pointer' "
    "onclick=\"this.src='/stream?'+Date.now()\">"
    "</body></html>";

static bool cameraOn = false;

static bool startCamera() {
    if (cameraOn) return true;

    camera_config_t config = {};
    config.ledc_channel = LEDC_CHANNEL_0;
    config.ledc_timer = LEDC_TIMER_0;
    config.pin_d0 = Y2_GPIO_NUM;
    config.pin_d1 = Y3_GPIO_NUM;
    config.pin_d2 = Y4_GPIO_NUM;
    config.pin_d3 = Y5_GPIO_NUM;
    config.pin_d4 = Y6_GPIO_NUM;
    config.pin_d5 = Y7_GPIO_NUM;
    config.pin_d6 = Y8_GPIO_NUM;
    config.pin_d7 = Y9_GPIO_NUM;
    config.pin_xclk = XCLK_GPIO_NUM;
    config.pin_pclk = PCLK_GPIO_NUM;
    config.pin_vsync = VSYNC_GPIO_NUM;
    config.pin_href = HREF_GPIO_NUM;
    config.pin_sccb_sda = SIOD_GPIO_NUM;
    config.pin_sccb_scl = SIOC_GPIO_NUM;
    config.pin_pwdn = PWDN_GPIO_NUM;
    config.pin_reset = RESET_GPIO_NUM;
    config.xclk_freq_hz = 20000000;
    config.pixel_format = PIXFORMAT_JPEG;
    config.frame_size = FRAMESIZE_VGA;  // 640x480 is plenty to see the room
    config.jpeg_quality = 12;           // 0-63, lower = better quality
    config.fb_count = 2;
    config.fb_location = CAMERA_FB_IN_PSRAM;
    config.grab_mode = CAMERA_GRAB_LATEST;

    esp_err_t err = esp_camera_init(&config);
    if (err != ESP_OK) {
        Serial.printf("Camera init FAILED: 0x%x\n", err);
        return false;
    }
    cameraOn = true;

    sensor_t *s = esp_camera_sensor_get();
    Serial.printf("Camera ON, sensor PID: 0x%x\n", s->id.PID);
    return true;
}

static void stopCamera() {
    if (!cameraOn) return;

    // The XIAO Sense has no PWDN pin, so put the sensor in software standby.
    // esp_camera_init() soft-resets the sensor, which clears this again.
    sensor_t *s = esp_camera_sensor_get();
    if (s->id.PID == OV2640_PID) {
        s->set_reg(s, 0x109, 0x10, 0x10);  // sensor bank COM2: standby
    } else if (s->id.PID == OV3660_PID) {
        s->set_reg(s, 0x3008, 0x40, 0x40);  // SYSTEM CTROL0: power down
    }

    esp_camera_deinit();  // frees the frame buffers, but leaves XCLK running
    ledc_stop(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_0, 0);
    cameraOn = false;
    Serial.println("Camera OFF");
}

static esp_err_t indexHandler(httpd_req_t *req) {
    httpd_resp_set_type(req, "text/html");
    return httpd_resp_send(req, INDEX_HTML, HTTPD_RESP_USE_STRLEN);
}

static esp_err_t captureHandler(httpd_req_t *req) {
    setCpuFrequencyMhz(STREAM_CPU_MHZ);
    esp_err_t res = ESP_FAIL;
    if (startCamera()) {
        camera_fb_t *fb = esp_camera_fb_get();
        if (fb) {
            httpd_resp_set_type(req, "image/jpeg");
            res = httpd_resp_send(req, (const char *)fb->buf, fb->len);
            esp_camera_fb_return(fb);
        }
    }
    if (res != ESP_OK) httpd_resp_send_500(req);
    stopCamera();
    setCpuFrequencyMhz(IDLE_CPU_MHZ);
    return res;
}

static esp_err_t streamHandler(httpd_req_t *req) {
    setCpuFrequencyMhz(STREAM_CPU_MHZ);
    if (!startCamera()) {
        setCpuFrequencyMhz(IDLE_CPU_MHZ);
        httpd_resp_send_500(req);
        return ESP_FAIL;
    }

    esp_err_t res = httpd_resp_set_type(req, STREAM_CONTENT_TYPE);
    Serial.println("Stream client connected");
    uint32_t started = millis();
    uint32_t frames = 0;
    char part[128];
    while (res == ESP_OK) {
        if (millis() - started > STREAM_MAX_SECONDS * 1000) {
            Serial.println("Stream time limit reached");
            break;
        }
        camera_fb_t *fb = esp_camera_fb_get();
        if (!fb) {
            Serial.println("Frame capture failed");
            res = ESP_FAIL;
            break;
        }
        size_t hlen = snprintf(part, sizeof(part), STREAM_PART, fb->len);
        res = httpd_resp_send_chunk(req, part, hlen);
        if (res == ESP_OK) res = httpd_resp_send_chunk(req, (const char *)fb->buf, fb->len);
        esp_camera_fb_return(fb);
        frames++;
    }
    if (res == ESP_OK) httpd_resp_send_chunk(req, nullptr, 0);  // end the response cleanly

    uint32_t secs = (millis() - started) / 1000;
    Serial.printf("Stream ended: %lu frames in %lu s\n", frames, secs);
    stopCamera();
    setCpuFrequencyMhz(IDLE_CPU_MHZ);
    return ESP_OK;
}

static void startServer() {
    httpd_config_t config = HTTPD_DEFAULT_CONFIG();
    httpd_handle_t server = nullptr;
    if (httpd_start(&server, &config) != ESP_OK) {
        Serial.println("HTTP server start FAILED");
        return;
    }
    httpd_uri_t index = {"/", HTTP_GET, indexHandler, nullptr};
    httpd_uri_t capture = {"/capture", HTTP_GET, captureHandler, nullptr};
    httpd_uri_t stream = {"/stream", HTTP_GET, streamHandler, nullptr};
    httpd_register_uri_handler(server, &index);
    httpd_register_uri_handler(server, &capture);
    httpd_register_uri_handler(server, &stream);
}

static void connectWiFi() {
    if (WiFi.status() == WL_CONNECTED) return;
    WiFi.mode(WIFI_STA);
    WiFi.setAutoReconnect(true);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    Serial.print("Connecting to Wi-Fi");
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }
    Serial.printf("\nConnected, RSSI: %d dBm\n", WiFi.RSSI());
}

static const char *psModeName() {
    wifi_ps_type_t ps;
    if (esp_wifi_get_ps(&ps) != ESP_OK) return "n/a";
    switch (ps) {
        case WIFI_PS_NONE: return "none";
        case WIFI_PS_MIN_MODEM: return "min-modem";
        case WIFI_PS_MAX_MODEM: return "max-modem";
        default: return "?";
    }
}

#ifdef POWER_TEST
// Bench test for the multimeter: steps through power states, PHASE_SECONDS each.
// LED stays on for BRIDGE_SECONDS after boot (remove the meter bridge then),
// and blinks N times at the start of phase N.
static const uint32_t BRIDGE_SECONDS = 10;
static const uint32_t PHASE_SECONDS = 60;

static void announcePhase(int n, const char *name) {
    Serial.printf("Phase %d: %s\n", n, name);
    for (int i = 0; i < n; i++) {
        digitalWrite(USER_LED_PIN, LOW);
        delay(250);
        digitalWrite(USER_LED_PIN, HIGH);
        delay(400);
    }
}

static void runPowerTest() {
    digitalWrite(USER_LED_PIN, LOW);
    delay(BRIDGE_SECONDS * 1000);
    digitalWrite(USER_LED_PIN, HIGH);
    delay(3000);

    setCpuFrequencyMhz(IDLE_CPU_MHZ);
    WiFi.mode(WIFI_OFF);

    announcePhase(1, "Wi-Fi off, camera never started");
    delay(PHASE_SECONDS * 1000);

    announcePhase(2, "Wi-Fi off, camera running");
    startCamera();
    delay(PHASE_SECONDS * 1000);

    announcePhase(3, "Wi-Fi off, camera stopped");
    stopCamera();
    delay(PHASE_SECONDS * 1000);

    announcePhase(4, "Wi-Fi connected, max modem sleep");
    connectWiFi();
    WiFi.setSleep(WIFI_PS_MAX_MODEM);
    delay(PHASE_SECONDS * 1000);

    // Long blink: test over, continue into normal operation.
    digitalWrite(USER_LED_PIN, LOW);
    delay(2000);
    digitalWrite(USER_LED_PIN, HIGH);
    Serial.println("Power test done");
}
#endif

void setup() {
    pinMode(USER_LED_PIN, OUTPUT);
    digitalWrite(USER_LED_PIN, HIGH);  // LED off

    Serial.begin(115200);
    delay(2000);  // give the USB serial monitor time to attach
    Serial.println("\n=== Camera stage 2a ===");
    Serial.printf("PSRAM: %lu bytes\n", ESP.getPsramSize());

#ifdef POWER_TEST
    runPowerTest();
#endif

    // Probe the camera once at boot so a bad ribbon shows up immediately.
    if (!startCamera()) return;
    stopCamera();

    setCpuFrequencyMhz(IDLE_CPU_MHZ);
    connectWiFi();
    WiFi.setSleep(WIFI_PS_MAX_MODEM);

    startServer();
    Serial.printf("Open in browser: http://%s/\n", WiFi.localIP().toString().c_str());
}

void loop() {
    static uint32_t lastReport = 0;
    if (millis() - lastReport > 30000) {
        lastReport = millis();
        Serial.printf("[%lu s] Wi-Fi %s, RSSI %d dBm, power save %s, CPU %lu MHz, camera %s\n",
                      millis() / 1000,
                      WiFi.status() == WL_CONNECTED ? "connected" : "DISCONNECTED",
                      WiFi.RSSI(), psModeName(), getCpuFrequencyMhz(),
                      cameraOn ? "on" : "off");
    }
    delay(1000);
}
