#!/usr/bin/env python3
"""Génère les images de la marque NOYA Face à partir du « N » de NOYA 360.

Source : packaging/brand/noya-n.png (le N du logo de https://noya360.fr, fond transparent).
Produit :
- packaging/AppIcon.png (1024 × 1024) : carré arrondi clair, cadre façon Face ID bleu nuit, N bleu ;
- packaging/brand/BrandN.png : silhouette du N pour l'icône modèle de la barre des menus.

Nécessite Pillow :
    python3 -m pip install Pillow
    python3 scripts/generate-app-icon.py
"""
import math
import pathlib

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "packaging" / "brand" / "noya-n.png"
SS = 4  # suréchantillonnage pour des bords nets
SIZE = 1024
BODY = 824  # gabarit des icônes macOS : carré de 824 px centré
OFFSET = (SIZE - BODY) // 2
RADIUS = 185
# Fond clair : le N bleu de NOYA 360 garde ses ombres bleu nuit, comme sur le site.
TOP = (0xFF, 0xFF, 0xFF)
BOTTOM = (0xE6, 0xEC, 0xF7)
FRAME = (0x0B, 0x1B, 0x3A, 235)  # bleu nuit du mot NOYA


def rounded_mask(size, box, radius):
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=radius, fill=255)
    return mask


def background():
    big = SIZE * SS
    gradient = Image.new("RGB", (1, big))
    for y in range(big):
        t = y / (big - 1)
        gradient.putpixel((0, y), tuple(round(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3)))
    gradient = gradient.resize((big, big))
    mask = rounded_mask(big, (OFFSET * SS, OFFSET * SS, (OFFSET + BODY) * SS - 1, (OFFSET + BODY) * SS - 1), RADIUS * SS)
    layer = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    layer.paste(gradient, (0, 0), mask)
    return layer


def face_frame(big):
    """Coins du cadre façon Face ID, dans la grille de 32 unités de BrandMark.swift."""
    layer = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    unit = BODY * SS / 32
    origin = OFFSET * SS
    width = round(1.25 * unit)
    color = FRAME

    def p(x, y):
        return (origin + x * unit, origin + y * unit)

    def arc(cx, cy, start, end):
        # Pillow trace l'épaisseur vers l'intérieur de la boîte : on l'élargit d'une
        # demi-épaisseur pour que l'arc soit centré sur le tracé des branches.
        r = 2.4 * unit + width / 2
        box = [p(cx, cy)[0] - r, p(cx, cy)[1] - r, p(cx, cy)[0] + r, p(cx, cy)[1] + r]
        draw.arc(box, start, end, fill=color, width=width)

    lo, hi, k = 5.0, 27.0, 5.6  # bords du cadre et longueur des branches
    c = 2.4
    segments = [
        ((lo, lo + c), (lo, lo + k)), ((lo + c, lo), (lo + k, lo)),
        ((hi - k, lo), (hi - c, lo)), ((hi, lo + c), (hi, lo + k)),
        ((hi, hi - k), (hi, hi - c)), ((hi - c, hi), (hi - k, hi)),
        ((lo + k, hi), (lo + c, hi)), ((lo, hi - c), (lo, hi - k)),
    ]
    for a, b in segments:
        draw.line([p(*a), p(*b)], fill=color, width=width)
        for point in (p(*a), p(*b)):
            r = width / 2
            draw.ellipse([point[0] - r, point[1] - r, point[0] + r, point[1] + r], fill=color)
    arc(lo + c, lo + c, 180, 270)
    arc(hi - c, lo + c, 270, 360)
    arc(hi - c, hi - c, 0, 90)
    arc(lo + c, hi - c, 90, 180)
    return layer


def letter(big):
    n = Image.open(SOURCE).convert("RGBA")
    target_w = round(BODY * SS * 0.50)
    target_h = round(n.height * target_w / n.width)
    n = n.resize((target_w, target_h), Image.LANCZOS)
    layer = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    x = (big - target_w) // 2
    y = (big - target_h) // 2 + round(0.02 * big)
    # Halo discret pour détacher le N du fond.
    glow = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    glow.paste((40, 110, 255, 55), (x, y), n.split()[3])
    glow = glow.filter(ImageFilter.GaussianBlur(24 * SS))
    layer.alpha_composite(glow)
    layer.alpha_composite(n, (x, y))
    return layer


def app_icon():
    big = SIZE * SS
    icon = background()
    icon.alpha_composite(face_frame(big))
    icon.alpha_composite(letter(big))
    # Le halo ne doit pas déborder du carré arrondi.
    mask = rounded_mask(big, (OFFSET * SS, OFFSET * SS, (OFFSET + BODY) * SS - 1, (OFFSET + BODY) * SS - 1), RADIUS * SS)
    alpha = ImageChops.multiply(icon.split()[3], mask)
    icon.putalpha(alpha)
    icon = icon.resize((SIZE, SIZE), Image.LANCZOS)
    icon.save(ROOT / "packaging" / "AppIcon.png")


def menu_bar_letter():
    """Silhouette noire du N (seule la transparence compte pour une image modèle)."""
    n = Image.open(SOURCE).convert("RGBA")
    height = 64
    width = round(n.width * height / n.height)
    alpha = n.split()[3].resize((width, height), Image.LANCZOS)
    out = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    out.putalpha(alpha)
    out.save(ROOT / "packaging" / "brand" / "BrandN.png")


if __name__ == "__main__":
    app_icon()
    menu_bar_letter()
    print("packaging/AppIcon.png et packaging/brand/BrandN.png générés.")
