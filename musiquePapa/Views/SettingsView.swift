import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var choosingFolder = false
    @State private var cleanConfirmation = false
    var body: some View {
        Form {
            Section("Lecture") {
                VStack(alignment: .leading) {
                    Text("Vitesse par défaut : \(library.settings.defaultSpeed, specifier: "%.1f")")
                    Slider(value: Binding(get: { library.settings.defaultSpeed }, set: { value in library.updateSettings { $0.defaultSpeed = value } }), in: 1...10, step: 0.1)
                }
                Stepper("Taille du texte : \(Int(library.settings.defaultFontSize)) pt", value: Binding(get: { library.settings.defaultFontSize }, set: { value in library.updateSettings { $0.defaultFontSize = value } }), in: 12...64, step: 2)
                Toggle("Reprendre à la dernière position", isOn: Binding(get: { library.settings.resumePosition }, set: { value in library.updateSettings { $0.resumePosition = value } }))
                Toggle("Ouvrir la chanson suivante en fin de playlist", isOn: Binding(get: { library.settings.autoAdvance }, set: { value in library.updateSettings { $0.autoAdvance = value } }))
                Text("La chanson suivante s’ouvre en pause. La vitesse globale s’applique aux partitions sans vitesse personnalisée. Dans le lecteur, touchez la valeur de vitesse pour revenir au réglage global. Les vitesses déjà enregistrées sont conservées.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Apparence") {
                Picker("Thème", selection: Binding(get: { library.settings.theme }, set: { value in library.updateSettings { $0.theme = value } })) { Text("Système").tag("system"); Text("Clair").tag("light"); Text("Sombre").tag("dark") }
            }
            Section("Couleur des accords par défaut") {
                ChordColorControls(value: library.settings.chordColor ?? .blueDefault) { color in library.updateSettings { $0.chordColor = color } }
                Button("Rétablir le bleu par défaut") { library.updateSettings { $0.chordColor = nil } }
            }
            Section {
                Label("Dropbox via Fichiers", systemImage: "externaldrive.badge.icloud").font(.headline)
                Text("Installez Dropbox sur l’iPad, connectez-vous dans Dropbox puis activez-le dans Fichiers → Parcourir → Modifier. Choisissez ensuite vos partitions avec le bouton Importer de la bibliothèque.")
                if let folder = library.state.folder {
                    LabeledContent("Dossier associé", value: folder.name)
                    if let date = folder.lastRefresh { LabeledContent("Dernière actualisation", value: date.formatted(date: .abbreviated, time: .shortened)) }
                    Button("Actualiser les partitions", systemImage: "arrow.clockwise") { Task { await library.refreshFolder() } }.disabled(library.isImporting)
                    Button("Dissocier le dossier", role: .destructive) { library.commit { $0.folder = nil } }.disabled(library.isImporting)
                }
                Button("Choisir un dossier Dropbox", systemImage: "folder.badge.plus") { choosingFolder = true }.disabled(library.isImporting)
                if library.isImporting { ImportProgressView() }
            } header: { Text("Dropbox") } footer: {
                Text("Le choix d’un dossier et son accès ultérieur dépendent du fournisseur Fichiers. Si Dropbox refuse les dossiers, importez plusieurs fichiers. L’actualisation est manuelle ; aucune connexion permanente n’est promise. Les copies locales restent lisibles hors connexion. Une suppression dans Dropbox ne supprime jamais votre copie locale.")
            }
            Section("Stockage local") {
                LabeledContent("Partitions", value: "\(library.songs.count)")
                LabeledContent("Espace occupé", value: ByteCountFormatter.string(fromByteCount: library.storageBytes, countStyle: .file))
                Button("Nettoyer les anciennes copies") { cleanConfirmation = true }.disabled(library.isImporting)
                Button("Ajouter les partitions de démonstration", systemImage: "guitars") { Task { await DemoLibrary.install(in: library) } }.disabled(library.isImporting)
            }
            Section("MusiquePapa · \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1")") {
                Text("Conçu pour jouer tranquillement, sans publicité et sans inscription. PDF et ChordPro sont copiés dans l’application. Les transpositions et les réglages d’affichage ne modifient jamais les fichiers d’origine.")
                Text("Clavier ou pédale en mode clavier : Espace pour Lecture/Pause ; flèches gauche/droite pour les chansons d’une playlist.").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Réglages")
        .sheet(isPresented: $choosingFolder) { DocumentPicker(folder: true) { urls in choosingFolder = false; Task { await library.importFiles(urls, folder: true, link: true) } } }
        .alert("Nettoyer le stockage ?", isPresented: $cleanConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Nettoyer") { library.cleanUnusedFiles() }
        } message: { Text("Seules les anciennes copies qui ne sont plus utilisées ni dans la bibliothèque ni dans sa sauvegarde de secours seront effacées.") }
    }
}
