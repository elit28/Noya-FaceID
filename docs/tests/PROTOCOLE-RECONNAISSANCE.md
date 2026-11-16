# Protocole de mesure — reconnaissance faciale

Utilisé aux jalons J2 (choix et calibrage du modèle SFace) et J4 (moteur de reconnaissance). Les critères sont fixés **avant** les mesures pour éviter d'ajuster les seuils jusqu'à obtenir un bon résultat.

## Ce qu'on mesure

| Mesure | Définition |
|---|---|
| **Faux rejet (FRR)** | Le propriétaire est refusé alors que c'est bien lui |
| **Fausse acceptation (FAR)** | Une autre personne est acceptée |
| **Temps de reconnaissance** | Du début de la recherche à la décision, mesuré par l'app |

## Conditions

- MacBook Air M5, caméra intégrée, distance d'environ une longueur de bras.
- Enrôlement standard : deux scans, une seule apparence (« Standard »), lumière normale.
- Aucune image n'est enregistrée : l'outil de diagnostic consigne uniquement des scores, des décisions et des durées dans un fichier local, qui n'est jamais commité.

## Faux rejets — propriétaire

50 tentatives par condition, en relançant la recherche à chaque fois :

| Condition | Tentatives |
|---|---|
| Lumière normale, face à l'écran | 50 |
| Lumière faible (lampe éteinte, soir) | 50 |
| Contre-jour (fenêtre derrière) | 50 |
| Avec lunettes, sans apparence « lunettes » enregistrée | 50 |
| Tête tournée d'environ 20° | 50 |

**Objectif de confort (non bloquant)** : au plus 10 % de faux rejets en lumière normale avec l'exigence « Standard ».

## Fausses acceptations — autres personnes

- Au moins 3 volontaires **consentants**, informés qu'aucune image n'est conservée.
- 20 tentatives par volontaire, avec le profil du propriétaire enrôlé.

**Critère bloquant** : 0 acceptation au réglage « Standard ».

À savoir : 0 acceptation sur 60 essais ne prouve pas que le taux est nul. Statistiquement, cela borne le taux à environ 5 % avec 95 % de confiance (règle de trois : 3/n). Ce chiffre sera indiqué tel quel dans la documentation.

## Calibrage du seuil

1. Tracer la distribution des scores du propriétaire et celle des autres personnes.
2. Choisir le seuil « Standard » qui garantit 0 fausse acceptation avec une marge, puis vérifier le taux de faux rejets.
3. « Souple » et « Stricte » sont définis par rapport à « Standard » et documentés avec leurs mesures.

Repère public pour SFace : OpenCV indique une similarité cosinus de 0,363 comme seuil de même identité, mesurée sur un jeu de référence (LFW). Ce n'est qu'un point de départ : le seuil retenu sera celui mesuré sur le Mac.

## Résultats

Consignés dans `docs/tests/resultats/` (date, version, conditions, chiffres bruts), y compris les échecs.
