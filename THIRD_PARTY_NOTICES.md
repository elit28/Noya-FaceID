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
  - adaptés de `HeyMacApp/AppLock` : `Sources/NoyaFace/AppLock/AppWatcher.swift`, `ShieldController.swift` et `AppLockController.swift` (masquage immédiat de l'app protégée, reprise du premier plan, mode plein écran seul, masque opaque par défaut) ;
  - `scripts/create-signing-identity.sh`, et la base de `scripts/build-app.sh`, `scripts/lib-signing.sh` et `scripts/verify-app.sh`.
- Modifications principales : renommage, retrait du modèle ArcFace (licence), appel direct de `CGSessionCopyCurrentDictionary` sans chargement dynamique de symbole, signature avec Hardened Runtime, traduction des scripts.

### Silent-Face-Anti-Spoofing (MiniFASNetV2)

- Auteur : Minivision AI — licence du dépôt : **Apache-2.0** (`LICENSES/Apache-2.0.txt`)
- Source : <https://github.com/minivision-ai/Silent-Face-Anti-Spoofing>
- Repris :
  - le modèle MiniFASNetV2 (2.7_80x80), converti en Core ML par HeyMac : `Sources/NoyaCore/Resources/AntiSpoof.mlpkgdata` ;
  - trois images d'exemple, non modifiées, utilisées comme références de test : `Tests/NoyaCoreTests/Fixtures` (voir `NOTICE.txt`).
- Remarque : le dépôt d'origine est sous Apache-2.0 et ne précise pas de licence distincte pour les poids du modèle.

### SFace (modèle de reconnaissance)

- Auteurs : Yaoyao Zhong (SFace) ; conversion ONNX : OpenCV Zoo (Chengrui Wang) — licence **Apache-2.0** (`LICENSES/Apache-2.0.txt`)
- Source : <https://github.com/opencv/opencv_zoo/tree/main/models/face_recognition_sface>, fichier `face_recognition_sface_2021dec.onnx` (SHA-256 `0ba9fbfa01b5270c96627c4ef784da859931e02f04419c829e83484087c34e79`)
- Repris : converti en Core ML (précision FP16) par `scripts/convert_sface.py` → `Sources/NoyaCore/Resources/FaceRecognition.mlpkgdata`. Sortie de référence du modèle d'origine pour les tests : `Tests/NoyaCoreTests/Fixtures/sface_reference.json`.
- Remarque : OpenCV Zoo place tous les fichiers de ce répertoire sous Apache-2.0 ; le jeu de données d'entraînement n'y est pas précisé.

### Logo NOYA

- Le « N » de `packaging/brand/noya-n.png` (et les images qui en dérivent : `packaging/AppIcon.png`, `packaging/brand/BrandN.png`) est le logo de NOYA 360 (<https://noya360.fr>). C'est une marque : **il n'est pas couvert par la licence MIT**. Une version dérivée du projet doit utiliser son propre logo.

## Prévus — Planned (not included yet)

- **Glance** — Jonathan Zhou — MIT — <https://github.com/jonnyoo/glance> : portage prévu de la détection de présence réelle multi-indices et des profils. Rien n'est encore inclus.

## Exclus — Deliberately excluded

- **Modèles InsightFace / ArcFace** (`w600k_mbf`, `w600k_r50`, paquets `buffalo_*`) : licence « recherche non commerciale uniquement ». Ils ne sont pas redistribués ; un test et un contrôle de la CI empêchent leur ajout.
