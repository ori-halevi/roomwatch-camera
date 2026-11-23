# Development notes

What was measured, what broke, and why the firmware and the enclosure look the way they do. Read this before changing power or camera code: most of the odd-looking lines in `src/main.c` exist because of something below.

- [Architecture decisions](#architecture-decisions)
- [Hardware facts](#hardware-facts)
- [Firmware](#firmware)
- [Power: measurements and what moved the needle](#power-measurements-and-what-moved-the-needle)
- [Bugs worth knowing about](#bugs-worth-knowing-about)
- [Charging and the battery gauge](#charging-and-the-battery-gauge)
- [Enclosure v10: what went wrong](#enclosure-v10-what-went-wrong)
- [Build environment notes](#build-environment-notes)

---

## Architecture decisions

| Decision | Why |
|---|---|
| DIY ESP32, not a commercial battery camera | None offered local-only viewing plus instant wake. No cloud, no vendor app, no recording, no audio. |
| Stay associated to Wi-Fi + automatic light sleep | Viewing is instant (open the page, picture appears). Deep sleep or ESP-NOW polling would save more power but add seconds of wake-up. A 10 Ah battery makes this affordable. |
| HTTP + MJPEG, not RTSP | The browser is the viewer. Nothing to install. |
| Raw LiPo + TP4056, no power bank | Power banks switch off at low current draw. |
| Live view stops after 180 s | A forgotten browser tab would otherwise empty the battery. |
| Pure ESP-IDF, not Arduino | The prebuilt Arduino-ESP32 libs are compiled without `CONFIG_PM_ENABLE` and tickless idle, so automatic light sleep is impossible there. The first (Arduino) firmware is kept in `archive/stage2a-arduino/`. |

Usage profile it was designed for: about one minute of viewing every two days. At that rate the stream costs ~1.7 mAh/day and **idle current decides everything**.

## Hardware facts

- **Seeed XIAO ESP32S3 Sense**: ESP32-S3R8, 8 MB flash, 8 MB octal PSRAM. Battery pads (`BAT+`/`BAT−`) are on the back, right of centre. User LED is GPIO21, active low.
- **Camera**: OV2640, 120°, on a 75 mm flex (the kit's stock OV3660 also works with this firmware). Pins on the Sense board: XCLK 10, SDA 40, SCL 39, D0–D7 = 15, 17, 18, 16, 14, 12, 11, 48, VSYNC 38, HREF 47, PCLK 13. **There is no PWDN pin** (tied to GND on the board) and the camera LDOs can't be switched off.
- **Battery**: 10,000 mAh 1S LiPo with a protection board.
- **Charger**: TP4056 USB-C module with DW01 + FS8205 protection (the chip on these clones is a CSM4056).
- **Battery sense**: 2 × 220 kΩ divider into D0 (GPIO1, ADC1 channel 0). About 9.5 µA, which is noise next to the idle current.
- **Do not power the XIAO from the battery through the 5V/VUSB pin.** It drops too much voltage to run, and plugging in USB at the same time pushes 5 V into the LiPo. Use the BAT pads.

## Firmware

`src/main.c` (ESP-IDF), `src/history.c` (event log in flash), `src/index.html` (dashboard, embedded into the binary).

**Boot:** NVS → power management (`max 240 / min 40 MHz`, light sleep on) → Wi-Fi STA in modem power-save → HTTP server → status task. The camera sensor is **not** touched until the first view (see the XCLK bug below).

**Endpoints**

| Path | What |
|---|---|
| `/` | Dashboard |
| `/stream` | MJPEG, stops after 180 s. Runs in its own task, so the rest of the server keeps answering. A second viewer gets 503. |
| `/capture` | One JPEG (503 while someone is streaming) |
| `/api/status` | JSON: battery mV, RSSI, uptime, sleep share, firmware version, chip temperature, … |
| `/api/events` | History ring: boots, views (with the viewing device, battery voltage under load and peak chip temperature), captures, hourly battery voltage + sleep share, hourly RSSI / chip temperature / Wi-Fi drops, Wi-Fi drops and recoveries (time offline), charges, updates. Record layout in `src/history.h`. |
| `POST /api/charged` | Mark "charged now" (also detected automatically from a +150 mV jump) |
| `POST /api/orient` | Image rotation / mirror |
| `POST /update?key=…` | OTA firmware update (key from `secrets.h`) |
| `/log`, `/stats`, `/tasks`, `/set` | Diagnostics: ESP log ring buffer, PM profiling, task list, live power-save tuning |

**Partitions:** two 3 MB OTA slots with rollback (an image is marked valid only after it reaches Wi-Fi), a 256 KB `history` partition (16-byte records, survives a flat battery), NVS.

**Wi-Fi reconnect** backs off 2, 4, 8, 16, 32 s, then every 60 s, so a router outage doesn't drain the battery.

## Power: measurements and what moved the needle

Share of time the chip spends in light sleep, battery only (from `CONFIG_PM_PROFILING` via `/stats`):

| Setup | Asleep |
|---|---|
| Far from the router, RSSI −78 dBm | ~40 % (weak signal keeps the radio awake) |
| Near the router, RSSI −61, max-modem, listen interval 10 | 79 % |
| + shorter active windows, beacon-lost optimisation, idle CPU 80 MHz | 82 % |
| **min-modem (wake every DTIM)** | **85 %**, pages load in ~0.15 s |
| + `FREERTOS_UNICORE` | **86 %** |

Counter-intuitively, min-modem beat max-modem here: each wake is ~7 ms instead of 26–56 ms. The ESP32-S3 has no beacon-wakeup / MAC power-down, so the remaining ~13 % awake time is the radio. The router's DTIM period (1 here) is the largest remaining lever.

**Battery drain test** (hourly ADC readings, 256-sample average, linear fit):

| Phase | Duration | Slope |
|---|---|---|
| Sensor never started since boot | 26 h | −3.3 ± 1.1 mV/day |
| After one capture | 11 h | −1.3 ± 1.8 mV/day |
| What the old XCLK leak would have shown | | about −36 mV/day |

Rough idle estimate: 2–4 mA, i.e. months per charge.

**Measuring current with a cheap multimeter doesn't work on this board.** The DT-830B's mA range has enough burden voltage to brown the ESP32 out on every Wi-Fi burst (reset reason 9, or a half-hung state where ping answers but HTTP doesn't). The 10 A range doesn't brown it out but is too coarse. The battery-voltage history ended up being the better instrument.

## Bugs worth knowing about

### `esp_camera_deinit()` leaves XCLK running on the ESP32-S3

On the S3, esp32-camera 2.x generates XCLK with the **LCD_CAM peripheral** (`gpio_matrix_out(pin_xclk, CAM_CLK_IDX)`), not LEDC. `esp_camera_deinit()` only calls `ledc_stop()`, which is a no-op here. The sensor keeps getting a 20 MHz clock after "stop" and draws tens of mA.

**Fix:** `stop_camera()` resets GPIO10 to a plain output held low. `esp_camera_init()` re-routes it next time.

### OV2640 software standby hangs the SCCB bus

Writing COM2 bit 4 (standby) to an OV2640 makes it hold SDA low mid-transaction. Every later probe fails (`SCCB_Write Failed addr:0x30 reg:0x09`, then `Camera probe failed 0x106`), and only a power cycle recovers it. Because there is no PWDN pin, a reset or an OTA doesn't help. This is a known, unsolved issue (esp32-camera #101, #672). The OV3660's standby (reg 0x3008) works fine.

**Fix:** no standby write for the OV2640. With XCLK stopped (above), it isn't needed.

Lesson from this one: the answer was in `/log` from the first failure. Several hardware theories (cracked flex, bent contacts, a short) cost time before anyone read the log.

### Light sleep with USB plugged in

With light sleep on and USB connected to a PC, USB dies, logs stop and the network half-works. On battery alone, everything is fine. `CONFIG_USJ_NO_AUTO_LS_ON_CONNECTION` doesn't reliably prevent it (it only holds a lock while USB SOF packets arrive, and Windows suspends an idle port). For USB debugging, build the `debug` env (`-DUSE_LIGHT_SLEEP=0`). Flashing a sleeping board over USB needs manual boot mode: hold **B**, tap **R**, release **B**.

### LED went dark mid-blink

Light sleep switches GPIOs to their sleep configuration, so a short LED flash was cut off. `set_led()` holds a `NO_LIGHT_SLEEP` lock while the LED is on.

### Wi-Fi drops every hour (open)

The router de-authenticates the camera (reason 7) exactly 62/92/122 minutes after each association: a per-station timer, most likely the WPA group/pairwise rekey being missed during power save. It reconnects in seconds and costs about 3 mAh/day. The clean fix is on the router (rekey interval 86400 s or off), not in firmware.

### Smaller findings

- The first frames after `esp_camera_init()` come out green-tinted. The firmware discards 5 warm-up frames.
- Heat: in open air the ESP32-S3 went from 33 to ~61 °C in a 3-minute stream, ~63 °C after back-to-back streams. `/api/status` reports the built-in temperature sensor (current and peak), and the stream stops itself at 75 °C.
- Orientation (rotate/mirror, EXIF values 1–8) is stored on the device and written into `/capture` JPEGs as EXIF, so snapshots sent elsewhere (e.g. Telegram) come out upright too.
- The XIAO Sense's microphone can sits under the plug of long-flex camera modules. With the 75 mm OV2640 module the plug can't seat flat until the can's lid is removed.

### The power switch failed

After about a month the camera vanished from the network twice. The history showed an hourly reading, then nothing at all: no Wi-Fi drop, no reboot record, and switching it off and on produced no boot record either, so the board had no power (a crash or a hang would have rebooted and logged it). It only came back on a USB cable. Measured: 4.02 V at the charger's B+/B−, 4.00 V at OUT+/OUT−, 0 V at the XIAO's BAT pads. Joining the three wires at the slide switch (OUT+, the wire to BAT+, and the divider) brought it straight back. The tiny slide switch had lost contact inside. The fix was to bypass it. Lesson: a power path through a cheap micro slide switch is a single point of failure; a power loss leaves no trace in the device's own log, so measure along the path from the battery forward.

## Charging and the battery gauge

- These TP4056 USB-C clones have **no CC resistors**, so USB-C PD chargers and C-to-C cables don't power them. A plain 5 V USB-A charger with an A-to-C cable works.
- LED: red = charging, blue = full. Charge with the switch **off**, or the camera's load can stop the module from ever reporting "full".
- At the default 1 A the module gets too hot to touch. Hot glue near it softens. The battery stays cool (it's a linear charger; the heat is in the module). Swapping Rprog from 1.2 kΩ to 2.4 kΩ halves the current.
- The dashboard's battery % comes from a LiPo discharge curve (`BATT_CURVE` in `index.html`), with 100 % = 4080 mV (calibrated against a meter on this module's cut-off) and 0 % = 3400 mV. A voltage-based percentage is good to roughly ±5 %. An exact one needs a fuel-gauge chip such as the MAX17048.

## Enclosure v10: what went wrong

The parts printed fine. The model, though, had only been checked in its **final assembled pose**, never along the path each part takes to get there. Building it showed:

1. **The flex slot under the carriage didn't go through.** The groove stopped 1.2 mm short of the room above it, so the camera flex had no way in. The 3D viewer drew the flex straight through solid plastic because it had no collision check. (Fixed in the `.scad`, groove height 5 → 6.5 mm; the STLs here were not regenerated.)
2. **The carriage can't enter the hood rails.** The rail faces are 28 mm apart; the carriage with both tongues is 30.4 mm tall, and the grooves have closed ends. No sequence of moves gets it in. It only went in because the hood wall cracked. Workaround for an existing print: cut off the lower tongue and tilt the carriage in, hanging from the upper one.
3. **Nothing holds the charger against the USB plug's push.** It sits in two edge slots with a 2 mm gap behind it. Hot glue there softens from the charger's heat. A 3 mm EVA foam strip between the board and the battery works.
4. **The Sense board's microphone can blocks the 75 mm camera module's connector**, so the plug sat tilted until the can's lid was removed (the mic isn't used).
5. **The 200 mm back plate is held by only four screws**, at its ends. The middle flexes. It needs at least two more around mid-height.

**Rules for a next version:**

- Write the assembly sequence first, step by step, and check every **insertion path** in the model: clearances along the way, what's already installed and in the way, how fingers and a screwdriver reach.
- Include every non-printed item in that check: the flex (width, the connector end, bend radius), wires and solder joints, plug forces, heat sources next to glue or plastic, foam, screws.
- Anything that slides in rails needs a real entry: an open groove end, a removable cap, or a snap tongue. Check the part's height against the gap numerically.
- Every connector you push into needs a solid stop behind its board.
- The viewer must flag impossible geometry instead of drawing through it, and the step-by-step assembly animation (`enclosure/viewer/camera_mount.html`) should exist and be checked against the real geometry **before** printing.
- No long unsupported spans between fixings.

## Build environment notes

- PlatformIO, platform `espressif32` 8.0.0, ESP-IDF 6.1, toolchain `xtensa-esp-elf` 15.2.
- After editing `sdkconfig.defaults`, delete the generated `sdkconfig.<env>`, or the new defaults are silently ignored.
- PlatformIO ignored `CONFIG_PARTITION_TABLE_SINGLE_APP_LARGE`. The fix is `board_build.partitions = partitions.csv` plus `CONFIG_PARTITION_TABLE_CUSTOM`.
- `board_build.embed_txtfiles = src/index.html` is needed in `platformio.ini` as well as `EMBED_TXTFILES` in `src/CMakeLists.txt`.
- If `managed_components/espressif__esp32-camera` gets corrupted after a failed build (missing `CMakeLists.txt`), delete `managed_components/` and rebuild.
- `#define LIGHT_SLEEP` collides with an enum in the ESP32-S3 ROM headers, hence `USE_LIGHT_SLEEP`.
- `tools/ota.py` sometimes reports `timed out` although the update applied. Check `fw` in `/api/status`.
