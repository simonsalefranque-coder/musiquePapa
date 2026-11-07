# Architecture

## Modules

| Dossier | Responsabilité |
|---|---|
| Models | Chansons, playlists, préférences, réglages, dossier lié et schéma du catalogue |
| ViewModels | `LibraryStore` : transactions, import et persistance ; `ReaderSession` : état et commandes du lecteur |
| Views | Écrans SwiftUI français, navigation, actions, réglages et commandes |
| Services | Import coordonné, validation des formats, SHA-256, sélecteur Fichiers, démonstrations |
| ChordPro | Décodage, analyse des directives, transposition, mesure et dessin des accords/paroles |
| PDF | Contrôleur UIKit durable et adaptateur SwiftUI ; PDFKit continu ; zoom et ancrage |
| Playback | `CADisplayLink`, calcul temporel, positions fractionnaires, pause, reprise et fin |
| Editor | Source ChordPro, UITextView, coloration, actions, aperçu, import/export et brouillon |
| Storage | JSON atomique et copie de secours |
| Dropbox | Accès Fichiers par bookmark et frontière de fournisseur |
| Tests / UITests | Tests de données, fichiers, lecteurs UIKit réels et gestes d’interface |

## Pourquoi UIKit dans le lecteur

SwiftUI pilote l’interface, mais un `UIViewControllerRepresentable` conserve le même `PDFView` ou `UIScrollView` pendant toute la lecture. Les rafraîchissements de progression ne reconstruisent pas le document. La seule reconstruction volontaire correspond à un changement de chanson ou de contenu.

Le lecteur ChordPro mesure accords et paroles avec leurs polices réelles et dessine chaque paire à la même abscisse. La largeur tient compte des accords pour éviter leurs chevauchements ; les mots passent à la ligne et les très longs mots sont coupés par graphèmes. Un ancrage par ligne musicale conserve la zone visible pendant la recomposition. Les tablatures ne sont jamais repliées.

Le PDF utilise `singlePageContinuous`, `autoScales = false` après réglage initial et `PDFView.scaleFactor`. Une page et un point du document servent d’ancre au zoom. Un geste de pincement explicite utilise cette même méthode ; le pincement du scroll interne est désactivé pour éviter une double application. Le défileur de PDFKit est découvert par type public `UIScrollView`, sans nom de classe privé ni remplacement de son delegate. C’est un point à revérifier lors des futures mises à jour majeures de PDFKit.

## Défilement

`CADisplayLink` calcule `déplacement = pointsParSeconde × duréeÉcoulée`. Les grands intervalles sont bornés à 100 ms pour éviter un saut au retour d’une interruption. L’accumulation conserve les fractions de pixel, car UIKit arrondit les positions affichées. La plage de défilement est recalculée à chaque image ; elle suit donc le zoom et les changements de dimensions. Le moteur utilise les marges ajustées et atteint la dernière page. Le rafraîchissement de l’interface est limité à cinq fois par seconde ; la sauvegarde de progression à une fois toutes les deux secondes.

Pendant un pincement, le déplacement automatique est suspendu sans perdre l’état Lecture. Un glissement manuel met en pause. Pause/arrêt/arrière-plan et fin du document sont traités explicitement. Un proxy faible et l’invalidation du display link empêchent la rétention du contrôleur après sa fermeture.

## Import, sécurité et cohérence

Les URL externes sont ouvertes avec accès sécurisé et lues sous `NSFileCoordinator`. L’énumération et la lecture tournent hors du thread UI. Les fichiers sont traités l’un après l’autre pour éviter de charger un dossier entier en mémoire. Un nouvel import écrit d’abord une copie locale unique, puis publie le catalogue atomiquement. Si l’enregistrement du catalogue échoue, la nouvelle copie est supprimée et l’ancien état reste actif.

Un fichier modifié est associé par identité de dossier + chemin relatif. Les doublons indépendants sont identifiés par empreinte de contenu. Les favoris, playlists et réglages appartiennent à l’identifiant local et survivent au remplacement du fichier. Les anciennes copies sont conservées tant qu’un catalogue actif/de secours peut encore les référencer. Aucune suppression ni modification distante.

L’association de dossier utilise le bookmark minimal iPadOS et rééquilibre chaque `startAccessingSecurityScopedResource` réussi par un `stopAccessingSecurityScopedResource`. Un accès refusé est signalé, sans effacer les copies locales. Référence : [accès aux répertoires Apple](https://developer.apple.com/documentation/uikit/providing-access-to-directories).

## Évolution Dropbox API

Aucune intégration réseau directe actuellement. `ScoreFolderProvider` isole la résolution du fournisseur Fichiers ; `ImportedScore` et `LibraryStore.accept` isolent l’entrée de données validées du reste de l’app. Un futur fournisseur réseau devra produire les mêmes documents validés, avec un identifiant de fichier Dropbox stable comme source :

- OAuth officiel avec PKCE et session d’authentification système ; aucun mot de passe collecté.
- Jetons stockés exclusivement dans Keychain, jamais dans le catalogue.
- Scopes de lecture minimaux, gestion de révocation/expiration et pagination.
- Identifiants, révisions et curseur delta Dropbox pour les modifications/renommages.
- Pas de secret client embarqué et pas de dépendance de la lecture locale à l’authentification.

## Limites assumées

La bibliothèque JSON convient à une bibliothèque personnelle. Une collection très volumineuse pourrait justifier SwiftData/SQLite et des écritures groupées. La progression de reprise entre lancements est normalisée, pas indexée par mesure ; elle peut être approximative après une modification du document ou un changement de format d’écran. Le rendu ChordPro est personnalisé ; son contenu dessiné n’offre pas encore une lecture VoiceOver ligne par ligne. Les commandes ont des libellés accessibles.


## Mise à jour 1.1 : préférences et éditeur

`ReaderPreferences.speed` est optionnel : `nil` signifie héritage du défaut global, une valeur signifie préférence propre à l’UUID de partition. Les anciennes valeurs JSON sont conservées sans heuristique. Les nouvelles propriétés (`originalKey`, `displayKey`, `chordColor`, `Song.editing`, réglage global de couleur) sont optionnelles ; le décodeur lit donc les catalogues v1 sans perte. Les sauvegardes portent la version 2. Le moteur temporel n’a pas été modifié.

`MusicalKey` sépare tonique, mode et graphie. L’intervalle découle uniquement des toniques source/destination ; le capo n’est pas ajouté. Le transpositeur conserve les suffixes et traite les basses séparément, avec une graphie cohérente incluant les notes diatoniques comme E# et Cb. Une transposition ne modifie jamais les qualités majeures/mineures des accords. Le changement de mode est explicité dans le sélecteur.

Le problème du sélecteur était localisé dans `ReaderView` : 25 actions dans un `Menu` contextuel ancré au bas du lecteur, sans liste contrôlée par l’application. Aucun `ScrollView` SwiftUI englobant le menu et la partition n’était présent ; les gestes de la partition appartiennent à son contrôleur UIKit. `TonalityView` présente désormais une seule `List` dans une feuille modale, avec en-tête fixe et commande Terminé. Le défilement ne dépend plus de l’auto-défilement d’un long menu contextuel. Les tests UI sélectionnent Si en bas puis Do en haut dans les deux orientations.

`ChordEditorModel` conserve le texte complet. `ChordSourceEditing` applique les transformations sur les plages UTF-16 du texte source et ne sérialise pas le résultat du parseur. `ChordTextEditor` garde le même `UITextView` dans les deux orientations et pendant les bascules d’aperçu : saisie, sélection, undo/redo appartiennent à UIKit. La coloration ne remplace pas le contenu et suspend l’enregistrement d’undo pendant les changements d’attributs ; elle ne perturbe pas les compositions de clavier. Les publications dues aux notifications de sélection sont différées hors du cycle SwiftUI.

L’aperçu est actualisé après 180 ms sans nouvelle saisie. Il utilise `ChordCanvas` ; la mesure est recalculée uniquement si le texte, la présentation ou la largeur changent, pas à chaque image du défilement. Un coordinateur d’édition au niveau de `RootView` évite de détruire la feuille lorsque la nouvelle empreinte recrée le lecteur. Les sauvegardes différées d’un ancien lecteur sont rejetées si son empreinte n’est plus courante.

`LibraryStore.saveChordSource` vérifie l’empreinte attendue, écrit un nouveau fichier atomiquement puis publie le catalogue. Une erreur laisse l’ancien fichier et l’état actif intacts. L’historique retient l’original immuable et la version précédente ; le nettoyage respecte ces références, y compris dans le catalogue de secours. La restauration vérifie le hash et échange les versions sans toucher à l’UUID, aux favoris ni aux playlists.

Lors d’une actualisation de dossier, un fichier édité localement n’est pas remplacé : une source identique à l’original est ignorée, une source distante différente déclenche une erreur explicite. La comparaison/fusion reste manuelle via import séparé. Aucun jeton ou accès d’écriture Dropbox n’a été ajouté.


## Extension 1.3 : conversion, impression, diagrammes

`Printing` réutilise les mesures de `ChordCanvas` et ses débuts de lignes visuelles pour paginer un PDF A4 vectoriel. Le code brut ChordPro n’est jamais imprimé. Les PDF existants sont copiés octet pour octet. Les sorties sont proposées via les interfaces Apple (AirPrint, FileExporter, UIActivityViewController).

`Conversion` traite soit les colonnes du texte, soit les rectangles PDF/OCR. Pour PDFKit, le texte et la géométrie utilisent le même NSRange via PDFSelection : les indices de glyphes de characterBounds ne sont pas interchangeables avec les indices UTF-16 de page.string. Le worker utilise son propre PDFDocument, la progression revient sur MainActor, la cancellation est vérifiée entre les pages. Vision reconnaît du texte, jamais les notes des portées.

L’écran de comparaison réutilise ChordEditorModel, ChordTextEditor et ChordPreview. La vue native d’édition reste montée pendant les changements de panneau, préservant l’annulation. Une conversion enregistrée crée un nouvel UUID. Le nouveau champ optionnel Song.conversionOrigin référence une copie immuable de l’original ; retainedFilenames l’inclut dans la protection du nettoyage. Les deux fichiers sont écrits avant la publication du catalogue ; une erreur de publication supprime les fichiers temporaires créés, sans changer la partition précédente.

`Internet` utilise un WKWebView à stockage non persistant et URLSession pour les téléchargements directs bornés à 5 Mo. L’extraction du texte de la page est une action explicite de l’utilisateur. La navigation n’autorise que HTTP/HTTPS et ne suit pas de schéma applicatif arbitraire.

`Guitar` sépare le symbole, les doigtés et le dessin vectoriel. Les formes fermées sont transposées par translation entière, puis filtrées par leurs notes et leur basse réelles en accordage standard. Les zones tactiles sont calculées par ChordCanvas à partir du texte effectivement rendu, après transposition et zoom. Le contrôleur présente une fenêtre ancrée au rectangle de l’accord et met seulement la lecture en pause. Aucun fichier source ni préférence de zoom n’est modifié.

Le lecteur ne republie plus une progression ou un libellé de zoom inchangés à chaque échantillon ; cela évite de reconstruire inutilement ses menus pendant une pause.

## Correctif 1.3.1 : extraction musicale Internet

`WebScoreExtractor.js` est une ressource du bundle exécutée en lecture seule dans le document WKWebView affiché. L’adaptateur de La Boîte à chansons utilise les marqueurs DOM et le contenu CSS rendu. Le parcours générique travaille soit sur un bloc préformaté, soit sur les rectangles des caractères et des éléments d’accord. La sélection explicite est prioritaire ; l’absence de zone fiable est un résultat distinct, pas une invitation à convertir silencieusement `document.body`.

`WebScoreExtractor.swift` décode le résultat structuré, prépare les métadonnées et capture le rectangle source avec WKPDFConfiguration. `WebImportDiagnostics`, facultatif dans `ConversionOrigin`, conserve le diagnostic de l’import initial ; l’interface recompte séparément les accords de l’édition en cours. Les anciens catalogues et anciennes conversions se décodent sans migration destructive. Le traitement des colonnes mixtes est activé pour les pages préformatées ; les autres parcours de conversion conservent leur mode existant.

Le test de page publique est opt-in (`LIVE_WEB_VALIDATION`) et distinct des tests locaux. Les fixtures et les captures archivées ne contiennent que des créations originales. Les tests de page réelle conservent uniquement les compteurs et les résultats des assertions, sans publier de paroles ni d’original PDF.
