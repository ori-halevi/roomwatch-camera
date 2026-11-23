"""Build camera_mount.html: the step-by-step camera/holder/carriage animation as one
file that opens with a double-click. Packs the four STLs it needs into the page.
Usage: python build_mount.py
"""
import base64
import json
import os

here = os.path.dirname(os.path.abspath(__file__))
names = ["carriage", "rocker", "screws", "d_camera"]
models = {n: base64.b64encode(open(os.path.join(here, "models", n + ".stl"), "rb").read()).decode() for n in names}
page = open(os.path.join(here, "mount_template.html"), encoding="utf-8").read()
assert "__MODELS__" in page
page = page.replace("__MODELS__", json.dumps(models))
open(os.path.join(here, "camera_mount.html"), "w", encoding="utf-8").write(page)
print("camera_mount.html", len(page), "bytes")
