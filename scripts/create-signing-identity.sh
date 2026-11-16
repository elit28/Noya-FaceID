#!/bin/bash
# À lancer une seule fois sur le Mac qui construit NOYA Face (facultatif).
# Crée un certificat de signature de code auto-signé dans le trousseau de session et
# l'approuve uniquement pour la signature de code. macOS demande votre mot de passe une fois.
# Intérêt : une signature stable d'une version à l'autre, donc les autorisations Caméra et
# Accessibilité ne sont pas redemandées après chaque construction.
# Attention : la clé privée reste dans votre trousseau ; ne l'exportez et ne la partagez jamais.
# Pour l'enlever : Trousseaux d'accès › supprimer « NOYA Face Local Signing ».
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-signing.sh"

if signing_identity_available; then
    echo "L’identité de signature « $SIGNING_IDENTITY_NAME » existe déjà."
    exit 0
fi

KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $SIGNING_IDENTITY_NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$WORK/key.pem" -out "$WORK/cert.pem" -config "$WORK/cert.cnf" 2>/dev/null
PASS="$(openssl rand -hex 16)"
openssl pkcs12 -export -legacy -inkey "$WORK/key.pem" -in "$WORK/cert.pem" -out "$WORK/id.p12" -passout "pass:$PASS" 2>/dev/null \
    || openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" -out "$WORK/id.p12" -passout "pass:$PASS"

security import "$WORK/id.p12" -k "$KEYCHAIN" -P "$PASS" -T /usr/bin/codesign >/dev/null
echo "Validez la demande de macOS pour approuver « $SIGNING_IDENTITY_NAME » (signature de code uniquement)…"
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$WORK/cert.pem"

if signing_identity_available; then
    echo "Identité de signature « $SIGNING_IDENTITY_NAME » créée."
else
    echo "ERREUR : certificat importé mais non valide pour la signature de code." >&2
    exit 1
fi
