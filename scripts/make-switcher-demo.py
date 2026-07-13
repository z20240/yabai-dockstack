#!/usr/bin/env python3
"""Draw the README illustration for the AltTab-style window switcher: a mock
switcher panel (thumbnail grid, space tags, selection ring) over a desktop-ish
gradient. All window content is fake — no real screenshots, no private data.
Output: assets/demo-window-switcher.png. Requires Pillow.
Run: python3 scripts/make-switcher-demo.py
"""
import os
from PIL import Image, ImageDraw, ImageFont

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "assets", "demo-window-switcher.png")

S = 2                    # supersample, downscaled at the end
FINAL_W = 1520
CELL_W, CELL_H = 252, 204
COLS, GAP, PAD = 5, 12, 22
PANEL_W = COLS * CELL_W + (COLS - 1) * GAP + PAD * 2
PANEL_H = 2 * CELL_H + GAP + PAD * 2
MARGIN_X = (FINAL_W - PANEL_W) // 2
MARGIN_TOP, CAPTION_H = 36, 56
FINAL_H = MARGIN_TOP + PANEL_H + CAPTION_H

W, H = FINAL_W * S, FINAL_H * S
img = Image.new("RGB", (W, H))
d = ImageDraw.Draw(img, "RGBA")

BODY_FONT = "/System/Library/Fonts/SFNSRounded.ttf"
GLYPH_FONT = "/System/Library/Fonts/SFNS.ttf"
title_f = ImageFont.truetype(BODY_FONT, 12 * S)
tag_f = ImageFont.truetype(BODY_FONT, 10 * S)
badge_f = ImageFont.truetype(BODY_FONT, 15 * S)
caption_f = ImageFont.truetype(GLYPH_FONT, 16 * S)

# desktop-ish vertical gradient backdrop
top, bottom = (34, 39, 51), (24, 27, 35)
for y in range(H):
    t = y / H
    d.line([(0, y), (W, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)))

def rr(box, radius, **kw):
    d.rounded_rectangle([c * S for c in box], radius=radius * S, **kw)

def text(xy, s, font, fill, anchor="la"):
    d.text((xy[0] * S, xy[1] * S), s, font=font, fill=fill, anchor=anchor)

# panel
PX, PY = MARGIN_X, MARGIN_TOP
rr((PX, PY, PX + PANEL_W, PY + PANEL_H), 20, fill=(29, 29, 33, 246), outline=(255, 255, 255, 26), width=S)

ACCENT = (52, 120, 246)

def mini_window(box, kind):
    """A fake app window inside the thumbnail area."""
    x0, y0, x1, y1 = box
    dark = kind in ("code", "term", "music")
    bg = {"code": (30, 32, 44), "term": (18, 20, 24), "music": (44, 32, 52),
          "browser": (244, 244, 247), "notes": (250, 245, 231), "chat": (250, 250, 252),
          "mail": (248, 249, 251), "files": (238, 240, 244), "design": (225, 227, 233),
          "docs": (252, 252, 252)}[kind]
    rr((x0, y0, x1, y1), 7, fill=bg)
    bar = (52, 54, 68) if dark else (222, 223, 228)
    rr((x0, y0, x1, y0 + 15), 7, fill=bar)
    d.rectangle([x0 * S, (y0 + 8) * S, x1 * S, (y0 + 15) * S], fill=bar)
    for i, c in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]):
        cx = x0 + 8 + i * 9
        d.ellipse([(cx - 2.6) * S, (y0 + 5) * S, (cx + 2.6) * S, (y0 + 10.2) * S], fill=c)
    cx0, cy0, cx1 = x0 + 10, y0 + 24, x1 - 10
    if kind == "code":
        colors = [(122, 162, 247), (247, 118, 142), (158, 206, 106), (224, 175, 104), (122, 162, 247), (187, 154, 247)]
        for i, c in enumerate(colors):
            wl = [0.55, 0.75, 0.42, 0.66, 0.3, 0.5][i]
            ind = [0, 8, 16, 16, 8, 0][i]
            rr((cx0 + ind, cy0 + i * 12, cx0 + ind + (cx1 - cx0 - ind) * wl, cy0 + i * 12 + 5), 2, fill=c + (220,))
    elif kind == "term":
        for i in range(5):
            wl = [0.5, 0.7, 0.35, 0.62, 0.25][i]
            c = (108, 203, 121) if i % 2 == 0 else (160, 165, 175)
            rr((cx0, cy0 + i * 13, cx0 + (cx1 - cx0) * wl, cy0 + i * 13 + 5), 2, fill=c + (210,))
    elif kind == "browser":
        rr((cx0, cy0, cx1, cy0 + 10), 5, fill=(226, 227, 232))
        rr((cx0, cy0 + 17, cx1, cy0 + 47), 5, fill=(199, 219, 252))
        for i in range(2):
            rr((cx0, cy0 + 54 + i * 11, cx0 + (cx1 - cx0) * (0.9 - i * 0.25), cy0 + 58 + i * 11), 2, fill=(196, 198, 206))
    elif kind == "notes":
        rr((cx0, cy0, cx0 + (cx1 - cx0) * 0.5, cy0 + 7), 2, fill=(212, 170, 60))
        for i in range(4):
            rr((cx0, cy0 + 15 + i * 12, cx0 + (cx1 - cx0) * (0.92 - (i % 2) * 0.2), cy0 + 19 + i * 12), 2, fill=(206, 200, 182))
    elif kind == "chat":
        for i in range(3):
            left = i % 2 == 0
            wl = [0.55, 0.5, 0.62][i]
            bx0 = cx0 if left else cx1 - (cx1 - cx0) * wl
            c = (229, 230, 235) if left else (78, 141, 245)
            rr((bx0, cy0 + i * 22, bx0 + (cx1 - cx0) * wl, cy0 + i * 22 + 15), 7, fill=c)
    elif kind == "music":
        rr((cx0, cy0, cx0 + 52, cy0 + 52), 6, fill=(233, 96, 155))
        rr((cx0 + 62, cy0 + 8, cx1, cy0 + 15), 3, fill=(210, 205, 220))
        rr((cx0 + 62, cy0 + 24, cx0 + 62 + (cx1 - cx0 - 62) * 0.6, cy0 + 30), 3, fill=(160, 155, 175))
        rr((cx0, cy0 + 62, cx1, cy0 + 66), 2, fill=(90, 82, 105))
        rr((cx0, cy0 + 62, cx0 + (cx1 - cx0) * 0.4, cy0 + 66), 2, fill=(233, 96, 155))
    elif kind == "mail":
        for i in range(4):
            d.ellipse([(cx0 + 1) * S, (cy0 + 3 + i * 15) * S, (cx0 + 6) * S, (cy0 + 8 + i * 15) * S],
                      fill=(78, 141, 245) if i < 2 else (208, 210, 216))
            rr((cx0 + 12, cy0 + 2 + i * 15, cx0 + 12 + (cx1 - cx0 - 12) * (0.85 - (i % 3) * 0.12), cy0 + 7 + i * 15), 2,
               fill=(184, 187, 196))
    elif kind == "files":
        for i in range(6):
            fx = cx0 + (i % 3) * 42
            fy = cy0 + (i // 3) * 34
            rr((fx, fy + 4, fx + 30, fy + 26), 4, fill=(120, 178, 255))
            rr((fx, fy, fx + 14, fy + 8), 2, fill=(96, 156, 240))
    elif kind == "design":
        d.ellipse([(cx0 + 6) * S, (cy0 + 6) * S, (cx0 + 48) * S, (cy0 + 48) * S], fill=(174, 129, 255))
        rr((cx0 + 62, cy0 + 14, cx1 - 4, cy0 + 60), 6, fill=(255, 159, 92))
        rr((cx0 + 30, cy0 + 40, cx0 + 92, cy0 + 68), 6, outline=(90, 94, 106), width=S)
    elif kind == "docs":
        rr((cx0, cy0, cx0 + (cx1 - cx0) * 0.6, cy0 + 8), 2, fill=(226, 106, 106))
        for i in range(4):
            rr((cx0, cy0 + 16 + i * 11, cx0 + (cx1 - cx0) * (0.95 - (i % 2) * 0.15), cy0 + 20 + i * 11), 2,
               fill=(200, 202, 208))

CELLS = [
    ("code",    "Code — main.swift",       "S1", (86, 156, 245), "C"),
    ("code",    "Code — api/service.ts",   "S3", (86, 156, 245), "C"),
    ("browser", "Browser — Documentation", "S1", (255, 149, 64), "B"),
    ("term",    "Terminal — ~/project",    "S2", (66, 196, 120), "T"),
    ("chat",    "Chat — Team",             "S2", (58, 190, 196), "K"),
    ("notes",   "Notes — Ideas",           "S4", (238, 196, 74), "N"),
    ("music",   "Music — Now Playing",     "S4", (233, 96, 155), "M"),
    ("files",   "Files — Downloads",       "S5", (150, 158, 176), "F"),
    ("design",  "Design — Mockups",        "S5", (174, 129, 255), "D"),
    ("docs",    "Docs — Draft.md",         "S3", (226, 106, 106), "W"),
]
SELECTED = 1   # second Code window — the "same app, pick the exact window" story

for i, (kind, title, tag, badge_c, badge_ch) in enumerate(CELLS):
    col, row = i % COLS, i // COLS
    x = PX + PAD + col * (CELL_W + GAP)
    y = PY + PAD + row * (CELL_H + GAP)
    sel = i == SELECTED
    rr((x, y, x + CELL_W, y + CELL_H), 12,
       fill=(255, 255, 255, 42 if sel else 16),
       outline=ACCENT if sel else None, width=2 * S if sel else 0)

    tx0, ty0 = x + 10, y + 10
    tx1, ty1 = x + CELL_W - 10, y + CELL_H - 34
    mini_window((tx0, ty0, tx1, ty1), kind)

    # app badge over the thumbnail's bottom-left corner
    bx, by = tx0 + 4, ty1 - 30
    rr((bx, by, bx + 26, by + 26), 7, fill=badge_c)
    text((bx + 13, by + 13.5), badge_ch, badge_f, (255, 255, 255), anchor="mm")

    # space tag pill, top-right
    tag_w = 24
    rr((tx1 - tag_w - 4, ty0 + 4, tx1 - 4, ty0 + 19), 5, fill=(0, 0, 0, 150))
    text((tx1 - 4 - tag_w / 2, ty0 + 11.5), tag, tag_f, (255, 255, 255), anchor="mm")

    # ✕ close button on the selected cell (drawn, not a glyph — font coverage)
    if sel:
        d.ellipse([(tx0 + 2) * S, (ty0 + 2) * S, (tx0 + 20) * S, (ty0 + 20) * S], fill=(88, 90, 98, 235))
        for dx in (-1, 1):
            d.line([((tx0 + 11 - 3.4 * dx) * S, (ty0 + 7.6) * S),
                    ((tx0 + 11 + 3.4 * dx) * S, (ty0 + 14.4) * S)],
                   fill=(235, 236, 240), width=int(1.6 * S))

    # title
    text((x + CELL_W / 2, y + CELL_H - 17), title, title_f, (238, 239, 243, 235), anchor="mm")

caption = "Hold ⌥ + tap Tab to cycle every window on every space  ·  release to switch  ·  Shift reverses  ·  type to search"
text((FINAL_W / 2, MARGIN_TOP + PANEL_H + CAPTION_H / 2 + 2), caption, caption_f, (152, 160, 173), anchor="mm")

img = img.resize((FINAL_W, FINAL_H), Image.LANCZOS)
img.save(OUT)
print("wrote", OUT, f"{FINAL_W}x{FINAL_H}")
