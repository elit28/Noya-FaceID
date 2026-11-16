#!/bin/bash
# Construit l'image disque d'installation de NOYA Face : fond à la marque, icônes placées,
# raccourci Applications. Aucun AppleScript ni Finder : dmgbuild écrit lui-même la mise en page.
# Usage : scripts/build-dmg.sh <fichier.dmg>   (après scripts/build-app.sh)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?Usage : scripts/build-dmg.sh <fichier.dmg>}"
APP="$REPO_ROOT/dist/NOYA Face.app"
DMG_DIR="$REPO_ROOT/packaging/dmg"
[ -d "$APP" ] || { echo "App absente : lancez d'abord scripts/build-app.sh" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

python3 -m venv "$WORK/venv"
"$WORK/venv/bin/pip" install --quiet "dmgbuild==1.6.7"

# Fond net sur les écrans Retina : une seule image TIFF à deux résolutions.
tiffutil -cathidpicheck "$DMG_DIR/background.png" "$DMG_DIR/background@2x.png" -out "$WORK/background.tiff"

rm -f "$OUT"
"$WORK/venv/bin/dmgbuild" -s "$DMG_DIR/settings.py" \
    -D app="$APP" \
    -D background="$WORK/background.tiff" \
    -D icon="$APP/Contents/Resources/AppIcon.icns" \
    "NOYA Face" "$OUT"
hdiutil verify "$OUT"
echo "Image disque prête : $OUT"
