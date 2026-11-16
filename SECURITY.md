# Sécurité — Security

## Signaler une vulnérabilité

**N'ouvrez pas de ticket public.** Utilisez le signalement privé de GitHub : onglet *Security* › *Report a vulnerability* du dépôt. Décrivez la version, les étapes pour reproduire et l'impact. Nous accusons réception dès que possible et publions un correctif avant toute divulgation.

*Please do not open a public issue. Use GitHub private vulnerability reporting (Security tab › Report a vulnerability) with the version, reproduction steps and impact.*

## État actuel

Version de développement : la protection d'applications et le verrouillage en cas d'absence sont écrits, compilés et testés automatiquement sur macOS, mais **pas encore essayés ni mesurés sur un vrai Mac**. Les garanties ci-dessous décrivent les objectifs et les règles du projet ; elles seront vérifiées et mesurées à chaque jalon (voir `docs/audit/AUDIT-TECHNIQUE.md`).

## Ce que NOYA Face protège — et ce qu'il ne protège pas

La caméra d'un Mac capte une image en deux dimensions : **NOYA Face n'a pas le niveau de sécurité de Face ID** et ne remplace pas un mot de passe macOS robuste.

| Menace | Position |
|---|---|
| Regard indiscret, accès opportuniste (proche, collègue) | Protégé (objectif principal) |
| Photo imprimée, photo sur téléphone | Objectif : 0 acceptation sur 50 + 50 essais, mesuré au jalon J6 |
| Vidéo rejouée sur un écran | **Non garanti** — limite documentée |
| Plusieurs personnes devant la caméra | Refus de la reconnaissance |
| Personne connaissant votre mot de passe macOS | Hors périmètre |
| Logiciel malveillant exécuté avec vos droits, accès au disque | Hors périmètre ; les données restent chiffrées |
| Écran de connexion après redémarrage, FileVault, changement d'utilisateur | Mot de passe toujours obligatoire |

La **protection d'applications** est une protection de confidentialité : elle masque l'application, mais celle-ci continue de fonctionner et ses données restent sur le disque. Terminal, Réglages Système, Moniteur d'activité, Finder et NOYA Face ne peuvent jamais être protégés, pour pouvoir corriger une erreur. Quitter NOYA Face demande Touch ID ou le mot de passe, mais un arrêt forcé (Moniteur d'activité) retire la protection jusqu'à la relance.

Le **verrouillage en cas d'absence** allume brièvement la caméra après la période d'inactivité choisie (le voyant vert s'allume) et verrouille le Mac avec le raccourci système ⌃⌘Q, ce qui exige l'autorisation Accessibilité.

Le **déverrouillage de l'écran** est un mode avancé, désactivé par défaut, qui saisit votre mot de passe macOS à votre place. Il reste **indisponible** tant que le mot de passe ne peut pas être protégé par Touch ID au niveau du Trousseau (nécessite une version signée avec un compte Apple Developer).

## Données et stockage

| Donnée | Emplacement | Protection |
|---|---|---|
| Empreintes faciales (aucune image) | `~/Library/Application Support/NOYA Face/` (dossier `0700`, fichiers `0600`) | AES-256-GCM, clé dans le Trousseau |
| Mot de passe macOS (mode avancé seulement) | Trousseau | Chiffré, clé protégée par Touch ID ou mot de passe |
| Réglages | `UserDefaults` | Non sensibles |
| Journaux | Journal de diagnostic local | Jamais de mot de passe, d'image ni d'empreinte |

Aucune donnée n'est envoyée sur Internet. Aucune télémétrie, aucun compte.

## Règles appliquées au code

- **Aucune API privée d'Apple** ni chargement dynamique de symbole : contrôle automatique en CI (`scripts/check-private-api.sh`). Une éventuelle exception (animation sur l'écran verrouillé) sera isolée, optionnelle, désactivée par défaut et documentée.
- **Hardened Runtime** obligatoire ; seul l'entitlement caméra est accordé ; aucune exception du type `disable-library-validation` (vérifié par `scripts/verify-app.sh`).
- Aucun anti-débogage, aucune instruction de contournement de Gatekeeper.
- Aucun modèle sous licence incompatible (contrôle CI et test).
- Aucun secret dans le dépôt (contrôle CI `scripts/check-repository.sh`).
