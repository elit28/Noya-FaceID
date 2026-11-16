# Protocole de test — anti-usurpation (présence réelle)

Jalon J6. Critères validés le 16/11/2026, fixés **avant** les mesures. Les résultats sont publiés tels quels, échecs compris.

## Règles

- On n'utilise que des photos et vidéos **du propriétaire**, prises pour l'occasion et supprimées après le test.
- Chaque tentative dure toute la fenêtre de recherche (5 s par défaut).
- Le réglage de présence réelle est « Stricte » et l'exigence de correspondance « Standard ».
- L'app consigne pour chaque essai : l'attaque, la décision, le motif de refus (texture, reflet, cadre d'appareil, absence d'indice temporel, plusieurs visages). Aucune image n'est conservée.

## Attaques et critères

| # | Attaque | Essais | Critère |
|---|---|---|---|
| A1 | Photo imprimée couleur, papier mat, format A4 | 25 | **0 acceptation** (bloquant) |
| A2 | Photo imprimée couleur, papier brillant | 25 | **0 acceptation** (bloquant) |
| A3 | Photo sur téléphone, luminosité maximale | 25 | **0 acceptation** (bloquant) |
| A4 | Photo sur tablette ou second écran | 25 | **0 acceptation** (bloquant) |
| A5 | Vidéo du propriétaire (clignements, mouvements) sur téléphone | 20 | Résultat documenté ; non garanti |
| A6 | Vidéo du propriétaire sur un écran d'ordinateur | 20 | Résultat documenté ; non garanti |
| A7 | Photo tenue à la main et bougée | 20 | **0 acceptation** (bloquant) |
| A8 | Propriétaire + une autre personne dans le champ | 20 | **0 acceptation** (refus « plusieurs visages ») |
| A9 | Tentatives répétées avec la photo A1 | jusqu'à la limite | Mot de passe exigé après la limite d'essais |
| A10 | Photo A1 dans une pièce sombre | 20 | **0 acceptation** (bloquant) |

A1 à A4 réunissent les 50 essais « photo imprimée » et les 50 essais « photo sur téléphone ou écran » prévus par la décision n° 12 de l'audit.

## Conduite à tenir

- **Échec d'un critère bloquant** : correction (seuils, indices, combinaison CNN et indices temporels), puis nouvelle campagne complète. Aucune publication avant réussite.
- **Vidéo acceptée (A5, A6)** : limite documentée dans `SECURITY.md` et dans l'interface. Le déverrouillage de l'écran reste un mode avancé, désactivé par défaut.
- **Sécurité avant confort** : les seuils de présence réelle ne sont jamais assouplis pour améliorer le taux de reconnaissance.

## Fiche de résultats (modèle)

| Date | Version | Attaque | Essais | Acceptations | Motifs de refus | Remarques |
|---|---|---|---|---|---|---|
| | | | | | | |
