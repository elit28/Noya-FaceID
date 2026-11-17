# Journal des versions — Changelog

## 1.0.2 (novembre 2026)

- Écran verrouillé : la reconnaissance se lance à chaque approche (souris, trackpad, touche, réveil de l'écran), avec 2 essais à chaque fois ; plus de déverrouillage immédiat quand on verrouille devant la caméra (testé).
- Champ du mot de passe vidé avant la saisie automatique (testé).
- Menu « Armer le déverrouillage de l'écran… » quand la saisie automatique est désarmée.

## 1.0.1 (novembre 2026)

- Fenêtre d'installation (DMG) soignée : fond à la marque NOYA, icônes de 128 pt alignées sur une flèche « Glissez NOYA Face dans Applications », fenêtre sans barres, fond Retina. Construite par `scripts/build-dmg.sh` (dmgbuild, sans AppleScript).

## 1.0.0 (novembre 2026)

Première version stable. Détails et limites : [`docs/release-notes/1.0.0.md`](docs/release-notes/1.0.0.md).

- Installateur DMG (glisser dans Applications), en plus de l'archive `.zip`.
- Recherche de mises à jour depuis l'app (désactivée par défaut, ne contacte que GitHub, n'installe rien seule).
- Désinstallation complète : visage, mot de passe et clé du trousseau, réglages, journaux, ouverture à la connexion, autorisations si macOS le permet, puis l'app à la Corbeille.
- Résistance aux photos et vidéos non mesurée (choix du propriétaire), indiquée dans les notes.

## 0.9.0 — bêta (novembre 2026)

Première version publique, pour essais. Détails et limites : [`docs/release-notes/0.9.0.md`](docs/release-notes/0.9.0.md).

- Assistant de configuration, enregistrement du visage en deux tours de tête, apparences.
- Protection d'applications (écran opaque, visage puis Touch ID ou mot de passe, règles de reverrouillage).
- Verrouillage quand vous vous éloignez.
- Déverrouillage de l'écran (mode avancé, désactivé par défaut) : saisie du mot de passe macOS, armée par Touch ID.
- Île autour de l'encoche, tableau de bord, français et anglais.
- Reconnaissance SFace (OpenCV Zoo, Apache-2.0) et détection de présence réelle MiniFASNetV2, entièrement sur le Mac.

Pas encore mesuré : résistance aux photos et vidéos, seuils de reconnaissance, consommation. Non notarisée.
