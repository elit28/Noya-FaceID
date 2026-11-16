# Contribuer à NOYA Face — Contributing

Merci de votre intérêt ! *Thanks for your interest — English summary at the end.*

## Prérequis

- macOS 14 Sonoma ou plus récent
- Xcode 16 ou plus récent (Swift 6)

## Compiler et tester

```bash
swift build
```

```bash
swift test
```

```bash
scripts/build-app.sh
```

Ouvrir le projet dans Xcode : ouvrez simplement `Package.swift`.

L'app construite se trouve dans `dist/NOYA Face.app`. Elle est signée en ad hoc (ou avec l'identité locale créée une fois par `scripts/create-signing-identity.sh`) et n'est pas notarisée.

## Règles du projet

- **Textes de l'interface** : écrits en français dans le code (ils servent de clés), puis traduits dans `packaging/en.lproj/Localizable.strings` (et ajoutés tels quels dans `packaging/fr.lproj/`). `python3 scripts/check-localizations.py` doit réussir.
- **Aucune API privée** ni chargement dynamique de symbole : `scripts/check-private-api.sh` doit réussir.
- **Swift 6** et concurrence stricte pour tout nouveau code ; commentaires en français.
- **Tests** obligatoires pour toute logique nouvelle ; les fonctions de sécurité ont en plus un protocole de test manuel documenté.
- **Aucun secret** (certificat, clé, identifiant) dans le dépôt ; aucun modèle dont la licence interdit la redistribution.
- Les fonctions doivent être réelles : pas de bouton décoratif, pas de chiffre affiché sans mesure.
- Les failles de sécurité se signalent en privé : voir `SECURITY.md`.

## Propositions de modification

1. Créez une branche depuis `Branche-Principale-Noya-FaceID`.
2. Vérifiez que la CI est verte (contrôles, compilation, tests, construction de l'app).
3. Ouvrez une pull request décrivant le changement et la façon de le tester.

---

**English summary.** Requirements: macOS 14+, Xcode 16+. Build with `swift build`, test with `swift test`, package with `scripts/build-app.sh`. UI strings are written in French in code (they are the keys) and translated in `packaging/en.lproj/Localizable.strings`; `scripts/check-localizations.py` must pass. No private Apple APIs, no secrets, Swift 6 for new code, tests required. Report security issues privately (see `SECURITY.md`).
