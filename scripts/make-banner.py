#!/usr/bin/env python3
"""Compose the README hero banner: our logo + wordmark + tagline + "works with" yabai.
Inputs: assets/logo.png, assets/yabai-icon.png. Output: assets/banner.png
Requires Pillow. Run: python3 scripts/make-banner.py
"""
import os
from PIL import Image, ImageDraw, ImageFont

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(REPO, "assets")

W, H = 1600, 900
NAVY = (16, 42, 67)
GRAY = (90, 107, 123)
bg = Image.new("RGB", (W, H), (255, 255, 255))
draw = ImageDraw.Draw(bg)

TITLE_FONT = "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf"
BODY_FONT = "/System/Library/Fonts/SFNSRounded.ttf"
title_f = ImageFont.truetype(TITLE_FONT, 150)
tag_f = ImageFont.truetype(BODY_FONT, 46)
works_f = ImageFont.truetype(BODY_FONT, 40)

def center_text(text, font, y, fill):
    box = draw.textbbox((0, 0), text, font=font)
    w = box[2] - box[0]
    draw.text(((W - w) / 2, y), text, font=font, fill=fill)
    return y + (box[3] - box[1])

# our logo at top
logo = Image.open(os.path.join(ASSETS, "logo.png")).convert("RGBA").resize((180, 180), Image.LANCZOS)
bg.paste(logo, ((W - 180) // 2, 70), logo)

# wordmark + tagline
center_text("yabai-dockstack", title_f, 280, NAVY)
center_text("visual enhancements for yabai on macOS", tag_f, 470, GRAY)
center_text("window switcher · stack indicators · window menu · Dock previews", tag_f, 540, GRAY)

# "works with" + yabai icon
center_text("works with", works_f, 660, GRAY)
yabai = Image.open(os.path.join(ASSETS, "yabai-icon.png")).convert("RGBA").resize((120, 120), Image.LANCZOS)
bg.paste(yabai, ((W - 120) // 2, 730), yabai)

bg.save(os.path.join(ASSETS, "banner.png"))
print("wrote", os.path.join(ASSETS, "banner.png"))
