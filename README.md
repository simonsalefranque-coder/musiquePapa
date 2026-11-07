# MusiquePapa

Application native **iPad**, en français, pour lire des partitions PDF et ChordPro. Projet SwiftUI / UIKit / PDFKit, sans dépendance externe, sans compte applicatif et sans backend. Cible minimale : **iPadOS 17**, notamment l’iPad 9e génération 10,2 pouces.

## Correctif 1.3.1 — importation Internet

Les accords affichés par le CSS sont récupérés avec leurs paroles. L’import cible la zone musicale, ajoute un diagnostic d’accords et conserve une copie visuelle de la source pour la comparaison. Les accords comme `Am7/4` sont reconnus. En l’absence de zone fiable, une sélection ou une correction explicite est proposée.

Le [guide du correctif Internet](Documentation/CORRECTION_INTERNET_1.3.1.md) explique la cause, les fichiers modifiés, les limites et la vérification sur iPad. Les résultats vérifiés sont dans [TESTS.md](Documentation/TESTS.md).

## Nouveautés 1.3

- Internet : recherche dans un navigateur intégré, import direct d’une URL texte et conversion de texte collé.
- PDF vers ChordPro : extraction du texte ou OCR local, comparaison avec l’original et correction dans l’éditeur existant.
- Accords tactiles : diagrammes, positions alternatives, transposition et indication du capo ; lecture mise en pause.
- Impression AirPrint et export PDF A4 : aperçu, couleur/noir et blanc, taille du texte, Fichiers et partage Apple.

Le [guide de mise à jour 3](Documentation/MISE_A_JOUR_3.md) détaille les commandes, les limites de conversion et les vérifications sur iPad. Les sources originales et les données existantes sont conservées.

## Ouvrir et essayer

1. Ouvrir **musiquePapa.xcodeproj** dans Xcode. Aucun générateur ni téléchargement de paquet n’est nécessaire.
2. Choisir le schéma **musiquePapa** puis un simulateur **iPad** dans la barre supérieure.
3. Cliquer sur ▶︎ (ou `⌘R`).
4. Dans la bibliothèque, toucher **Essayer les démonstrations**. Deux créations originales sont incluses : une chanson ChordPro et un PDF vectoriel de dix pages.

Les écrans sont Bibliothèque, Playlists, Lecteur et Réglages. Sur certaines versions récentes d’iPadOS, les onglets sont affichés en haut par le système.

## Installer sur votre iPad 9

Il n’y a aucun code à écrire ou à recopier.

1. Vérifier que l’iPad utilise iPadOS 17 ou une version ultérieure.
2. Brancher l’iPad au Mac, le déverrouiller et accepter **Faire confiance** si demandé.
3. Dans Xcode → Settings → Accounts, ajouter votre compte Apple si nécessaire.
4. Ouvrir le projet, sélectionner la cible **musiquePapa** → **Signing & Capabilities**. Garder **Automatically manage signing**, puis choisir votre **Personal Team** ou votre équipe existante.
5. Pour cette mise à jour, conserver le **Bundle Identifier** et l’équipe déjà utilisés. Changer l’identifiant crée une autre application et ne reprend pas automatiquement la bibliothèque existante.
6. Choisir votre iPad comme destination à côté du schéma **musiquePapa**, puis cliquer sur ▶︎.
7. Si demandé, activer **Mode développeur** sur l’iPad dans Réglages → Confidentialité et sécurité, puis suivre le redémarrage indiqué. Autoriser éventuellement le profil dans Réglages → Général → VPN et gestion de l’appareil.

Un compte Apple gratuit permet l’installation de développement. Apple impose actuellement une expiration du profil après **7 jours** : il faut alors relancer l’installation depuis Xcode, avec le même identifiant, sans supprimer l’application afin de conserver la bibliothèque. Aucun abonnement n’est nécessaire pour le fonctionnement local ; l’installation gratuite n’est pas permanente. Voir [les limites Personal Team d’Apple](https://developer.apple.com/help/account/basics/about-your-developer-account) et [l’installation sur un appareil](https://help.apple.com/xcode/mac/current/en.lproj/dev5a825a1ca.html).

La signature dépend de votre compte Apple et de l’iPad connecté ; aucun compte ni certificat personnel n’est intégré au dépôt. La compilation non signée ne constitue pas un paquet directement installable sur un appareil physique.

## Importer depuis Dropbox

1. Installer Dropbox sur l’iPad et s’y connecter dans l’application Dropbox.
2. Ouvrir **Fichiers → Parcourir → … → Modifier**, puis activer Dropbox.
3. Dans MusiquePapa, utiliser **Bibliothèque → Importer → Importer des fichiers** et choisir Dropbox. La sélection multiple est prise en charge.
4. Pour un dossier complet, choisir **Importer un dossier**. Les sous-dossiers sont parcourus ; les fichiers non pris en charge sont ignorés. La disponibilité de la sélection de dossier dépend du fournisseur.
5. Pour conserver une association, utiliser **Réglages → Dropbox → Choisir un dossier Dropbox**, puis **Actualiser les partitions** lors des mises à jour.

Les fichiers sont téléchargés puis copiés dans le stockage privé de MusiquePapa : **ils restent lisibles hors connexion après importation réussie**. Une connexion peut être nécessaire pendant l’importation depuis Dropbox. [Guide officiel Dropbox pour Fichiers](https://help.dropbox.com/integrations/ios-files-app).

L’actualisation est manuelle. L’app conserve un bookmark iPadOS, redemande de choisir le dossier si l’accès expire et affiche les erreurs par fichier. Les nouveaux fichiers sont ajoutés ; les fichiers modifiés au même chemin relatif sont remplacés en conservant leur identité, favoris, titre personnalisé, réglages et appartenance aux playlists. Si la copie a été modifiée dans l’éditeur, une modification distante est signalée et ne remplace jamais votre travail local. Pour comparer, importer séparément le fichier distant depuis Fichiers ; il devient une nouvelle partition si son contenu diffère. Une suppression distante n’efface jamais une partition locale. Un déplacement ou renommage distant avec un contenu modifié peut être interprété comme un nouveau document.

La détection des doublons compare le SHA-256 du contenu. Deux fichiers identiques ne créent pas deux entrées. Les PDF dont les métadonnées binaires diffèrent peuvent rester distincts même s’ils ont le même aspect. Aucun mot de passe Dropbox, jeton OAuth ni secret n’est demandé. L’API Dropbox directe n’est pas implémentée et aucun faux bouton de connexion n’est affiché.

## Lire et jouer

- **PDF** : défilement vertical continu sur toutes les pages ; pincement à deux doigts ; double-tap pour agrandir autour d’un point ; boutons +/− ; menu Ajuster à la largeur / à la page. Le rendu reste vectoriel. Déplacement horizontal disponible après agrandissement. Le zoom choisi n’est pas réinitialisé au changement de page.
- **ChordPro** : pincement ou A+/A− entre 12 et 64 pt. Accords de couleur personnalisable, paroles lisibles, refrains sur fond discret, tablatures monospace sans suppression des espaces. Les mots sont réorganisés si nécessaire ; les tablatures longues défilent horizontalement. Panneau Tonalité : choix direct parmi les 12 notes, dièses/bémols et modes majeur/mineur ; réglage en demi-tons conservé de −12 à +12, y compris les basses (`D/F#`). Capo, tonalité et tempo sont affichés lorsqu’ils sont renseignés.
- **Lecture** : défilement continu à vitesse réglable de 1 à 10 par pas de 0,1. **Pause** conserve la position ; **Arrêt** met en pause et revient au début ; **Retour au début** conserve l’état lecture/pause.
- Un glissement manuel à un doigt met en pause et permet de remonter. Un pincement suspend le déplacement pendant le geste, puis poursuit si la lecture était active. Le point musical visible est conservé autant que possible pendant l’agrandissement.
- La vitesse, la taille du texte / le zoom PDF, la transposition et la progression sont mémorisés pour chaque chanson. Pendant la consultation, la position est enregistrée au plus toutes les deux secondes, et lors des actions ou de la mise en arrière-plan.
- Le mode scène masque les distractions ; un bouton flottant masque/affiche les commandes. L’écran reste allumé en lecture ou en mode scène. Le passage en arrière-plan met la lecture en pause.
- Playlists : créer, renommer, ajouter des chansons ; **Modifier** affiche les poignées permettant de réordonner par glisser-déposer. Retirer une chanson d’une playlist ne la supprime pas de la bibliothèque. Les boutons précédent/suivant suivent cet ordre.
- L’option d’ouverture automatique de la chanson suivante ouvre celle-ci **en pause**, pour éviter un départ inattendu. Elle n’a d’effet qu’après ouverture depuis une playlist.
- Clavier / pédale configurée comme clavier : Espace = lecture/pause ; flèches gauche/droite = chanson précédente/suivante. La compatibilité d’une pédale particulière reste à vérifier sur appareil.

## Mise à jour 1.1 : tonalités, couleurs et éditeur

Les données de la version précédente sont lues directement. Aucun import à refaire, aucune suppression de bibliothèque. Les identifiants, playlists, favoris, zooms et vitesses déjà enregistrées sont conservés. Le catalogue passe en version 2 lors de sa prochaine sauvegarde.

- **Tonalité** : ouvrir le panneau du lecteur. « Origine » reprend `{key: ...}` ; si la chanson n’en possède pas, choisir sa note et son mode dans Origine. « Affichage » choisit la destination. Les deux choix restent distincts du capo. Choisir une autre note transpose les accords sans modifier le fichier. Les qualités `m`, `7`, `maj7`, les basses et les paroles sont préservées. Changer de mode ne transforme pas automatiquement une chanson majeure en mineure : ce serait une réharmonisation, pas une simple transposition. Le panneau l’indique lorsque les modes diffèrent.
- **Couleur** : toucher la palette du lecteur pour choisir la couleur de cette chanson. Sept couleurs et le sélecteur personnalisé sont disponibles. « Rétablir la couleur par défaut » supprime la préférence propre au morceau. Le défaut se choisit dans Réglages. La luminosité s’adapte au thème pour garder les accords lisibles ; les paroles et les autres styles restent inchangés.
- **Vitesse** : déplacer le curseur mémorise immédiatement une préférence pour cette partition, PDF ou ChordPro. Toucher la valeur chiffrée puis « Rétablir la vitesse globale » pour supprimer cette préférence. Les nouvelles chansons héritent du défaut global tant qu’aucune vitesse particulière n’est choisie. Les vitesses de l’ancienne version restent des préférences individuelles, car on ne peut pas savoir rétrospectivement lesquelles avaient été réglées manuellement.

### Modifier ou créer une chanson

1. Dans un lecteur ChordPro, toucher **Modifier**. La bibliothèque propose aussi **Nouvelle chanson** et, dans les options d’une chanson, **Modifier** et **Dupliquer cette chanson**.
2. Écrire dans le texte coloré. Les accords sont bleus, les directives violettes, les commentaires verts ; un soulignement orange signale une syntaxe suspecte. Les fonctions de sélection, copie, collage et annulation d’iPadOS restent disponibles. Utiliser les flèches Annuler/Rétablir, A−/A+ ou pincer pour zoomer l’édition.
3. La barre **Accords** propose les notes, les altérations et les types courants. Un accord est inséré au curseur, ou **au début d’une sélection sans effacer les paroles sélectionnées**. Le champ libre accepte notamment `F#m7/C#`. Les barres d’outils peuvent défiler horizontalement sur un écran étroit.
4. **Insérer** ajoute les directives. Sélectionner un passage puis choisir Couplet, Refrain ou Tablature l’entoure avec les directives de début et de fin.
5. **Informations** modifie titre, artiste, tonalité d’origine, capo, tempo et sous-titre. Les alias correspondants sont remplacés sans créer de doublons ; les autres directives sont conservées.
6. **Aperçu** bascule le rendu en portrait. Sur une largeur d’au moins 900 points, notamment l’iPad 9 en paysage plein écran, le code et le rendu s’affichent côte à côte. Le rendu utilise les mêmes accords alignés, transposition et couleur que le lecteur. Le curseur et l’historique d’annulation survivent aux changements de présentation.
7. **Enregistrer** écrit une nouvelle copie locale UTF-8 et met immédiatement à jour la bibliothèque et le lecteur. **Annuler** demande confirmation si du texte a changé. Un échec de sauvegarde conserve l’éditeur et le document enregistré.
8. Le menu **…** permet de restaurer la version enregistrée précédente, exporter vers Fichiers, partager le ChordPro, rechercher/remplacer et transposer les accords d’une sélection. La restauration demande confirmation et garde à son tour la version qu’elle remplace.

Les modifications ne sont jamais écrites automatiquement dans Dropbox. L’original local d’avant édition et une version précédente sont protégés du nettoyage. L’éditeur garde le texte source, y compris les directives SongBook inconnues et les espaces de tablature ; il ne reconstruit pas le fichier à partir du rendu. Le brouillon non enregistré reste en mémoire : enregistrer avant de fermer volontairement l’application. Pour préserver la fluidité, l’édition est limitée aux fichiers de 5 Mo ; les fichiers plus grands restent lisibles dans le lecteur.

Le guide de vérification de cette version se trouve dans [Documentation/MISE_A_JOUR_1_1.md](Documentation/MISE_A_JOUR_1_1.md).

## Formats et limites

PDF et `.pro`, `.chordpro`, `.chopro`, `.cho`, `.txt` contenant de la notation ChordPro. Décodage UTF-8 (avec ou sans BOM), UTF-16 avec BOM, Windows-1252 et ISO-8859-1. Les directives principales SongBook et leurs alias sont prises en charge. Les directives inconnues ne sont pas rendues et sont comptées dans le lecteur ; leur texte reste intact dans l’éditeur et lors de l’enregistrement. Pas de diagrammes d’accords, grilles graphiques complexes ni rendu de toutes les extensions ChordPro.

Les PDF vides, corrompus ou verrouillés par mot de passe sont refusés. Une limite de 100 Mo par fichier prévient les imports excessifs. Les erreurs n’empêchent pas l’importation des autres fichiers du lot.

L’ouverture depuis une autre application utilise les types documentaires iPadOS et `onOpenURL` ; ce n’est pas une extension de partage dédiée. Métronome et connexion directe OAuth Dropbox sont reportés pour privilégier les fonctions principales.

## Données et maintenance

Catalogue JSON versionné et sauvegardé par écriture atomique dans `Application Support/MusiquePapa/bibliotheque.json`. Copie de secours `bibliotheque.backup.json` et documents dans `Partitions/`. Le catalogue précédent reste récupérable en cas de corruption. Un document remplacé ou supprimé peut subsister dans la sauvegarde de secours ; **Réglages → Nettoyer les anciennes copies** retire les copies qui ne sont plus référencées par les deux catalogues, les originaux protégés et les versions précédentes restaurables. Ne pas supprimer l’app pour la réinstaller : une désinstallation iPadOS efface ses données locales.

Architecture détaillée : [Documentation/ARCHITECTURE.md](Documentation/ARCHITECTURE.md). Tests et vérifications : [Documentation/TESTS.md](Documentation/TESTS.md).

Les fichiers UIKit du squelette initial, y compris le storyboard déjà modifié avant cette intervention, sont conservés et exclus de la cible. `OriginalTemplate/` en contient aussi une copie de référence.
