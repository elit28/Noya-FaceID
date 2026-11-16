# Composants tiers — Third-party notices

NOYA Face est distribué sous licence MIT (voir `LICENSE`). Il intègre ou s'appuie sur les composants suivants, dont les licences et avis de copyright sont conservés dans `LICENSES/`.

*NOYA Face is MIT-licensed (see `LICENSE`). It includes or builds on the components below; their licenses and copyright notices are kept in `LICENSES/`.*

## Inclus — Included

### HeyMac

- Auteur : Harshit Maurya — © 2026 — licence **MIT** (`LICENSES/HeyMac-MIT.txt`)
- Source : <https://github.com/iharshitmaurya/HeyMac>, commit `a73667d` (09/11/2026)
- Repris :
  - `Sources/NoyaCore` (ex-`HeyMacCore`) : alignement du visage, pipeline de vérification, classifieur anti-usurpation, stockage chiffré, état du verrouillage ;
  - `Sources/NoyaEngine` (ex-`HeyMacEngine`) : caméra, enrôlement, vérification, protection d'applications ;
  - les tests correspondants (`Tests/NoyaCoreTests`, `Tests/NoyaEngineTests`) ;
  - `scripts/create-signing-identity.sh`, et la base de `scripts/build-app.sh`, `scripts/lib-signing.sh` et `scripts/verify-app.sh`.
- Modifications principales : renommage, retrait du modèle ArcFace (licence), appel direct de `CGSessionCopyCurrentDictionary` sans chargement dynamique de symbole, signature avec Hardened Runtime, traduction des scripts.

### Silent-Face-Anti-Spoofing (MiniFASNetV2)

- Auteur : Minivision AI — licence du dépôt : **Apache-2.0** (`LICENSES/Apache-2.0.txt`)
- Source : <https://github.com/minivision-ai/Silent-Face-Anti-Spoofing>
- Repris :
  - le modèle MiniFASNetV2 (2.7_80x80), converti en Core ML par HeyMac : `Sources/NoyaCore/Resources/AntiSpoof.mlpkgdata` ;
  - trois images d'exemple, non modifiées, utilisées comme références de test : `Tests/NoyaCoreTests/Fixtures` (voir `NOTICE.txt`).
- Remarque : le dépôt d'origine est sous Apache-2.0 et ne précise pas de licence distincte pour les poids du modèle.

## Prévus — Planned (not included yet)

- **Glance** — Jonathan Zhou — MIT — <https://github.com/jonnyoo/glance> : portage prévu de la détection de présence réelle multi-indices et des profils. Rien n'est encore inclus.
- **SFace** (OpenCV Zoo) — Apache-2.0 — <https://github.com/opencv/opencv_zoo> : modèle de reconnaissance en évaluation (jalon J2). Rien n'est encore inclus.

## Exclus — Deliberately excluded

- **Modèles InsightFace / ArcFace** (`w600k_mbf`, `w600k_r50`, paquets `buffalo_*`) : licence « recherche non commerciale uniquement ». Ils ne sont pas redistribués ; un test et un contrôle de la CI empêchent leur ajout.
