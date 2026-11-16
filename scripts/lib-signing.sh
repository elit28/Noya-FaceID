# Fonctions de signature, chargées par les scripts de construction.
#
# Sans compte Apple Developer, NOYA Face est signée :
#   - avec l'identité locale « NOYA Face Local Signing » si elle existe
#     (créée une fois par scripts/create-signing-identity.sh) : signature stable d'une
#     version à l'autre, donc les autorisations Caméra/Accessibilité sont conservées ;
#   - sinon en ad hoc, avec une exigence désignée réduite à l'identifiant (plus faible :
#     macOS peut redemander les autorisations après une mise à jour).
# Dans les deux cas : Hardened Runtime activé, seul l'entitlement caméra est accordé.

SIGNING_IDENTITY_NAME="NOYA Face Local Signing"
BUNDLE_ID="fr.noya360.noyaface"
SIGNING_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENTITLEMENTS="$SIGNING_LIB_DIR/../packaging/NoyaFace.entitlements"

signing_identity_available() {
    security find-identity -v -p codesigning 2>/dev/null | grep -qF "\"$SIGNING_IDENTITY_NAME\""
}

# sign_app CHEMIN_APP
sign_app() {
    local path="$1"
    if signing_identity_available; then
        codesign --force --options runtime --entitlements "$ENTITLEMENTS" \
            --sign "$SIGNING_IDENTITY_NAME" --identifier "$BUNDLE_ID" --timestamp=none "$path"
    else
        codesign --force --options runtime --entitlements "$ENTITLEMENTS" \
            --sign - --identifier "$BUNDLE_ID" \
            -r="designated => identifier \"$BUNDLE_ID\"" "$path"
    fi
}
