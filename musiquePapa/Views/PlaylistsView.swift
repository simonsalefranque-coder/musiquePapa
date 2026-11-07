import SwiftUI

struct PlaylistsView: View {
    @EnvironmentObject private var library: LibraryStore
    let onOpen: (Song, UUID?) -> Void
    @State private var creating = false
    @State private var name = ""
    @State private var deleting: Playlist?
    var body: some View {
        List {
            if library.playlists.isEmpty {
                ContentUnavailableView("Préparez votre prochain moment musical", systemImage: "music.note.list", description: Text("Créez une playlist, puis ajoutez vos chansons dans l’ordre de votre choix."))
            }
            ForEach(library.playlists) { playlist in
                NavigationLink {
                    PlaylistDetailView(playlistID: playlist.id, onOpen: onOpen)
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "list.bullet.rectangle.fill").font(.largeTitle).foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 5) { Text(playlist.name).font(.title3.bold()); Text("\(playlist.songIDs.count) partition(s)").foregroundStyle(.secondary) }
                    }.padding(.vertical, 10)
                }.swipeActions { Button("Supprimer", role: .destructive) { deleting = playlist } }
            }
        }
        .navigationTitle("Playlists")
        .toolbar { Button("Créer", systemImage: "plus.circle.fill") { name = ""; creating = true } }
        .alert("Nouvelle playlist", isPresented: $creating) {
            TextField("Ex. Répétition", text: $name)
            Button("Annuler", role: .cancel) {}
            Button("Créer") { library.createPlaylist(name) }
        }
        .alert("Supprimer la playlist ?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) { if let deleting { library.deletePlaylist(deleting.id) }; deleting = nil }
        } message: { Text("Les partitions resteront dans la bibliothèque.") }
    }
}
struct PlaylistDetailView: View {
    @EnvironmentObject private var library: LibraryStore
    let playlistID: UUID
    let onOpen: (Song, UUID?) -> Void
    @State private var adding = false
    @State private var renaming = false
    @State private var name = ""
    private var playlist: Playlist? { library.playlists.first { $0.id == playlistID } }
    var body: some View {
        List {
            Section {
                Text("Touchez une chanson pour jouer. Utilisez Modifier pour changer l’ordre avec les poignées à droite.").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(playlist?.songIDs ?? [], id: \.self) { id in
                if let song = library.song(id) { Button { onOpen(song, playlistID) } label: { SongRow(song: song).padding(.vertical, 6) }.buttonStyle(.plain) }
            }
            .onMove { from, to in library.updatePlaylist(playlistID) { $0.songIDs.move(fromOffsets: from, toOffset: to) } }
            .onDelete { offsets in library.updatePlaylist(playlistID) { $0.songIDs.remove(atOffsets: offsets) } }
            Button("Ajouter des partitions", systemImage: "plus") { adding = true }
        }
        .navigationTitle(playlist?.name ?? "Playlist")
        .toolbar {
            ToolbarItem { Button("Renommer") { name = playlist?.name ?? ""; renaming = true } }
            ToolbarItem { EditButton() }
        }
        .alert("Renommer la playlist", isPresented: $renaming) {
            TextField("Nom", text: $name)
            Button("Annuler", role: .cancel) {}
            Button("Enregistrer") { let clean = name.trimmingCharacters(in: .whitespacesAndNewlines); if !clean.isEmpty { library.updatePlaylist(playlistID) { $0.name = clean } } }
        }
        .sheet(isPresented: $adding) { AddSongsView(playlistID: playlistID) }
    }
}
struct AddSongsView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    let playlistID: UUID
    @State private var search = ""
    var body: some View {
        NavigationStack {
            List(LibrarySort.az.sorted(library.songs).filter { search.isEmpty || $0.title.localizedStandardContains(search) || $0.artist.localizedStandardContains(search) }) { song in
                let included = library.playlists.first { $0.id == playlistID }?.songIDs.contains(song.id) == true
                Button {
                    library.updatePlaylist(playlistID) { if included { $0.songIDs.removeAll { $0 == song.id } } else { $0.add(song.id) } }
                } label: {
                    HStack { SongRow(song: song); Image(systemName: included ? "checkmark.circle.fill" : "circle").font(.title2) }
                }.buttonStyle(.plain).accessibilityLabel("\(song.title), \(included ? "ajoutée" : "non ajoutée")")
            }
            .searchable(text: $search, prompt: "Titre ou artiste")
            .navigationTitle("Ajouter des partitions")
            .toolbar { Button("Terminé") { dismiss() } }
        }
    }
}
