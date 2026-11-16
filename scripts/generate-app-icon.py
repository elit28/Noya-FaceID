#!/usr/bin/env python3
"""Génère packaging/AppIcon.png (1024 × 1024) : le logo NOYA Face, cadre façon Face ID + « N ».

Même géométrie que BrandMark.swift (grille de 32 unités). Nécessite Pillow :
    python3 -m pip install Pillow
    python3 scripts/generate-app-icon.py
"""
import math
import pathlib
import sys

from PIL import Image, ImageDraw

SUPERSAMPLE = 4
SIZE = 1024
# Gabarit des icônes macOS : carré arrondi de 824 px centré dans 1024 px.
BODY = 824
OFFSET = (SIZE - BODY) / 2
RADIUS = 185


def to_px(x, y, scale):
    return (OFFSET + x * BODY / 32) * scale, (OFFSET + y * BODY / 32) * scale


def arc_points(cx, cy, r, start_deg, end_deg, steps=24):
    """Points d'un arc (degrés, sens horaire, repère y vers le bas)."""
    return [
        (cx + r * math.cos(math.radians(start_deg + (end_deg - start_deg) * i / steps)),
         cy + r * math.sin(math.radians(start_deg + (end_deg - start_deg) * i / steps)))
        for i in range(steps + 1)
    ]


def stroke(draw, points, width, scale):
    """Trait à extrémités et jonctions arrondies."""
    pixels = [to_px(x, y, scale) for x, y in points]
    w = width * BODY / 32 * scale
    draw.line(pixels, fill="white", width=round(w), joint="curve")
    for px, py in pixels:
        draw.ellipse((px - w / 2, py - w / 2, px + w / 2, py + w / 2), fill="white")


def main():
    s = SUPERSAMPLE
    image = Image.new("RGBA", (SIZE * s, SIZE * s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle(
        (OFFSET * s, OFFSET * s, (OFFSET + BODY) * s, (OFFSET + BODY) * s),
        radius=RADIUS * s, fill=(0x14, 0x14, 0x16, 255),
    )
    corners = [
        [(8, 12.5), (8, 10)] + arc_points(10, 10, 2, 180, 270) + [(12.5, 8)],
        [(19.5, 8), (22, 8)] + arc_points(22, 10, 2, 270, 360) + [(24, 12.5)],
        [(24, 19.5), (24, 22)] + arc_points(22, 22, 2, 0, 90) + [(19.5, 24)],
        [(12.5, 24), (10, 24)] + arc_points(10, 22, 2, 90, 180) + [(8, 19.5)],
    ]
    for corner in corners:
        stroke(draw, corner, 1.8, s)
    stroke(draw, [(12.75, 20), (12.75, 12), (19.25, 20), (19.25, 12)], 2.1, s)

    output = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "packaging/AppIcon.png")
    image.resize((SIZE, SIZE), Image.LANCZOS).save(output)
    print(f"Icône écrite : {output}")


if __name__ == "__main__":
    main()
