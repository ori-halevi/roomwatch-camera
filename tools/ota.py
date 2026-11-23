"""Push firmware to the camera over Wi-Fi.

Usage: python tools/ota.py [firmware.bin] [host]
Used by `pio run -e ota -t upload`. The key comes from include/secrets.h (OTA_KEY).
"""
import os
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
firmware = Path(sys.argv[1] if len(sys.argv) > 1 else ROOT / ".pio/build/xiao_esp32s3_sense/firmware.bin")
host = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("CAMERA_HOST", "192.168.1.170")

match = re.search(r'#define\s+OTA_KEY\s+"([^"]+)"', (ROOT / "include/secrets.h").read_text())
if not match:
    sys.exit("OTA_KEY not found in include/secrets.h")

data = firmware.read_bytes()
print(f"Sending {firmware.name} ({len(data) // 1024} KB) to {host} ...")
request = urllib.request.Request(
    f"http://{host}/update?key={match.group(1)}",
    data=data,
    headers={"Content-Type": "application/octet-stream"},
)
try:
    with urllib.request.urlopen(request, timeout=120) as response:
        print(response.read().decode().strip())
except Exception as e:
    sys.exit(f"Update failed: {e}")
