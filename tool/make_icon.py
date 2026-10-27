#!/usr/bin/env python3
"""Generates the launcher icon: Spotify's three-wave mark, recoloured violet.

Run from the project root:  python tool/make_icon.py
Requires Pillow (already available in this environment).
"""
from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

GREEN = (29, 185, 84, 255)  # #1DB954, Spotify green
INK = (11, 7, 16, 255)  # near-black waves

SS = 4  # supersample factor
SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
FOREGROUND_SIZES = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}


def wave_mark(size: int, scale: float) -> Image.Image:
    """Three Spotify-style arcs on a transparent canvas."""
    img = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = size * SS / 2

    # Concentric arcs centred below the middle: they read as nested rainbows,
    # which is how the Spotify mark is built. The group is tilted slightly.
    base_r = size * SS * scale
    widths = [0.15, 0.14, 0.13]
    radii = [0.95, 0.72, 0.49]
    tilt = -8  # degrees

    # PIL arcs are drawn on an axis-aligned box, so build the group upright and
    # rotate it afterwards for the slight Spotify tilt.
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    for radius_f, width_f in zip(radii, widths):
        r = base_r * radius_f
        w = max(2, int(base_r * width_f))
        box = [cx - r, cy - r + base_r * 0.42, cx + r, cy + r + base_r * 0.42]
        ld.arc(box, start=203, end=337, fill=INK, width=w)
        # Round the arc ends the way the logo's bars are rounded.
        for ang in (203, 337):
            ex = cx + (r - w / 2) * math.cos(math.radians(ang))
            ey = cy + base_r * 0.42 + (r - w / 2) * math.sin(math.radians(ang))
            ld.ellipse([ex - w / 2, ey - w / 2, ex + w / 2, ey + w / 2], fill=INK)

    layer = layer.rotate(tilt, resample=Image.BICUBIC, center=(cx, cy))
    img.alpha_composite(layer)
    return img.resize((size, size), Image.LANCZOS)


def legacy_icon(size: int) -> Image.Image:
    """Full-bleed violet square for pre-adaptive launchers."""
    img = Image.new("RGBA", (size, size), GREEN)
    mark = wave_mark(size, scale=0.44)
    img.alpha_composite(mark)
    return img


def foreground(size: int) -> Image.Image:
    """Adaptive foreground: waves inside the 66dp safe zone of the 108dp canvas."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mark = wave_mark(size, scale=0.44)
    # Shrink so the mark sits inside the safe zone.
    inner = int(size * 0.74)
    small = mark.resize((inner, inner), Image.LANCZOS)
    off = (size - inner) // 2
    img.alpha_composite(small, (off, off))
    return img


def main() -> None:
    for density, size in SIZES.items():
        folder = os.path.join(RES, f"mipmap-{density}")
        os.makedirs(folder, exist_ok=True)
        legacy_icon(size).save(os.path.join(folder, "ic_launcher.png"))
    for density, size in FOREGROUND_SIZES.items():
        folder = os.path.join(RES, f"mipmap-{density}")
        os.makedirs(folder, exist_ok=True)
        foreground(size).save(os.path.join(folder, "ic_launcher_foreground.png"))

    # Preview at a phone-friendly size for eyeballing.
    legacy_icon(512).save(os.path.join(ROOT, "..", "screenshots", "icon_preview.png"))
    print("Wrote launcher icons for", ", ".join(SIZES))


if __name__ == "__main__":
    main()
