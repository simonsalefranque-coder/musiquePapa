# MusiquePapa 1.3.1 — Accords des partitions Internet

## Cause du problème

Le navigateur utilisait `window.getSelection().toString() || document.body.innerText`. Cela extrayait toute la page en l’absence de sélection : menus, tonalités, navigation et textes annexes. Surtout, `innerText` ne contient pas les accords que La Boîte à chansons dessine avec un pseudo-élément CSS `::before` sur une balise vide. Les paroles étaient donc présentes sans leurs accords.

La reconnaissance textuelle rejetait également `Am7/4`, car l’ancienne expression régulière n’autorisait qu’une note après `/`.

## Correction

- Un extracteur JavaScript en lecture seule analyse le document actuellement affiché dans WKWebView. Il ne réalise aucune requête réseau et ne contourne aucun accès protégé.
- L’adaptateur La Boîte à chansons sélectionne `#divPartition`, récupère le titre et l’artiste dans leurs éléments dédiés, puis lit les symboles réellement affichés par le CSS. Les marqueurs intégrés au texte donnent la position des accords dans les paroles, indépendamment du décalage visuel des étiquettes. Aucune chanson ni suite harmonique n’est codée en dur.
- Les introductions et accords sans paroles restent présents. Les fragments de tablature du site sont regroupés selon leurs lignes et cellules visibles. Les éléments de doigté identifiés et les notations de six cordes sont exclus du texte chanté.
- Pour les autres pages, l’extracteur recherche un conteneur musical. Les blocs préformatés conservent les colonnes, les tabulations et les directives ChordPro. Les balises d’accords et les lignes superposées utilisent les rectangles des caractères réellement affichés, pas une division arbitraire par une largeur de police supposée.
- Les éléments masqués, menus, boutons, listes de tonalités, annonces et diagrammes reconnus sont exclus. Les positions éloignées ou les symboles non lisibles produisent un avertissement.
- Sans zone fiable, l’application propose une sélection manuelle, un texte collé, une récupération explicitement destinée à la correction ou l’annulation. L’ensemble de la page n’est plus converti silencieusement.
- Le diagnostic distingue les accords détectés dans la source, les accords présents dans l’édition courante et les éléments à vérifier. Il reste disponible après sauvegarde et réouverture. Un total identique ne garantit pas que chaque position soit correcte.
- Le panneau Original conserve une copie PDF locale du contenu affiché, avec ses accords et sa mise en page. Si cette copie échoue, l’interface indique qu’elle montre seulement le texte extrait et demande de comparer aussi avec la page.

## Fichiers concernés

| Fichier | Rôle |
|---|---|
| `musiquePapa/Internet/WebScoreExtractor.js` | Sélection de zone, adaptateur du site, extraction DOM/CSS, colonnes et diagnostics |
| `musiquePapa/Internet/WebScoreExtractor.swift` | Pont WKWebView, conversion, copie visuelle PDF |
| `musiquePapa/Internet/InternetImportView.swift` | Action d’import structurée et choix de récupération |
| `musiquePapa/Conversion/ChordTextConverter.swift` | Symboles complexes, comptage des ambiguïtés, texte mêlant colonnes et ChordPro |
| `musiquePapa/Conversion/ConversionReviewView.swift` | Diagnostics conservés et libellé de secours de l’original |
| `musiquePapa/Editor/ChordEditorView.swift` | Compteur dans la comparaison existante |
| `musiquePapa/ViewModels/LibraryStore.swift` | Sauvegarde et relecture des diagnostics facultatifs |
| `musiquePapa/Resources/WebImportDemo.html` | Partition originale utilisée uniquement par le parcours de test explicite |
| `Tests/WebScoreExtractionTests.swift` | Pages synthétiques, positions, filtrage, sauvegarde, rendu, transposition et cibles tactiles |
| `Tests/WebScoreLiveValidationTests.swift` | Validation réelle facultative, sans archivage des paroles |
| `UITests/MusiquePapaUITests.swift` | Conversion complète, comparaison, enregistrement et relance |

Les modèles existants restent lisibles : le diagnostic ajouté est facultatif. Les lecteurs, la transposition, les diagrammes, Dropbox, les playlists et l’export PDF n’ont pas été réécrits.

## Vérification sur votre iPad 9

1. Installer la version 1.3.1 avec le même identifiant d’application, sans supprimer MusiquePapa.
2. Ouvrir **Bibliothèque → Importer → Rechercher sur Internet**.
3. Ouvrir la partition souhaitée et attendre que les paroles et accords soient visibles.
4. Laisser le titre « Partition convertie » pour récupérer automatiquement celui de la page, puis toucher **Utiliser le texte de la page**.
5. Passer en paysage et comparer l’original à gauche avec le résultat à droite : accords, introductions, lignes et tablatures. Ouvrir **Vérifications** si nécessaire.
6. Choisir **Modifier** pour corriger une position, puis **Enregistrer en ChordPro**.
7. Fermer le navigateur, rouvrir la chanson depuis la bibliothèque et vérifier la transposition, le zoom et la lecture hors connexion.

Une chanson importée précédemment sans accords n’est pas réparée automatiquement : réimportez sa page pour créer une conversion complète.

## Limites

L’extracteur n’est pas universel. Les contenus dessinés dans des images/canvas, enfermés dans des cadres non accessibles, chargés seulement au défilement ou utilisant un balisage inconnu peuvent nécessiter une sélection ou une correction. Un changement de structure du site peut nécessiter une mise à jour de l’adaptateur. Les mises en page multicolonnes ou des positions CSS inhabituelles doivent être comparées à l’original.

Les diagrammes restent ceux du catalogue existant : `Am7/4` est conservé, rendu et transposé, mais un doigté non répertorié affiche « Aucun doigté vérifié disponible ».

La copie PDF de la source est locale et immuable. Elle couvre le rectangle de la zone sélectionnée ; pour une sélection partielle dans un paragraphe, elle peut montrer du contexte autour du texte choisi. Aucun fichier Dropbox n’est modifié.

## Validation

Les résultats finaux de compilation et de tests sont consignés dans `TESTS.md`. La validation réelle est distincte des fixtures : elle charge normalement la page publique et compare les symboles CSS de la source avec ceux du résultat. Elle n’est pas exécutée dans la suite locale ordinaire et ne conserve ni les paroles ni une copie de la chanson dans le dépôt.
