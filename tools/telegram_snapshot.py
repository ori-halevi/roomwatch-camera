"""Send one photo from the living-room camera to Telegram.

Posts one JPEG from the camera to a Telegram chat through the Bot API, with the
battery voltage and signal in the caption. Handy as a launcher in a Telegram bot,
or from Task Scheduler.

Settings: a .env file with BOT_TOKEN=... and OWNER_CHAT_ID=... Its path is taken
from tools/local_settings.py (git-ignored, BOT_ENV = r"...") if that exists,
otherwise from the TELEGRAM_ENV environment variable, otherwise tools/telegram.env.
The camera address works the same way (CAMERA_HOST, default 192.168.1.170).

Usage: pythonw tools/telegram_snapshot.py
"""
import json
import os
import sys
import time
import urllib.request
import uuid
from datetime import datetime
from pathlib import Path

try:  # personal paths, kept out of git
    import local_settings as _local
except ImportError:
    _local = None
CAMERA = "http://" + getattr(_local, "CAMERA_HOST", os.environ.get("CAMERA_HOST", "192.168.1.170"))
BOT_ENV = Path(getattr(_local, "BOT_ENV", os.environ.get("TELEGRAM_ENV", Path(__file__).with_name("telegram.env"))))
# The camera serves one request at a time; while someone watches the live feed a
# snapshot would wait until the feed ends, so give up after this long.
CAPTURE_TIMEOUT = 20


def read_env(path: Path) -> dict[str, str]:
    values = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def telegram(token: str, method: str, fields: dict[str, str], photo: bytes | None = None) -> None:
    boundary = uuid.uuid4().hex
    body = b""
    for name, value in fields.items():
        body += (f"--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"\r\n\r\n"
                 f"{value}\r\n").encode()
    if photo is not None:
        body += (f"--{boundary}\r\nContent-Disposition: form-data; name=\"photo\"; "
                 f"filename=\"living_room.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n").encode()
        body += photo + b"\r\n"
    body += f"--{boundary}--\r\n".encode()
    request = urllib.request.Request(
        f"https://api.telegram.org/bot{token}/{method}", data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})
    urllib.request.urlopen(request, timeout=30).read()


def caption(status: dict | None) -> str:
    parts = [f"📷 Living room · {datetime.now():%d.%m %H:%M}"]
    if status:
        if status.get("mv"):
            parts.append(f"🔋 {status['mv'] / 1000:.2f}V")
        if status.get("rssi"):
            parts.append(f"📶 {status['rssi']} dBm")
    return " · ".join(parts)


def main() -> None:
    env = read_env(BOT_ENV)
    token, chat = env["BOT_TOKEN"], env["OWNER_CHAT_ID"]

    try:
        with urllib.request.urlopen(f"{CAMERA}/api/status", timeout=10) as r:
            status = json.load(r)
    except Exception:
        status = None  # the photo matters more than the caption

    started = time.monotonic()
    try:
        with urllib.request.urlopen(f"{CAMERA}/capture", timeout=CAPTURE_TIMEOUT) as r:
            photo = r.read()
    except Exception as e:
        busy = time.monotonic() - started >= CAPTURE_TIMEOUT - 1
        reason = ("the live feed is open somewhere - close it and try again" if busy and status
                  else f"camera not reachable ({e.__class__.__name__})")
        telegram(token, "sendMessage", {"chat_id": chat, "text": f"❌ No photo: {reason}"})
        sys.exit(1)

    telegram(token, "sendPhoto", {"chat_id": chat, "caption": caption(status)}, photo)


if __name__ == "__main__":
    main()
