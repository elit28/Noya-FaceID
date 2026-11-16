#!/bin/bash
# Contrôles d'hygiène du dépôt : aucun secret, aucun modèle InsightFace (licence non
# commerciale), aucun fichier personnel d'Xcode ou du Finder.
set -euo pipefail
cd "$(dirname "$0")/.."
status=0

if git ls-files | grep -iE 'arcface|w600k|buffalo_|glintr|antelopev2' | grep -v '^scripts/' | grep -v '^Tests/.*\.swift$' | grep -v 'Sources/.*\.swift$' | grep -q .; then
    echo "Modèle InsightFace détecté dans le dépôt (licence non commerciale) :" >&2
    git ls-files | grep -iE 'arcface|w600k|buffalo_|glintr|antelopev2' >&2
    status=1
fi

if git grep -nIE -- '-----BEGIN ([A-Z]+ )?PRIVATE KEY-----|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[0-9A-Z]{16}' -- . ':!scripts/check-repository.sh' >/dev/null; then
    echo "Secret potentiel détecté :" >&2
    git grep -nIE -- '-----BEGIN ([A-Z]+ )?PRIVATE KEY-----|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[0-9A-Z]{16}' -- . ':!scripts/check-repository.sh' >&2
    status=1
fi

if git ls-files | grep -E '(^|/)\.DS_Store$|xcuserdata/|\.p12$|\.mobileprovision$|\.cer$' | grep -q .; then
    echo "Fichier personnel ou certificat suivi par Git :" >&2
    git ls-files | grep -E '(^|/)\.DS_Store$|xcuserdata/|\.p12$|\.mobileprovision$|\.cer$' >&2
    status=1
fi

[ "$status" -eq 0 ] && echo "Dépôt propre : aucun secret, aucun modèle sous licence restrictive."
exit "$status"
