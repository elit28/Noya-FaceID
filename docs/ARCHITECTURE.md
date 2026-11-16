# Architecture de NOYA Face

Document de référence de l'architecture. Les choix et leur justification figurent dans [`audit/AUDIT-TECHNIQUE.md`](audit/AUDIT-TECHNIQUE.md).

## État actuel — socle (jalon J1)

```mermaid
flowchart LR
    APP["NoyaFace<br/>(app de barre des menus)<br/>Swift 6"] --> CORE["NoyaCore<br/>reconnaissance, présence réelle,<br/>stockage chiffré, état du verrouillage<br/>Swift 6"]
    ENG["NoyaEngine<br/>caméra, enrôlement, vérification,<br/>protection d'applications<br/>Swift 5 → 6"] --> CORE
    TESTS["Tests<br/>NoyaCoreTests, NoyaEngineTests"] -.-> CORE
    TESTS -.-> ENG
```

| Module | Rôle | Origine |
|---|---|---|
| `NoyaCore` | Détection (Vision), alignement 5 points, extracteur d'empreinte (modèle ajouté au jalon J2), classifieur anti-usurpation MiniFASNet, stockage AES-GCM, lecture de l'état de verrouillage | HeyMac (MIT), adapté |
| `NoyaEngine` | Capture caméra à la demande, enrôlement, fenêtres de vérification bornées, coordination visage → Touch ID / mot de passe, sessions de confiance des apps protégées | HeyMac (MIT), adapté |
| `NoyaFace` | Application : icône de barre des menus (masquable), fenêtre de réglages, état réel des composants | Nouveau |

L'app n'utilise pas encore le moteur : aucune fonction de protection n'est active au jalon J1.

## Cible

```mermaid
flowchart TB
    subgraph UI["Interface (SwiftUI + AppKit)"]
        APP["NoyaFace : barre des menus, assistant, réglages, diagnostic"]
        ISL["Île de l'encoche / pastille"]
        SHD["Masques des apps protégées"]
    end
    subgraph ENG["Moteur"]
        POL["Règles de décision et limites de tentatives"]
        AUTH["Visage puis Touch ID / mot de passe (LAContext)"]
        LOCK["État verrouillé, verrouillage sur absence, déverrouillage (avancé)"]
        APPL["Protection d'applications"]
    end
    subgraph CORE["Cœur testable"]
        CAP["Caméra à la demande"]
        REC["Reconnaissance"]
        LIV["Présence réelle : CNN + indices temporels"]
        PRO["Visage et apparences"]
        SEC["Trousseau + AES-GCM"]
    end
    APP --> POL & AUTH & LOCK & APPL
    ISL --> POL
    SHD --> APPL
    POL --> REC & LIV & PRO
    LOCK --> SEC
    REC --> CAP
    LIV --> CAP
    PRO --> SEC
```

## Construction et contrôles

| Étape | Outil |
|---|---|
| Compilation, tests | `swift build`, `swift test` (Swift Testing) |
| App | `scripts/build-app.sh` : assemblage, traductions, icône, signature ad hoc ou identité locale, Hardened Runtime |
| Vérification de l'app | `scripts/verify-app.sh` : signature, runtime, entitlement caméra seul, identifiant, ressources, traductions, absence de modèle InsightFace |
| Contrôles du dépôt | `scripts/check-private-api.sh`, `scripts/check-localizations.py`, `scripts/check-repository.sh` |
| Intégration continue | `.github/workflows/ci.yml` : contrôles (Linux) puis compilation, tests et app (macOS) ; l'app de test est publiée en archive |

## Localisation

Textes de l'interface écrits en français dans le code (clés) ; traductions dans `packaging/<langue>.lproj/Localizable.strings` et `InfoPlist.strings`, copiées dans le bundle de l'app. Langue de développement : français ; langues : français, anglais (puis espagnol, allemand, italien, portugais). Le contrôle CI refuse tout texte non traduit.

Format retenu : fichiers `.strings` (système de localisation d'Apple, compatible avec la compilation en ligne de commande de SwiftPM, comme dans HeyMac). Un passage au catalogue `.xcstrings` est possible si le projet adopte un projet Xcode.
