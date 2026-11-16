#!/usr/bin/env python3
"""Monte la vidéo de présentation (docs/video/noya-face-presentation.mp4, 1920 × 1080, 30 i/s).

Uniquement des visuels réels : icône et fond d'installation du dépôt, capture de l'app
(docs/images/assistant.png). Fondus enchaînés, sans son. Nécessite Pillow, ffmpeg et Inter :
    python3 scripts/make-presentation-video.py
"""
import pathlib
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "video" / "noya-face-presentation.mp4"
POSTER = ROOT / "docs" / "images" / "video-poster.png"
W, H = 1920, 1080
NAVY, BLUE, GREY = (11, 27, 58), (29, 91, 255), (96, 106, 128)
FONTS = pathlib.Path("/usr/share/fonts/opentype/inter")
FADE = 0.6


def font(weight, size):
    return ImageFont.truetype(str(FONTS / f"Inter-{weight}.otf"), size)


def canvas():
    image = Image.new("RGB", (W, H))
    draw = ImageDraw.Draw(image)
    top, bottom = (255, 255, 255), (228, 235, 248)
    for y in range(H):
        t = y / (H - 1)
        draw.line([(0, y), (W, y)], fill=tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return image


def centered(draw, text, y, fnt, fill):
    width = draw.textlength(text, font=fnt)
    draw.text(((W - width) / 2, y), text, font=fnt, fill=fill)


def paste_shadowed(base, image, x, y, radius=40, opacity=70):
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    mask = Image.new("L", image.size, opacity)
    if image.mode == "RGBA":
        mask = image.getchannel("A").point(lambda a: a * opacity // 255)
    shadow.paste((11, 27, 58, 255), (x, y + radius // 2), mask)
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius))
    base.paste(Image.alpha_composite(base.convert("RGBA"), shadow).convert("RGB"))
    base.paste(image, (x, y), image if image.mode == "RGBA" else None)


def icon(size):
    return Image.open(ROOT / "packaging" / "AppIcon.png").convert("RGBA").resize((size, size), Image.LANCZOS)


def slide_intro():
    image = canvas()
    paste_shadowed(image, icon(360), (W - 360) // 2, 170)
    draw = ImageDraw.Draw(image)
    centered(draw, "NOYA Face", 580, font("Bold", 104), NAVY)
    centered(draw, "Votre visage protège votre Mac.", 720, font("Medium", 44), GREY)
    return image


def slide_assistant():
    image = canvas()
    draw = ImageDraw.Draw(image)
    centered(draw, "Configuration guidée", 70, font("Bold", 64), NAVY)
    centered(draw, "Autorisations, puis deux tours de tête — comme sur iPhone.", 160, font("Regular", 34), GREY)
    shot = Image.open(ROOT / "docs" / "images" / "assistant.png").convert("RGBA")
    height = 800
    shot = shot.resize((round(shot.width * height / shot.height), height), Image.LANCZOS)
    paste_shadowed(image, shot, (W - shot.width) // 2, 240, radius=30, opacity=50)
    return image


def slide_features():
    image = canvas()
    draw = ImageDraw.Draw(image)
    centered(draw, "Tout ce qu’il faut, rien de plus", 90, font("Bold", 64), NAVY)
    cards = [
        ("Applications protégées", "Masquées jusqu’à votre visage,", "Touch ID ou mot de passe."),
        ("Verrouillage automatique", "Le Mac se verrouille", "quand vous vous éloignez."),
        ("Déverrouillage de l’écran", "Mode avancé : NOYA Face tape", "votre mot de passe pour vous."),
        ("Île de l’encoche", "Chaque étape s’affiche", "autour de l’encoche."),
    ]
    card_w, card_h, gap = 780, 230, 40
    x0 = (W - (2 * card_w + gap)) // 2
    for index, (title, line1, line2) in enumerate(cards):
        x = x0 + (index % 2) * (card_w + gap)
        y = 260 + (index // 2) * (card_h + gap)
        draw.rounded_rectangle([x, y, x + card_w, y + card_h], radius=28, fill=(255, 255, 255), outline=(214, 222, 238), width=2)
        draw.rounded_rectangle([x + 36, y + 44, x + 44, y + card_h - 44], radius=4, fill=BLUE)
        draw.text((x + 76, y + 44), title, font=font("SemiBold", 42), fill=NAVY)
        draw.text((x + 76, y + 112), line1, font=font("Regular", 32), fill=GREY)
        draw.text((x + 76, y + 154), line2, font=font("Regular", 32), fill=GREY)
    centered(draw, "Le déverrouillage de l’écran saisit votre mot de passe : ce n’est pas Face ID.", 860, font("Regular", 28), GREY)
    return image


def slide_privacy():
    image = canvas()
    draw = ImageDraw.Draw(image)
    centered(draw, "Entièrement local", 300, font("Bold", 96), NAVY)
    for offset, line in enumerate(["Aucune image enregistrée", "Aucune donnée envoyée, aucun compte", "Libre et gratuit — licence MIT"]):
        centered(draw, line, 470 + offset * 80, font("Medium", 44), GREY)
    return image


def slide_install():
    image = canvas()
    draw = ImageDraw.Draw(image)
    centered(draw, "Installation en un geste", 90, font("Bold", 64), NAVY)
    window = Image.open(ROOT / "packaging" / "dmg" / "background@2x.png").convert("RGBA")
    window = window.resize((1188, 720), Image.LANCZOS)
    rounded = Image.new("L", window.size, 0)
    ImageDraw.Draw(rounded).rounded_rectangle([0, 0, window.width - 1, window.height - 1], radius=24, fill=255)
    window.putalpha(rounded)
    # Icône de l'app à son emplacement réel dans la fenêtre (170, 190 sur 660 × 400).
    scale = window.width / 660
    app = icon(round(128 * scale))
    window.alpha_composite(app, (round(170 * scale - app.width / 2), round(190 * scale - app.height / 2)))
    folder = folder_illustration(round(112 * scale))
    window.alpha_composite(folder, (round(490 * scale - folder.width / 2), round(190 * scale - folder.height / 2)))
    labels = ImageDraw.Draw(window)
    label_font = font("Medium", round(13 * scale))
    for x, text in ((170, "NOYA Face"), (490, "Applications")):
        width = labels.textlength(text, font=label_font)
        labels.text((x * scale - width / 2, 262 * scale), text, font=label_font, fill=(30, 30, 34))
    paste_shadowed(image, window, (W - window.width) // 2, 230, radius=30, opacity=60)
    return image


def folder_illustration(size):
    """Dossier stylisé (illustration, pas l'icône système d'Apple)."""
    big = size * 4
    folder = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(folder)
    back, front = (82, 160, 240), (110, 182, 250)
    draw.rounded_rectangle([big * 0.06, big * 0.16, big * 0.46, big * 0.30], radius=big * 0.05, fill=back)
    draw.rounded_rectangle([big * 0.06, big * 0.22, big * 0.94, big * 0.86], radius=big * 0.07, fill=back)
    draw.rounded_rectangle([big * 0.06, big * 0.32, big * 0.94, big * 0.86], radius=big * 0.07, fill=front)
    # Pictogramme « A » des Applications, tracé en lignes.
    cx, cy, half = big * 0.5, big * 0.6, big * 0.13
    width = round(big * 0.035)
    stroke = (255, 255, 255, 235)
    draw.line([(cx - half, cy + half), (cx, cy - half)], fill=stroke, width=width)
    draw.line([(cx + half, cy + half), (cx, cy - half)], fill=stroke, width=width)
    draw.line([(cx - half * 0.55, cy + half * 0.25), (cx + half * 0.55, cy + half * 0.25)], fill=stroke, width=width)
    return folder.resize((size, size), Image.LANCZOS)


def slide_outro():
    image = canvas()
    paste_shadowed(image, icon(240), (W - 240) // 2, 170)
    draw = ImageDraw.Draw(image)
    centered(draw, "Téléchargez NOYA Face", 470, font("Bold", 80), NAVY)
    centered(draw, "github.com/elit28/Noya-FaceID/releases", 590, font("Medium", 40), BLUE)
    centered(draw, "macOS 14 ou plus récent · par NOYA 360 · noya360.fr", 670, font("Regular", 32), GREY)
    centered(draw, "Une webcam n’est pas Face ID : gardez un mot de passe macOS robuste.", 900, font("Regular", 26), GREY)
    return image


SLIDES = [
    (slide_intro, 4.0),
    (slide_assistant, 6.0),
    (slide_features, 8.0),
    (slide_privacy, 4.5),
    (slide_install, 5.5),
    (slide_outro, 5.0),
]


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as work:
        inputs, durations = [], []
        for index, (render, duration) in enumerate(SLIDES):
            path = pathlib.Path(work) / f"slide{index}.png"
            frame = render()
            frame.save(path)
            if index == 0:
                POSTER.parent.mkdir(parents=True, exist_ok=True)
                frame.resize((1280, 720), Image.LANCZOS).save(POSTER, optimize=True)
            inputs += ["-loop", "1", "-t", f"{duration:.2f}", "-i", str(path)]
            durations.append(duration)
        chain, offset, label = [], 0.0, "[0:v]"
        for index in range(1, len(durations)):
            offset += durations[index - 1] - FADE
            out = f"[v{index}]"
            chain.append(f"{label}[{index}:v]xfade=transition=fade:duration={FADE}:offset={offset:.2f}{out}")
            label = out
        chain.append(f"{label}format=yuv420p[out]")
        command = ["ffmpeg", "-y", "-loglevel", "error", *inputs, "-filter_complex", ";".join(chain),
                   "-map", "[out]", "-r", "30", "-c:v", "libx264", "-crf", "20", "-preset", "slow",
                   "-movflags", "+faststart", str(OUT)]
        subprocess.run(command, check=True)
    print(f"{OUT.relative_to(ROOT)} et {POSTER.relative_to(ROOT)} générés.")


if __name__ == "__main__":
    sys.exit(main())
