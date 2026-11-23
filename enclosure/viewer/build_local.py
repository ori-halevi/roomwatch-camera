"""Build camera_3d.html: the viewer as one file that opens with a double-click.

Packs models/*.stl (binary STL, exported from camera_enclosure.scad with part="x_*")
into the page as base64 JSON, so no web server is needed.
Usage: python build_local.py
"""
import base64
import glob
import json
import os

here = os.path.dirname(os.path.abspath(__file__))
models = {os.path.basename(f)[:-4]: base64.b64encode(open(f, "rb").read()).decode()
          for f in sorted(glob.glob(os.path.join(here, "models", "*.stl")))}

page = open(os.path.join(here, "index.html"), encoding="utf-8").read()
fetch = 'const packed = await (await fetch("models.json")).json();'
assert fetch in page
page = page.replace(fetch, 'const packed = JSON.parse(document.getElementById("models").textContent);')

out = ('<!doctype html>\n<html lang="he" dir="rtl">\n<head>\n<meta charset="utf-8">\n'
       '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
       '<style>html,body{margin:0}</style>\n</head>\n<body>\n' + page +
       '\n<script type="application/json" id="models">' + json.dumps(models) + '</script>\n'
       '</body>\n</html>\n')
open(os.path.join(here, "camera_3d.html"), "w", encoding="utf-8").write(out)
print(f"camera_3d.html: {len(models)} parts, {len(out) // 1024} KB")
