import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var editor: EditorCoordinator
    let onOpen: (Song, UUID?) -> Void
    @State private var internetSource: InternetSource?
    enum InternetSource: String, Identifiable { case web = "Internet", text = "Texte"; var id: String { rawValue } }
    @State private var search = ""
    @State private var sort: LibrarySort = .az
    @State private var favoritesOnly = false
    @State private var recentOnly = false
    @State private var picker: PickerKind?
    @State private var deleting: Song?
    @State private var renaming: Song?
    @State private var newTitle = ""
    enum PickerKind: String, Identifiable { case files, folder; var id: String { rawValue } }
    private var filtered: [Song] {
        sort.sorted(library.songs.filter { song in
            (!favoritesOnly || song.favorite) && (!recentOnly || song.lastOpened != nil) &&
            (search.isEmpty || song.title.localizedStandardContains(search) || song.artist.localizedStandardContains(search))
        })
    }
    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "guitars.fill").font(.system(size: 35)).foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Le plaisir de jouer").font(.title2.bold())
                        Text("\(library.songs.count) partition(s) disponibles hors connexion").foregroundStyle(.secondary)
                    }
                    Spacer()
                }.padding(.vertical, 12)
                HStack {
                    Toggle("Favoris", isOn: $favoritesOnly).toggleStyle(.button)
                    Toggle("Récentes", isOn: $recentOnly).toggleStyle(.button).onChange(of: recentOnly) { _, value in if value { sort = .recent } }
                    Spacer()
                    Menu { Picker("Classement", selection: $sort) { ForEach(LibrarySort.allCases) { Text($0.rawValue).tag($0) } } } label: { Label(sort.rawValue, systemImage: "arrow.up.arrow.down") }
                }.buttonStyle(.bordered).padding(.vertical, 4)
            }
            if library.isImporting { Section { ImportProgressView() } }
            if library.songs.isEmpty {
                Section {
                    ContentUnavailableView("Vos partitions, au même endroit", systemImage: "doc.badge.plus", description: Text("Importez depuis Fichiers ou Dropbox, ou essayez les partitions de démonstration."))
                    Button("Essayer les démonstrations", systemImage: "play.circle") { Task { await DemoLibrary.install(in: library) } }.disabled(library.isImporting)
                }
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: search)
            }
            Section("Partitions · \(filtered.count)") {
                ForEach(filtered) { song in
                    HStack(spacing: 16) {
                        Button { onOpen(song, nil) } label: { SongRow(song: song) }.buttonStyle(.plain)
                        Button { library.updateSong(song.id) { $0.favorite.toggle() } } label: {
                            Image(systemName: song.favorite ? "star.fill" : "star").font(.title3).foregroundStyle(song.favorite ? .orange : .secondary).frame(width: 44, height: 48)
                        }.buttonStyle(.borderless).accessibilityLabel(song.favorite ? "Retirer des favoris" : "Ajouter aux favoris")
                        Menu {
                            if song.format == .chordPro {
                                Button("Modifier", systemImage: "square.and.pencil") { editor.open(song.id) }
                                Button("Dupliquer cette chanson", systemImage: "plus.square.on.square") {
                                    do { editor.open(try library.duplicateChordSong(song.id)) }
                                    catch { library.error = error.localizedDescription }
                                }
                            }
                            Button("Renommer", systemImage: "pencil") { renaming = song; newTitle = song.title }
                            if !library.playlists.isEmpty {
                                Menu("Ajouter à une playlist") { ForEach(library.playlists) { playlist in Button(playlist.name) { library.updatePlaylist(playlist.id) { $0.add(song.id) } } } }
                            }
                            Button("Supprimer de la bibliothèque", systemImage: "trash", role: .destructive) { deleting = song }
                        } label: { Image(systemName: "ellipsis.circle").font(.title3).frame(width: 44, height: 48) }.accessibilityLabel("Options de \(song.title)")
                    }.padding(.vertical, 5)
                    .swipeActions { Button("Supprimer", role: .destructive) { deleting = song } }
                    .contextMenu {
                        if song.format == .chordPro {
                            Button("Modifier", systemImage: "square.and.pencil") { editor.open(song.id) }
                            Button("Dupliquer cette chanson", systemImage: "plus.square.on.square") {
                                do { editor.open(try library.duplicateChordSong(song.id)) }
                                catch { library.error = error.localizedDescription }
                            }
                        }
                        Button("Ouvrir", systemImage: "play") { onOpen(song, nil) }
                    }
                }
            }
        }
        .navigationTitle("Bibliothèque")
        .searchable(text: $search, prompt: "Titre ou artiste")
        .toolbar {
            ToolbarItem(placement: .primaryAction) { Button("Nouvelle chanson", systemImage: "square.and.pencil") { editor.open() }.disabled(library.isImporting) }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Rechercher sur Internet", systemImage: "globe") { internetSource = .web }.accessibilityIdentifier("internetImport")
                    Button("Importer depuis une URL / un texte", systemImage: "text.badge.plus") { internetSource = .text }
                    Button("Importer des fichiers", systemImage: "doc.badge.plus") { picker = .files }
                    Button("Importer un dossier", systemImage: "folder.badge.plus") { picker = .folder }
                } label: { Label("Importer", systemImage: "plus.circle.fill") }.disabled(library.isImporting)
            }
        }
        .fullScreenCover(item: $internetSource) { source in InternetImportView(initialMode: source.rawValue).environmentObject(library) }
        .sheet(item: $picker) { kind in DocumentPicker(folder: kind == .folder) { urls in picker = nil; Task { await library.importFiles(urls, folder: kind == .folder) } } }
        .alert("Supprimer cette partition ?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) { if let deleting { library.delete(deleting) }; deleting = nil }
        } message: { Text("La copie locale et ses références dans les playlists seront retirées. Le fichier d’origine reste intact.") }
        .alert("Renommer la partition", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Titre", text: $newTitle)
            Button("Annuler", role: .cancel) {}
            Button("Enregistrer") {
                let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if let song = renaming, !title.isEmpty { library.updateSong(song.id) { $0.title = title; $0.customTitle = true } }; renaming = nil
            }
        }
    }
}
struct SongRow: View {
    let song: Song
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: song.format == .pdf ? "doc.richtext" : "music.note")
                .font(.title2).foregroundStyle(.tint).frame(width: 48, height: 52)
                .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 5) {
                Text(song.title).font(.headline).foregroundStyle(.primary)
                Text(song.artist.isEmpty ? "Artiste non renseigné" : song.artist).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(song.format.label).font(.caption.bold()).foregroundStyle(.secondary).padding(7).background(.quaternary, in: Capsule())
        }.contentShape(Rectangle())
    }
}
struct ImportProgressView: View {
    @EnvironmentObject private var library: LibraryStore
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Importation en cours…", systemImage: "arrow.down.doc")
            ProgressView(value: library.importProgress)
            Text(library.importFilename).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }.padding(.vertical, 8)
    }
}
