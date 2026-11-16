#!/bin/bash
# Vérifie une « NOYA Face.app » construite : signature, Hardened Runtime, entitlements,
# identifiant, ressources, traductions et absence de modèle sous licence restrictive.
set -euo pipefail

APP="${1:?usage : scripts/verify-app.sh « chemin/NOYA Face.app »}"
fail() { echo "ÉCHEC : $*" >&2; exit 1; }

codesign --verify --deep --strict "$APP" || fail "signature invalide"
codesign -d --verbose=2 "$APP" 2>&1 | grep -q "runtime" || fail "Hardened Runtime absent"
ENTITLEMENTS_XML="$(codesign -d --entitlements - --xml "$APP" 2>/dev/null || true)"
echo "$ENTITLEMENTS_XML" | grep -q "com.apple.security.device.camera" || fail "entitlement caméra absent"
if echo "$ENTITLEMENTS_XML" | grep -q "disable-library-validation\|allow-dyld-environment-variables\|allow-unsigned-executable-memory"; then
    fail "exception du Hardened Runtime interdite"
fi
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" = "fr.noya360.noyaface" ] || fail "identifiant inattendu"
[ -d "$APP/Contents/Resources/NoyaFace_NoyaCore.bundle" ] || fail "ressources NoyaCore absentes"
for LANG_CODE in fr en; do
    [ -f "$APP/Contents/Resources/$LANG_CODE.lproj/Localizable.strings" ] || fail "traduction $LANG_CODE absente"
    [ -f "$APP/Contents/Resources/$LANG_CODE.lproj/InfoPlist.strings" ] || fail "InfoPlist.strings $LANG_CODE absent"
done
if find "$APP" -iname "*arcface*" -o -iname "*w600k*" -o -iname "*buffalo*" | grep -q .; then
    fail "modèle InsightFace détecté (licence non commerciale)"
fi
echo "Architectures : $(lipo -archs "$APP/Contents/MacOS/NoyaFace")"
echo "Vérification réussie : $APP"
