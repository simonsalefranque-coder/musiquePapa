# Vérifications — MusiquePapa

## Version 1.3.1 — correction Internet, 1er novembre 2026

**55 tests locaux réussis : 46 tests unitaires/composants et 9 tests d’interface, aucun échec et aucun test ignoré.** Rapport complet : `TestResults/Internet-fix-regression-01.xcresult`, résumé `Documentation/TestSummary-1.3.1-iPad9.json`.

Après les derniers ajustements du filtrage des doigtés et des diagnostics, les 46 tests unitaires/composants et le parcours d’interface Internet sont revérifiés avec le test réel dans `TestResults/Internet-fix-final-real-02.xcresult`. La validation réelle est un test supplémentaire, distinct des 55 tests locaux.

### Page réelle

La page publique indiquée par l’utilisateur a été consultée normalement dans le navigateur, puis chargée dans WKWebView sur le simulateur. **44 marqueurs d’accords dans la source, 44 accords conservés, zéro position signalée comme incertaine par l’extracteur.** La suite des symboles est comparée à celle du CSS rendu, sans progression harmonique codée en dur. Chaque ligne de paroles `.pL` est comparée à ses véritables marqueurs DOM ; le titre et l’artiste sont vérifiés indépendamment de la casse d’affichage. Les notations de doigté `xx2033` et `x02033` sont absentes du ChordPro ; les menus et la liste de tonalités restent hors de la zone importée. La création du PDF source réussit.

Aucune parole ni copie du PDF de la chanson réelle n’est archivée dans le projet. Les captures de démonstration sont originales. Une première exécution a révélé des annotations de doigté encore présentes ; ce défaut a été corrigé et le test réel a été relancé avec succès.

### Couverture de la demande

| Cas | Validation |
|---|---|
| 1. Accords sur lignes séparées | Colonnes préformatées et lignes HTML superposées |
| 2. Accords directement intégrés | ChordPro entre crochets, mélange avec colonnes |
| 3. Balises indépendantes | Spans visibles et spans vides avec contenu CSS ; régression du cas paroles seules |
| 4. Espaces significatifs | Colonnes, tabulations, accents et tablatures |
| 5. Positionnement CSS | Rectangles des caractères, marqueurs absolus, ancrages DOM du site |
| 6. Plusieurs accords par ligne | Assertions de positions exactes et ordre des symboles |
| 7–8. Altérations et extensions | F#, Bb, F#m7, Bbmaj7, Am7/4, C/G, D/F#, G7(b9), C7alt, CmMaj7, G7(b9,#11), C6/9 |
| 9. Instrumentaux | Intro et accords sans paroles ; aucune fusion forcée avec le couplet suivant |
| 10–11. Éléments parasites | Navigation, publicité, tonalités, contenu masqué et annotations de doigté exclus |
| 12. Sections | Couplets/refrains structurés ; tablatures explicites préservées |
| 13. Plusieurs chansons | Plusieurs créations HTML synthétiques et une page réelle distincte |
| 14. Aperçu | Comparaison en paysage et capture examinée visuellement, source PDF avec accords |
| 15–16. Sauvegarde/réouverture | Bibliothèque persistée, relance de l’app, original et diagnostics conservés |
| 17. Affichage/transposition | Rendu à différentes tailles, symbole transposé, aucune modification de l’original |
| 18. Diagrammes | Cibles tactiles exactes après transposition ; doigtés existants et absence explicite pour une extension non cataloguée |

Compléments : sélection partielle, récupération uniquement après choix explicite, zéro accord avec avertissement, positions ambiguës comptées par accord, polices proportionnelles, retours automatiques et éléments masqués. La suite complète vérifie aussi le zoom tactile PDF/ChordPro, la lecture automatique, la pause/reprise, les playlists, Fichiers, l’éditeur, les couleurs, l’OCR et l’impression/export existants.

### Environnement et limites

- Xcode 27.0 ; simulateur iPad 9, iPadOS 26.2 ; cible minimale iPadOS 17. Pas de runtime iPadOS 17 disponible.
- Compilation Debug pour appareil signée, signature vérifiée ; version **1.3.1 (4)**, identifiant et équipe inchangés. L’extracteur inclus dans le paquet signé est identique au fichier source testé.
- Compilation Release pour appareil également vérifiée. Le message de métadonnées AppIntents ignorées est sans rapport avec ce correctif.
- Deux avertissements UIKit `_UIReparentingView` apparaissent encore dans la suite complète lors des menus natifs, comme en 1.3 ; aucun échec de test associé. Des messages de suspension WebKit du simulateur apparaissent également dans ses journaux.
- **La version 1.3.1 n’a pas été installée sur l’iPad physique : l’utilisateur a choisi de l’installer plus tard.** Aucun test tactile physique n’est revendiqué pour ce correctif. La bibliothèque de l’iPad n’a pas été modifiée.
- Source et résultat restent à comparer pour un site inconnu ou une mise en page ambiguë. La réussite sur cette page ne garantit pas tous les sites Internet.

Capture : `Documentation/Captures-1.3.1/Comparaison-internet.png`. Guide et fichiers modifiés : `Documentation/CORRECTION_INTERNET_1.3.1.md`.

## Version 1.3 — mise à jour 3, 31 octobre 2026

**43 tests réussis : 35 tests unitaires / composants et 8 tests d’interface, zéro échec et zéro test ignoré.** Rapport : `TestResults/Update3-validation-03.xcresult`. Résumé conservé dans `Documentation/TestSummary-1.3-iPad9.json`. Simulateur iPad 9, iPadOS 26.2 ; compilation Xcode 27.0, cible minimale iPadOS 17. Aucun runtime iPadOS 17 n’est installé.

Les 32 tests précédents sont conservés. Les 11 nouveaux tests couvrent :

| Demandes | Vérification réalisée |
|---|---|
| 1. Import URL | Véritable serveur HTTP de test sur loopback, démarré automatiquement par XCTest ; téléchargement d’un ChordPro original, source conservée, erreur 404 et rejet des URL locales. Pas de téléchargement d’œuvre tierce. |
| 2–3. Conversion et positions | Colonnes exactes, accents, tabulations, accords complexes, sections, tablatures, absence d’invention d’accords. |
| 4–5. PDF et OCR | PDF textuel original à deux pages, extraction par coordonnées de sélections PDFKit ; PDF raster original traité réellement par Vision. |
| 6–8. Correction et conservation | Correction dans l’éditeur, comparaison, enregistrement/relecture, copie de la source et conservation du PDF initial après nettoyage. |
| 9–10. Impression | Données PDF reconnues imprimables par UIKit pour les deux formats ; ouverture de l’interface native AirPrint avec les dix pages du PDF. Aucun papier imprimé. |
| 11–12. Export / partage | PDF A4 vectoriel de six pages, transposition C → D et Am → Bm, titre/capo, fichier local identique, copie PDF originale à trois pages, ouverture de la feuille de partage. Pas d’envoi à un tiers. |
| 13–18. Doigtés | C, Am, F barré, G7, F#m7, D/F# et C/G ; toutes les fondamentales et neuf familles avec vérification des notes, basses et barrés. Accords non catalogués explicitement indisponibles. |
| 19–21. Transposition / zoom / lecture | Zones tactiles correspondant à D/Bm après transposition, tailles 16/32/60, pause du contrôleur réel sans changement de position, vitesse ni taille. |
| 22–23. Fenêtres / orientations | Ouverture et fermeture des diagrammes, comparaison texte et PDF, changement d’orientation, aperçu PDF et partage natif. Captures conservées dans `Documentation/Captures-1.3`. |
| 24. Conservation | Favoris, ordre des playlists, vitesse, zoom, historique, préférences et reprise après réouverture ; migration des anciens catalogues toujours couverte. |

Le rendu de la première et de la dernière page du PDF exporté a aussi été contrôlé avec Poppler : marges, en-tête, accords alignés, pagination et dernière ligne présents. Les captures `Export-A4-verifie-*` correspondent à ce contrôle indépendant.

Deux avertissements UIKit `_UIReparentingView` sont enregistrés lors de l’ouverture des menus dans le simulateur. Les parcours aboutissent et les captures ont été contrôlées ; ces avertissements ne sont pas comptés comme des erreurs. L’avertissement de compilation AppIntents indique seulement que l’application ne déclare pas d’AppIntents.

### Compilation, sauvegarde et installation

- Debug pour simulateur : compilé et testé.
- Debug pour appareil : compilé avec la signature existante ; vérification `codesign --verify --deep --strict` réussie.
- Release pour appareil : compilation optimisée réussie sans signature.
- Version 1.3, build 3 ; identifiant `ISA-NUM1.musiquePapa` et équipe de signature inchangés.
- Sauvegarde réelle de l’iPad effectuée avant installation : **259 partitions et 1 playlist**, dans `build/Backup-iPad-avant-1.3-20261031` (dossier ignoré par Git, conservé uniquement sur ce Mac).
- Après reconnexion de l’iPad par l’utilisateur, **la version 1.3 a été installée et lancée sur l’iPad 9 physique**. Une sauvegarde actualisée a précédé l’installation (`build/Backup-iPad-avant-installation-1.3-20261031-soir`). Une nouvelle lecture après démarrage confirme les mêmes 259 partitions, la même playlist, les mêmes réglages et préférences, et des fichiers de partitions identiques par SHA-256. Résultat sans données personnelles : `Documentation/Installation-iPad-1.3.json`.

### Limites des vérifications

Les tests fonctionnels automatisés sont exécutés sur simulateur ; sur l’appareil physique, seuls l’installation, le démarrage et la conservation des données ont été vérifiés. Restent à essayer sur l’iPad : les gestes réels, les performances sur les partitions personnelles, l’accès aux sites réels et à Dropbox, un enregistrement dans un fournisseur Fichiers distant, AirPrint avec une imprimante et un partage AirDrop/Mail choisi par l’utilisateur. Une page web protégée ou un scan de portées seules ne bénéficie d’aucune conversion musicale garantie. Aucun envoi ni impression physique n’a été effectué.


## Version 1.1 — 29 octobre 2026

**32 tests réussis, 0 échec, 0 test ignoré, aucun avertissement d’exécution dans le résumé Xcode**, sur le simulateur **iPad 9 / iPadOS 26.2** : 27 tests de logique/lecteurs et 5 parcours d’interface. Rapport officiel : [TestSummary-1.1-iPad9.json](TestSummary-1.1-iPad9.json). Rapport complet local : `TestResults/Update-validation-1.1-02.xcresult`.

### Compilations et installation

- Debug simulateur : compilation et exécution réussies.
- Release ARM64 iPad : compilation réussie sur le code final.
- Debug iPad signé : compilation réussie avec l’équipe déjà configurée et le même Bundle Identifier ; vérification `codesign --verify --deep --strict` réussie avec accès au trousseau macOS.
- Produit : version **1.1**, build **2**, iPadOS minimal **17.0**.
- La mise à jour n’a pas été installée sur l’iPad physique pendant cette intervention. L’appareil est appairé, mais son tunnel de développement est indisponible et les services DDI ne sont pas accessibles. La tentative de lecture préalable du conteneur a été refusée par CoreDevice ; aucune sauvegarde de l’appareil n’est annoncée comme réalisée et son installation existante n’a pas été remplacée.
- Aucun essai sur iPad physique ni compte Dropbox réel. Pas de runtime iPadOS 17 installé : disponibilité des API vérifiée par compilation, pas par exécution sous iPadOS 17.

### Nouveautés vérifiées

| Fonction | Vérification exécutée |
|---|---|
| Défilement du sélecteur | Sélection de Si en bas puis retour et sélection de Do en haut, portrait et paysage, dans la vraie interface |
| Tonalités | Douze classes de notes, graphies dièse/bémol, modes majeur/mineur, lecture des noms français, intervalles, accords complexes et basses |
| Origine / affichage / capo | Source manuelle et cible indépendantes, intervalle appliqué une seule fois, fichier source inchangé ; adaptation après édition de `{key}` |
| Couleurs | Persistance individuelle et défaut global, réinitialisation, dessin limité aux accords, résolution en clair/sombre ; choix Rouge et capture UI |
| Vitesses | Deux chansons avec valeurs distinctes, renommage, réouverture du magasin, héritage global et retour au défaut ; commandes réelles du lecteur PDF et ChordPro |
| Lecture avec préférences | Changement de tonalité/couleur en cours de lecture avec zoom, conservation de taille et d’ancre ; moteur temporel existant inchangé |
| Éditeur | Création, changement du titre dans Informations, saisie accentuée, coloration, insertion sans écraser une sélection, annuler/rétablir et préservation de sélection |
| Aperçu / zoom | Boutons et pincement dans l’éditeur, bascule portrait, deux colonnes en paysage, captures contrôlées visuellement |
| Sauvegarde | Enregistrer puis rouvrir le texte, conserver les directives inconnues, original inchangé, UUID/favoris/playlists/vitesse conservés |
| Erreurs / conflits | Échec d’écriture du catalogue : ancien état intact et nouvelle copie retirée ; empreinte périmée refusée ; modification distante conservée séparément de l’édition locale |
| Restauration | Retour à la version précédente et retour inverse, intégrité par empreinte, nettoyage respectant les fichiers retenus |
| Migration | Lecture d’un catalogue v1 avec vitesses, favoris et playlists, passage v2 lors de l’écriture sans perte |
| Brouillon | Confirmation d’abandon, fermeture puis réouverture sans le texte abandonné |
| Régressions | PDF dix pages jusqu’à la fin, gestes de zoom, pause/reprise/arrêt, import via le sélecteur natif Fichiers, playlists, mode scène, persistance après relancement |

Les captures de la version sont dans [Captures-1.1](Captures-1.1). Elles proviennent du simulateur, pas de maquettes. Les tests utilisent une bibliothèque de test séparée et ne suppriment jamais la bibliothèque normale.

Le choix d’une destination d’export/partage réelle, l’import avec le compte Dropbox du père et le confort de jeu prolongé sont à vérifier sur appareil. Le [guide 1.1](MISE_A_JOUR_1_1.md) donne les manipulations précises.

---

## Historique : version 1.0 — 27 octobre 2026

## Résultat exécuté

**20 tests réussis, 0 échec, 0 test ignoré, aucun avertissement d’exécution**, sur un **simulateur iPad 9e génération sous iPadOS 26.2**, avec Xcode 27.0. Le résumé natif Xcode est conservé dans [TestSummary-iPad9.json](TestSummary-iPad9.json). Le rapport complet local est `TestResults/iPad9.xcresult` (ouvrable dans Xcode, exclu de Git pour sa taille).

Une série précédente de 19 tests a également réussi sur un simulateur iPad A16 / iPadOS 27.0. Elle a servi à vérifier les gestes puis à identifier un avertissement de mise à jour SwiftUI, corrigé et absent de la série iPad 9.

- Compilation Debug pour simulateur : réussie.
- Compilation Release ARM64 pour iPad physique : réussie **sans signature**.
- Déploiement minimal vérifié dans le produit compilé : iPadOS 17.0 ; famille d’appareil : iPad uniquement.
- Aucun test effectué sur un iPad physique. Aucun runtime iPadOS 17 n’est installé sur ce Mac ; la compatibilité minimale est vérifiée à la compilation, pas par une exécution sous iPadOS 17.
- Aucun compte Dropbox réel n’a été utilisé. Le fournisseur local Fichiers et la logique de bookmarks/actualisation sont testés ; le comportement de Dropbox doit encore être vérifié avec le compte du père.

## Couverture des 17 points demandés

| # | Vérification | Preuve exécutée / portée |
|---|---|---|
| 1 | Importation ChordPro | Validation, copie locale, import de dossier, import par le sélecteur natif Fichiers |
| 2 | Directives SongBook | Métadonnées, alias, commentaires, couplets, refrains, tablatures, directive inconnue et sauts de ligne |
| 3 | Alignement accords/paroles | Vérification des coordonnées de dessin d’accord et syllabe, en plus des captures du lecteur |
| 4 | Importation PDF multipage | Validation du PDF original de démonstration ; nombre de pages = 10 |
| 5 | Zoom tactile PDF | Pincement XCUITest ; le facteur change réellement ; rendu PDFKit |
| 6 | Zoom tactile ChordPro | Pincement XCUITest et bouton A+ ; la taille mémorisée change |
| 7 | Alignement après agrandissement | Coordonnées testées à 18, 32 et 58 pt ; tablature et espaces conservés |
| 8 | Défilement automatique PDF | Moteur de production dans un vrai PDFView, de la première à la dixième page, puis arrêt ; lecture UI également vérifiée |
| 9 | Défilement automatique ChordPro | UIScrollView réel, modification d’offset et progression visible en interface |
| 10 | Défilement avec zoom | Lecture après zoom et pincement pendant Lecture pour les deux formats ; l’état Lecture est conservé |
| 11 | Pause/reprise/arrêt | Tests temporels du moteur, pause stable dans l’interface, retour à zéro par Arrêt |
| 12 | Vitesse | Changement de vitesse, équivalence 30/60 Hz sur le scroll UIKit réel, conservation des fractions de pixel |
| 13 | Playlists | Création en interface, ajout, renommage, réordonnancement du modèle, retrait et suppression indépendants de la bibliothèque |
| 14 | Classement alphabétique | A–Z et Z–A avec accents ; méthode `localizedStandardCompare` |
| 15 | Persistance après fermeture | Reconstruction du magasin, favoris/playlists/préférences ; terminaison et relancement de l’application UI avec conservation du zoom |
| 16 | Importation depuis Fichiers | Le test ouvre le vrai sélecteur, sélectionne un `.pro` depuis « Sur mon iPad », valide Ouvrir et vérifie son apparition dans la bibliothèque |
| 17 | Lecture hors connexion | Lecture depuis les copies locales persistées ; aucune requête réseau du lecteur. Pas de test en mode avion sur appareil physique |

Un contrôle UI ciblé supplémentaire du **mode scène** a ensuite réussi sur le même iPad 9 simulé : entrée/sortie, masquage/retour des commandes, rotation paysage stabilisée et reprise après relancement. Rapport local : `TestResults/Screen-iPad9.xcresult`. Captures conservées dans [Captures](Captures).

## Autres tests

- UTF-8, UTF-16, Windows-1252 et ISO-8859-1.
- Accords altérés, accords avec basse et suffixes lors des transpositions.
- Fichier vide, TXT ordinaire, PDF invalide.
- Détection SHA-256 des doublons, mise à jour sans perte de favoris/titre personnalisé/playlists.
- Deux chemins identiques initialement, puis contenus divergents : conservation de chaque version distincte.
- Récupération du catalogue de secours après corruption du catalogue courant.
- Liaison de dossier local, bookmark résolu, nouvelle lecture après modification du fichier source.
- Portrait et paysage par changement d’orientation du simulateur.

Les tests UI utilisent un catalogue distinct (`MusiquePapaUITests`) et des fichiers originaux dans `Documents/TestsImport`, uniquement avec l’argument de test en compilation Debug. Ils n’effacent jamais la bibliothèque normale. Le chemin initial du sélecteur n’est forcé qu’en mode test ; en utilisation normale le fournisseur Fichiers garde son comportement habituel.

## Reproduire sans écrire de code

Dans Xcode, sélectionner le schéma **musiquePapa**, une destination iPad Simulator, puis **Product → Test** (`⌘U`). Les deux cibles de tests sont incluses dans le schéma partagé.

Pour une exécution en ligne de commande (facultative), `Scripts/verify.sh IDENTIFIANT_SIMULATEUR` exécute la suite et crée un nouveau rapport horodaté. La commande `xcrun simctl list devices available` donne les identifiants. Les rapports et sorties de compilation restent en dehors de Git.

## À vérifier sur votre iPad avant une répétition

1. Importer deux vrais fichiers depuis Dropbox et, si le fournisseur l’autorise, un dossier. Actualiser après modification d’une partition, puis vérifier favoris et playlist.
2. Fermer l’app, couper le réseau et rouvrir les copies locales.
3. Pincer, déplacer horizontalement un PDF agrandi, modifier le zoom pendant la lecture, tourner l’iPad et reprendre.
4. Laisser défiler une longue partition à vitesse lente jusqu’à la fin. Confirmer confort visuel, fluidité et maintien de l’écran allumé.
5. Réordonner une playlist avec les poignées en mode Modifier, puis vérifier précédent/suivant et ouverture automatique de la chanson suivante.
6. Tester une éventuelle pédale Bluetooth dans son mode clavier.

Ces étapes sur appareil et Dropbox réel ne sont pas présentées comme déjà réalisées.
