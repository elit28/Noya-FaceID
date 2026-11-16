#!/bin/bash
# Refuse toute API privée d'Apple, tout chargement dynamique de symbole et tout anti-débogage
# dans le code source. Exception possible uniquement sur une ligne marquée
# « NOYA-API-PRIVEE-AUTORISEE » (module optionnel et isolé, décision documentée).
set -euo pipefail
cd "$(dirname "$0")/.."

PATTERN='SkyLight|PrivateFrameworks|\bSLS[A-Z][A-Za-z]+|\bCGS[A-Z][A-Za-z]+\(|\bdlopen\(|\bdlsym\(|PT_DENY_ATTACH|\bptrace\('
MATCHES="$(grep -rnE "$PATTERN" Sources --include='*.swift' | grep -v 'NOYA-API-PRIVEE-AUTORISEE' || true)"
if [ -n "$MATCHES" ]; then
    echo "API privée ou chargement dynamique interdit :" >&2
    echo "$MATCHES" >&2
    exit 1
fi
echo "Aucune API privée détectée."
