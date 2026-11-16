<div align="center">
<img src="packaging/AppIcon.png" width="120" alt="Logo NOYA Face">

# NOYA Face

**Reconnaissance faciale et protection des applications pour Mac — libre, gratuite, entièrement locale.**

*Face recognition and app protection for Mac — free, open source, fully on-device.*

[![CI](https://github.com/elit28/Noya-FaceID/actions/workflows/ci.yml/badge.svg)](https://github.com/elit28/Noya-FaceID/actions/workflows/ci.yml)

</div>

> [!WARNING]
> **En développement — aucune version publiée.** Le projet en est au socle technique (jalon J1) : aucune fonction de protection n'est encore active.
>
> **La caméra d'un Mac n'est pas Face ID.** Elle ne mesure pas la profondeur du visage. NOYA Face apportera confort et confidentialité, mais ne remplace pas un mot de passe macOS robuste.

## Français

### Ce que fera NOYA Face

- **Protéger des applications** (Messages, Notes, Photos…) : masquées jusqu'à votre authentification par le visage, puis Touch ID ou mot de passe vérifiés par macOS.
- **Verrouiller le Mac quand vous vous éloignez** : la caméra ne s'allume qu'après une période sans clavier ni souris.
- **Afficher les étapes autour de l'encoche**, de chaque côté (pastille sur les Mac sans encoche).
- **Déverrouiller l'écran** (mode avancé, désactivé par défaut) : seulement avec une version signée permettant de protéger le mot de passe par Touch ID.
- **Français et anglais** dès la première version, puis espagnol, allemand, italien et portugais.

### Confidentialité

Traitement entièrement local, aucune image enregistrée, aucune donnée envoyée, aucun compte, aucune télémétrie. Détails : [`SECURITY.md`](SECURITY.md).

### Essayer la version de développement

Chaque modification produit une app de test dans l'onglet [Actions](https://github.com/elit28/Noya-FaceID/actions) (archive « NOYA-Face-dev »). Elle n'est pas notarisée : au premier lancement, macOS la bloque. Ouvrez alors **Réglages Système › Confidentialité et sécurité** et cliquez sur **Ouvrir quand même**.

### Compiler

Prérequis : macOS 14+, Xcode 16+.

```bash
swift build
```

```bash
swift test
```

```bash
scripts/build-app.sh
```

Plus de détails : [`CONTRIBUTING.md`](CONTRIBUTING.md) · architecture : [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · audit et plan : [`docs/audit/AUDIT-TECHNIQUE.md`](docs/audit/AUDIT-TECHNIQUE.md)

## English

NOYA Face will protect selected apps behind your face (with Touch ID or your macOS password as fallback, verified by macOS), lock your Mac when you walk away, and show recognition steps on both sides of the notch. Everything runs on-device: no images stored, no data sent, no account, no telemetry. **A Mac webcam is not Face ID** — NOYA Face is a convenience and privacy layer, not a replacement for a strong password. The project is at its technical foundation stage; nothing is released yet. Build with `swift build`, test with `swift test`, package with `scripts/build-app.sh` (macOS 14+, Xcode 16+).

## Licence — License

Code sous licence [MIT](LICENSE). Composants tiers et crédits (HeyMac, Silent-Face-Anti-Spoofing) : [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md). NOYA Face n'est pas affilié à Apple ; « Face ID » est une marque d'Apple Inc.
