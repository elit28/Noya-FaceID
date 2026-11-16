#!/bin/bash
# Construit « NOYA Face.app » dans dist/.
# Usage : scripts/build-app.sh [version] [numéro de build]
#   version          ex. 0.1.0 (CFBundleShortVersionString)
#   numéro de build  entier croissant (CFBundleVersion), 1 par défaut
# NOYA_UNIVERSAL=1 : binaire universel (Apple Silicon + Intel) ; sinon, architecture du Mac.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
PACKAGING="$REPO_ROOT/packaging"
VERSION="${1:-0.1.0}"
BUILD="${2:-1}"
DIST="$REPO_ROOT/dist"
APP="$DIST/NOYA Face.app"
source "$SCRIPT_DIR/lib-signing.sh"

ARCH_FLAGS=()
if [ "${NOYA_UNIVERSAL:-0}" = "1" ]; then
    ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi
if [ "${NOYA_UNIVERSAL:-0}" = "1" ]; then echo "Compilation (release, universelle)…"; else echo "Compilation (release)…"; fi
(cd "$REPO_ROOT" && swift build -c release --product NoyaFace ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"})
BIN="$(cd "$REPO_ROOT" && swift build -c release --show-bin-path ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"})"

echo "Assemblage de ${APP}…"
mkdir -p "$DIST" && touch "$DIST/.metadata_never_index"  # évite que Spotlight indexe cette copie
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/LICENSES"
cp "$BIN/NoyaFace" "$APP/Contents/MacOS/NoyaFace"
# Ressources SwiftPM de NoyaCore (modèles Core ML) : l'app les cherche dans Contents/Resources.
cp -R "$BIN/NoyaFace_NoyaCore.bundle" "$APP/Contents/Resources/"
# Traductions dans le bundle principal : SwiftUI et les invites système les trouvent ainsi.
for LOCALE_DIR in "$PACKAGING"/*.lproj; do
    cp -R "$LOCALE_DIR" "$APP/Contents/Resources/"
done
cp "$REPO_ROOT/LICENSE" "$REPO_ROOT/THIRD_PARTY_NOTICES.md" "$APP/Contents/Resources/"
cp "$REPO_ROOT"/LICENSES/* "$APP/Contents/Resources/LICENSES/"
sed -e "s/__VERSION__/$VERSION/g" -e "s/__BUILD__/$BUILD/g" "$PACKAGING/Info.plist" > "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" >/dev/null

echo "Icône…"
ICONSET="$DIST/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z $size $size "$PACKAGING/AppIcon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) "$PACKAGING/AppIcon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

echo "Signature (Hardened Runtime)…"
sign_app "$APP"
if ! signing_identity_available; then
    echo "remarque : signature ad hoc. Lancez une fois scripts/create-signing-identity.sh pour conserver les autorisations entre deux versions." >&2
fi

"$SCRIPT_DIR/verify-app.sh" "$APP"
echo "Terminé : $APP"
