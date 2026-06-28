#!/usr/bin/env python3
"""Generate app icons from assets/icon-source.png.

Produces (in assets/):
  AppIcon-native.icns     content padded on transparent canvas, rounded corners (HIG-ish)
  AppIcon-fullbleed.icns  source as-is, square corners
  AppIcon.icns            the bundled default (copy of native)
  menubar.png             36x36 colored menu-bar image
  icon-preview.png        side-by-side comparison

Requires: Pillow, and macOS `iconutil`. Run: python3 scripts/make-icons.py
"""
import os, subprocess, shutil
from PIL import Image, ImageDraw

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(REPO, "assets")
SRC = os.path.join(ASSETS, "icon-source.png")
SIZES = [16, 32, 128, 256, 512]

src = Image.open(SRC).convert("RGBA")

# detect the rounded square (lighter than the near-black background)
gray = src.convert("L")
mask = gray.point(lambda p: 255 if p > 24 else 0)
crop = src.crop(mask.getbbox())
side = max(crop.size)
sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
sq.paste(crop, ((side - crop.size[0]) // 2, (side - crop.size[1]) // 2))

def rounded(img, radius_frac=0.225):
    w, h = img.size
    r = int(min(w, h) * radius_frac)
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w - 1, h - 1], radius=r, fill=255)
    out = img.copy()
    out.putalpha(m)
    return out

BASE = 1024
content = int(BASE * 0.82)
native = Image.new("RGBA", (BASE, BASE), (0, 0, 0, 0))
sq_r = rounded(sq.resize((content, content), Image.LANCZOS), 0.225)
off = (BASE - content) // 2
native.paste(sq_r, (off, off), sq_r)
fullbleed = src.resize((BASE, BASE), Image.LANCZOS).convert("RGBA")

def build_icns(base_img, name):
    iconset = os.path.join("/tmp", name + ".iconset")
    os.makedirs(iconset, exist_ok=True)
    for s in SIZES:
        base_img.resize((s, s), Image.LANCZOS).save(os.path.join(iconset, f"icon_{s}x{s}.png"))
        d = s * 2
        base_img.resize((d, d), Image.LANCZOS).save(os.path.join(iconset, f"icon_{s}x{s}@2x.png"))
    out = os.path.join(ASSETS, name + ".icns")
    subprocess.run(["iconutil", "-c", "icns", iconset, "-o", out], check=True)
    return out

n = build_icns(native, "AppIcon-native")
build_icns(fullbleed, "AppIcon-fullbleed")
shutil.copyfile(n, os.path.join(ASSETS, "AppIcon.icns"))  # default = native
native.resize((36, 36), Image.LANCZOS).save(os.path.join(ASSETS, "menubar.png"))

pv = Image.new("RGBA", (256 * 2 + 60, 320), (240, 240, 240, 255))
def place(img, x, label):
    pv.alpha_composite(img.resize((256, 256), Image.LANCZOS), (x, 20))
    ImageDraw.Draw(pv).text((x + 80, 286), label, fill=(20, 20, 20, 255))
place(native, 20, "native (padded)")
place(fullbleed, 256 + 40, "fullbleed")
pv.convert("RGB").save(os.path.join(ASSETS, "icon-preview.png"))
print("Icons written to", ASSETS)
