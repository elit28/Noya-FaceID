#!/usr/bin/env python3
"""Génère le fond de la fenêtre d'installation (DMG) : packaging/dmg/background.png (660 × 400)
et background@2x.png (1320 × 800, écrans Retina).

Les icônes sont placées par packaging/dmg/settings.py : NOYA Face à (170, 190), Applications à
(490, 190), en 128 px. Nécessite Pillow et la police Inter :
    python3 scripts/generate-dmg-background.py
"""
import pathlib

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "packaging" / "dmg"
WIDTH, HEIGHT = 660, 400
APP_X, APPS_X, ICON_Y = 170, 490, 190
NAVY = (11, 27, 58)
BLUE = (29, 91, 255)
GREY = (96, 106, 128)
FONT_DIR = pathlib.Path("/usr/share/fonts/opentype/inter")


def font(name, size):
    return ImageFont.truetype(str(FONT_DIR / name), size)


def render(scale):
    w, h = WIDTH * scale, HEIGHT * scale
    image = Image.new("RGB", (w, h))
    top, bottom = (255, 255, 255), (232, 238, 249)
    for y in range(h):
        t = y / (h - 1)
        color = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        ImageDraw.Draw(image).line([(0, y), (w, y)], fill=color)
    draw = ImageDraw.Draw(image, "RGBA")

    def s(value):
        return value * scale

    # Titre.
    title = "Installer NOYA Face"
    title_font = font("Inter-SemiBold.otf", s(22))
    tw = draw.textlength(title, font=title_font)
    draw.text(((w - tw) / 2, s(34)), title, font=title_font, fill=NAVY)

    # Flèche de l'app vers Applications.
    y = s(ICON_Y - 6)
    x0, x1 = s(APP_X + 100), s(APPS_X - 104)
    steps = 60
    for i in range(steps):
        t = i / steps
        color = tuple(round(BLUE[c] + (NAVY[c] - BLUE[c]) * t) for c in range(3))
        xa = x0 + (x1 - x0) * i / steps
        xb = x0 + (x1 - x0) * (i + 1) / steps
        draw.line([(xa, y), (xb, y)], fill=color, width=s(4))
    draw.ellipse([x0 - s(2.5), y - s(2.5), x0 + s(2.5), y + s(2.5)], fill=BLUE)
    head = s(14)
    draw.polygon([(x1 + s(6), y), (x1 - head, y - head * 0.8), (x1 - head, y + head * 0.8)], fill=NAVY)

    # Consigne.
    line = "Glissez NOYA Face dans le dossier Applications"
    line_font = font("Inter-Medium.otf", s(15))
    lw = draw.textlength(line, font=line_font)
    draw.text(((w - lw) / 2, s(318)), line, font=line_font, fill=NAVY)
    sub = "Drag NOYA Face to the Applications folder"
    sub_font = font("Inter-Regular.otf", s(12))
    sw = draw.textlength(sub, font=sub_font)
    draw.text(((w - sw) / 2, s(342)), sub, font=sub_font, fill=GREY)
    return image


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    render(1).save(OUT / "background.png", optimize=True)
    render(2).save(OUT / "background@2x.png", optimize=True)
    print("packaging/dmg/background.png et background@2x.png générés.")
