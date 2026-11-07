# MusiquePapa 1.1 — Guide de mise à jour

## Installer sans perdre la bibliothèque

Ouvrir `musiquePapa.xcodeproj`, choisir le schéma **musiquePapa**, brancher et déverrouiller l’iPad, le choisir comme destination puis utiliser **Product → Run** (`⌘R`). Conserver l’équipe de signature et le Bundle Identifier existants. Ne pas désinstaller l’application : Xcode doit mettre à jour l’installation existante.

La version 1.1 lit le catalogue précédent sans réimportation. Les chansons, identifiants, favoris, playlists et réglages enregistrés sont conservés. Aucune partition d’un compte Dropbox n’est modifiée par cette mise à jour.

## Vérifier les cinq nouveautés sur l’iPad 9

### 1. Menu Tonalité

Ouvrir une chanson ChordPro et toucher **Tonalité** dans les commandes du lecteur. Faire défiler vers Si, puis remonter jusqu’à Do. Refaire le geste en paysage. La liste défile indépendamment de la partition, avec un bouton Terminé toujours accessible. Les demi-tons sont disponibles en bas de liste.

### 2. Tonalité d’origine et d’affichage

Avec une chanson en Do, sélectionner **Affichage → Majeur → Ré** : C doit devenir D, Am doit devenir Bm, C/G doit devenir D/A. Avec une chanson en La mineur, sélectionner Mi mineur : Am devient Em. Les paroles et le capo restent inchangés. Fermer et rouvrir la chanson pour vérifier le choix mémorisé.

Sans directive `{key: ...}`, sélectionner d’abord **Origine**, puis la note et le mode du fichier. Ce réglage ne réécrit pas le fichier. La transposition conserve toujours les qualités des accords : sélectionner un autre mode ne réharmonise pas automatiquement le morceau. Le panneau signale cette distinction.

### 3. Couleurs

Toucher la **palette** du lecteur, choisir Rouge puis Terminé. Les accords deviennent rouges ; les paroles, titres de sections, commentaires et tablatures gardent leur style. Agrandir et rouvrir la chanson. Choisir ensuite une couleur par défaut dans **Réglages → Couleur des accords par défaut**. La chanson conserve son choix propre jusqu’à **Rétablir la couleur par défaut**. Le sélecteur natif permet une couleur personnalisée. Noir, blanc et les couleurs trop peu contrastées adaptent leur luminosité au thème.

### 4. Vitesses

Régler une chanson sur 4, une autre sur 7, revenir à la première puis fermer et rouvrir l’application. La première doit revenir à 4. Répéter avec un PDF. Toucher le chiffre de vitesse, puis **Rétablir la vitesse globale** pour supprimer la préférence individuelle. Les anciennes vitesses restent conservées ; les nouvelles chansons sans préférence héritent du défaut global.

### 5. Éditeur ChordPro

1. Ouvrir **Bibliothèque → Nouvelle chanson**, ou **Modifier** dans un lecteur ChordPro. Les PDF ne proposent pas cet éditeur.
2. Ouvrir **Informations**, changer titre et artiste, puis Appliquer. Les directives correspondantes changent dans le texte.
3. Placer le curseur dans les paroles et toucher un accord de la barre. Pour un accord plus complexe, utiliser les altérations/types ou le champ libre. Une sélection de paroles n’est pas effacée : l’accord est ajouté devant elle.
4. Sélectionner un passage et utiliser **Insérer → Refrain**. Vérifier les directives de début et fin autour du passage.
5. Utiliser Annuler/Rétablir, A+/A− et le pincement dans l’éditeur. Le texte reste sélectionnable et copiable normalement.
6. Toucher l’icône œil **Aperçu** en portrait. Tourner en paysage plein écran : le code et le rendu s’affichent côte à côte. Les accords restent alignés au-dessus des paroles.
7. Enregistrer, rouvrir le lecteur puis l’éditeur : vérifier les paroles accentuées et les directives SongBook supplémentaires. Dans l’éditeur, celles-ci sont conservées même si le lecteur ne sait pas les afficher.
8. Modifier à nouveau, toucher Annuler et choisir **Abandonner les modifications**. Le texte enregistré doit rester intact.
9. Après une sauvegarde, ouvrir **… → Restaurer la version précédente**. La restauration demande confirmation et conserve à son tour la version remplacée.
10. **… → Exporter le fichier ChordPro** enregistre un fichier dans Fichiers. **Partager le fichier ChordPro** ouvre la feuille de partage native ; choisir soi-même la destination. Aucun envoi n’est fait automatiquement.

Le menu … propose aussi recherche/remplacement et transposition d’accords sélectionnés. Les barres d’outils se déplacent horizontalement si tout ne tient pas à l’écran.

## Actualisation Dropbox et modifications locales

Une actualisation peut remplacer une partition qui n’a pas été éditée localement. Dès qu’un morceau est modifié dans MusiquePapa, une version distante différente provoque un message dans le rapport d’importation et le texte local reste conservé. Pour comparer, importer séparément le fichier distant depuis Fichiers. Il n’y a ni écriture automatique dans Dropbox ni fusion silencieuse.

Les sauvegardes créent un fichier local distinct, puis mettent à jour le catalogue atomiquement. L’original et la version précédente sont protégés du nettoyage. Un échec d’écriture ne remplace pas la version active. Un brouillon non enregistré reste en mémoire : enregistrer avant de fermer volontairement l’application.

## Principaux fichiers

- `Views/TonalityView.swift` : liste de tonalités indépendante des gestes du lecteur.
- `ChordPro/MusicalKey.swift`, `Transposer.swift`, `ChordCanvas.swift` : tonalités, graphie des accords, rendu et couleur.
- `Models/LibraryModels.swift`, `Models/ChordColor.swift` : préférences compatibles avec les données précédentes et couleurs adaptatives.
- `Editor/` : saisie UIKit, coloration, outils, informations, aperçu et export.
- `ViewModels/LibraryStore.swift` : sauvegarde locale, restauration, protection lors d’une actualisation et migration du catalogue.
- `PDF/ScoreReaderController.swift`, `ViewModels/ReaderSession.swift` : application des préférences sans recréer le lecteur ni modifier le moteur de défilement.
- `Tests/UpdateTests.swift`, `Tests/ReaderTests.swift`, `UITests/MusiquePapaUITests.swift` : vérifications automatisées.

Les détails d’architecture et de validation sont dans `ARCHITECTURE.md` et `TESTS.md`.

## Limites

L’éditeur accepte les sources jusqu’à 5 Mo pour préserver sa fluidité. Les fichiers plus grands restent lisibles. La version précédente est restaurable, mais il ne s’agit pas d’un historique illimité. L’aperçu côte à côte nécessite au moins 900 points de largeur ; une fenêtre iPad réduite utilise la bascule Édition/Aperçu. Les directives inconnues sont conservées dans le fichier mais ne sont pas toutes rendues. La transposition conserve la nature des accords et ne réalise pas de réharmonisation majeure/mineure.

Les essais automatisés utilisent un simulateur iPad 9. Les essais tactiles sur l’iPad physique et avec le vrai compte Dropbox restent à effectuer.
