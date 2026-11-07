# MusiquePapa 1.3 — Internet, conversion, PDF et accords

## Utilisation sur l’iPad

### Internet et texte

Dans **Bibliothèque → Importer → Rechercher sur Internet**, saisissez un titre, un artiste ou une adresse complète. La recherche ouvre Google dans le navigateur intégré ; elle n’utilise pas d’API privée. Vous pouvez revenir à la page précédente.

- **Importer cette URL (fichier texte)** télécharge un fichier ChordPro ou texte directement accessible.
- **Utiliser le texte de la page** utilise depuis la version 1.3.1 une extraction structurée de la zone musicale, avec les accords DOM/CSS et un diagnostic. Sans zone fiable, choisissez une sélection, un collage ou une récupération destinée à la correction. Voir [le correctif Internet](CORRECTION_INTERNET_1.3.1.md).
- **Importer depuis une URL / un texte → Coller un texte** permet de coller des accords placés au-dessus des paroles.

N’importez que les contenus que vous êtes autorisé à réutiliser. Aucun paywall ni accès protégé n’est contourné. Les téléchargements sont limités à 5 Mo. Les pages qui ne fournissent pas de texte exploitable doivent être copiées manuellement. Le navigateur ne conserve pas sa session après sa fermeture. Les sites peuvent refuser l’affichage intégré ou demander des cookies ; aucun service payant n’est requis.

### PDF vers ChordPro

Ouvrez un PDF, puis **Outils → Convertir en ChordPro**. Le traitement est local : PDFKit extrait le texte et ses coordonnées ; les pages sans texte exploitable passent par Apple Vision. Une barre affiche l’avancement page par page. Vous pouvez annuler. La conversion est limitée à 100 pages par document.

Les paroles et accords sont associés selon leurs positions, pas selon une progression harmonique supposée. L’OCR peut confondre `B` et `8`, manquer un dièse ou déplacer un accord. Une partition composée uniquement de portées ne bénéficie d’aucune reconnaissance des notes musicales. Un PDF interdisant la copie n’est pas converti.

### Comparer et corriger

En paysage, l’original est à gauche et le résultat à droite. En portrait, choisissez **Original**, **Résultat** ou **Modifier**. Le PDF original garde son zoom tactile et son défilement multipage ; le texte original propose A− / A+ et un défilement dans les deux directions.

**Modifier** donne accès au même éditeur que les chansons habituelles : insertion d’accords, informations (titre/artiste/tonalité/capo), sections, recherche, annuler/rétablir et taille de texte. **Résultat** montre le rendu musical de la dernière édition. Le texte n’est pas recréé lors des changements de panneau ou d’orientation : sélection et historique d’annulation restent dans l’éditeur.

**Vérifications** liste les incertitudes détectées lors de la conversion. Elles restent consultables après correction ; ce n’est pas une mesure de fiabilité ni une validation automatique. Une page multicolonne, une mise en page proportionnelle ou une tablature complexe nécessite une comparaison attentive.

**Enregistrer en ChordPro** ajoute une nouvelle chanson. Une copie immuable du texte/PDF original est conservée localement avec celle-ci. Le PDF déjà présent, ses favoris et ses playlists restent intacts. Aucun original Dropbox n’est modifié. La nouvelle chanson fonctionne avec les playlists, tonalités, couleurs, zoom et défilement. **Modifier** permet de retrouver plus tard la source et le résultat.

### Diagrammes de guitare

Touchez un accord coloré du lecteur. Le diagramme représente **le symbole affiché**, donc la forme après transposition. Le lecteur passe en pause ; position, vitesse et zoom sont conservés. Fermez la fenêtre puis touchez **Lecture** pour reprendre.

Le menu Position présente les variantes connues. Mi grave à gauche, Mi aigu à droite ; X signifie corde muette, O corde à vide. Les chiffres 1 à 4 indiquent les doigts. Les barrés apparaissent en bleu. Le premier numéro de case figure à gauche du manche.

Le catalogue couvre les douze fondamentales, les enharmonies et neuf familles : majeur, mineur, 7, maj7, m7, sus2, sus4, diminué et augmenté. Des positions ouvertes sont privilégiées lorsqu’elles existent ; des formes fermées transposables étendent la couverture. C/G et D/F# ont des doigtés spécifiques. Les extensions non cataloguées, par exemple C7(b9), et les renversements non répertoriés affichent **Aucun doigté vérifié disponible**. Le catalogue n’affirme donc pas couvrir tous les accords possibles.

Le capo ne transpose pas une deuxième fois le diagramme. Celui-ci montre la forme écrite, avec des cases comptées depuis le capo. Pour un capo numérique entre 0 et 12, le nom de l’accord entendu est indiqué séparément. La forme simplifiée de Fa conserve les notes de Fa majeur sur quatre cordes ; ce n’est pas un remplacement par Fa maj7.

### Impression et partage

Dans le lecteur, **Outils → Imprimer / Exporter en PDF** ouvre un aperçu multipage avec zoom. Un PDF existant est exporté à l’identique. Une chanson ChordPro est rendue en PDF vectoriel A4 avec son titre, artiste, tonalité, capo et transposition courante.

Réglez la taille imprimée (10 à 32 points) et, si souhaité, **Noir et blanc**. L’aperçu est actualisé. Les accords et paroles d’une même ligne restent ensemble à la coupure de page. Les tablatures très larges entraînent une réduction proportionnelle pour ne pas être coupées horizontalement.

- **Imprimer** ouvre AirPrint. Le choix de l’imprimante et la confirmation restent dans l’interface Apple.
- **Enregistrer dans Fichiers** propose un nom fondé sur le titre. Choisissez éventuellement Dropbox s’il est activé dans Fichiers.
- **Partager** ouvre la feuille Apple (AirDrop, Mail, applications disponibles). Aucun destinataire ni envoi n’est choisi automatiquement.

## Conservation des données et installation

La version 1.3 a été installée et lancée sur votre iPad 9 le 31 octobre 2026. La vérification après installation confirme la conservation de vos 259 partitions, de votre playlist et de vos préférences. Une sauvegarde avant mise à jour reste sur le Mac dans le dossier `build/`.

Le bundle reste `ISA-NUM1.musiquePapa`, avec l’équipe de signature existante. Installez la mise à jour par Xcode sans supprimer l’application de l’iPad. Le nouveau champ de provenance est optionnel : les anciennes bibliothèques restent décodables. La sauvegarde de secours conserve également les sources originales nécessaires.

Ouvrir `musiquePapa.xcodeproj`, sélectionner le schéma `musiquePapa`, choisir l’iPad connecté et déverrouillé, puis ▶︎. L’iPad doit autoriser ce Mac et le développement. Voir aussi le README pour les problèmes de connexion et de confiance. iPadOS 17 reste la version minimale ; les tests automatisés utilisent le runtime disponible, pas iPadOS 17.

## Principaux composants

- `Printing/ScorePDFExporter.swift` : pagination vectorielle, aperçu, Fichiers, partage et AirPrint.
- `Conversion/ChordTextConverter.swift` : reconnaissance et alignement des accords ; aucune génération harmonique.
- `Conversion/PDFToChordProConverter.swift` : sélections PDFKit, coordonnées, OCR Vision et regroupement des lignes.
- `Conversion/ConversionReviewView.swift` et l’éditeur existant : comparaison, correction, progression et annulation.
- `Internet/` : navigateur WKWebView et téléchargement borné de fichiers texte.
- `Guitar/` : reconnaissance des symboles, catalogue extensible, diagramme vectoriel.
- `ChordPro/ChordCanvas.swift` et `PDF/ScoreReaderController.swift` : zones tactiles suivant le rendu et pause sans réinitialisation.
- `ViewModels/LibraryStore.swift` : publication atomique de la nouvelle partition et de la référence à son original.

## Catalogue de doigtés et références techniques

Les doigtés sont exprimés du Mi grave au Mi aigu, accordage standard E–A–D–G–B–E. Le catalogue contient des formes ouvertes courantes et des formes fermées de Mi/Ré déplacées d’un nombre entier de cases. La transposition conserve les intervalles ; un filtre vérifie que l’ensemble des notes et la basse correspondent exactement au symbole demandé. Les tests vérifient également les barrés. Aucun algorithme ne recherche au hasard des positions sur le manche. Les positions ouvertes suivent les formes enseignées dans la [bibliothèque d’accords JustinGuitar](https://www.justinguitar.com/chords) ; les schémas sont dessinés par l’application et aucune image n’est copiée.

L’OCR utilise [VNRecognizeTextRequest](https://developer.apple.com/documentation/vision/recognizing-text-in-images) et les [coordonnées des caractères reconnus](https://developer.apple.com/documentation/vision/vnrecognizedtext/boundingbox(for:)). La correction linguistique est désactivée pour éviter de transformer les symboles d’accord en mots supposés. Les coordonnées OCR restent estimées et nécessitent une relecture.

## Vérifications manuelles restant nécessaires

Les tests ne remplacent pas un essai sur l’iPad physique : toucher avec les doigts, lecture de longs documents personnels, disposition réelle des pages web et réaction du fournisseur Dropbox. AirPrint doit être essayé avec une imprimante compatible ; AirDrop et Mail avec un destinataire choisi par l’utilisateur. Les performances OCR varient selon la qualité des scans et le matériel. Aucun compte Dropbox ni imprimante réelle n’a été utilisé dans les tests automatisés.
