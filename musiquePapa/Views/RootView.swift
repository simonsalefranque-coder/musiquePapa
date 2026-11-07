import SwiftUI

struct RootView: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var tab = 0
    @State private var selectedSongID: UUID?
    @State private var playlistID: UUID?
    @State private var stage = false
    @StateObject private var editor = EditorCoordinator()
    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { LibraryView(onOpen: open) }
                .tabItem { Label("Bibliothèque", systemImage: "music.note.list") }.tag(0)
            NavigationStack { PlaylistsView(onOpen: open) }
                .tabItem { Label("Playlists", systemImage: "list.bullet.rectangle") }.tag(1)
            NavigationStack {
                if let song = library.song(selectedSongID), let url = library.url(for: song) {
                    ReaderView(song: song, url: url, stage: $stage, previous: neighbor(-1), next: neighbor(1))
                        .id(song.id.uuidString + song.digest)
                } else {
                    ContentUnavailableView("À vous de jouer", systemImage: "guitars", description: Text("Ouvrez une partition dans la bibliothèque ou une playlist."))
                        .navigationTitle("Lecteur")
                }
            }.tabItem { Label("Lecteur", systemImage: "play.rectangle") }.tag(2)
            NavigationStack { SettingsView() }
                .tabItem { Label("Réglages", systemImage: "gearshape") }.tag(3)
        }
        .toolbar(stage ? .hidden : .visible, for: .tabBar)
        .environmentObject(editor)
        .fullScreenCover(item: $editor.request) { request in EditorLoader(request: request).environmentObject(library) }
        .onAppear { if selectedSongID == nil { selectedSongID = library.state.lastSongID } }
        .onChange(of: library.songs.map(\.id)) { _, ids in if let selectedSongID, !ids.contains(selectedSongID) { self.selectedSongID = nil; stage = false } }
        .alert("MusiquePapa", isPresented: Binding(get: { library.error != nil }, set: { if !$0 { library.error = nil } })) {
            Button("Compris", role: .cancel) { library.error = nil }
        } message: { Text(library.error ?? "") }
        .sheet(isPresented: Binding(get: { library.importReport != nil }, set: { if !$0 { library.importReport = nil } })) {
            NavigationStack {
                ScrollView { Text(library.importReport ?? "").frame(maxWidth: .infinity, alignment: .leading).padding(24) }
                    .navigationTitle("Résultat de l’importation")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Terminé") { library.importReport = nil } } }
            }.presentationDetents([.medium, .large])
        }
    }
    private func open(_ song: Song, _ playlist: UUID?) { selectedSongID = song.id; playlistID = playlist; library.open(song.id); tab = 2 }
    private func neighbor(_ delta: Int) -> (() -> Void)? {
        guard let playlistID, let list = library.playlists.first(where: { $0.id == playlistID }) else { return nil }
        let ids = list.songIDs.filter { library.song($0) != nil }
        guard let current = ids.firstIndex(where: { $0 == selectedSongID }), ids.indices.contains(current + delta), let song = library.song(ids[current + delta]) else { return nil }
        return { open(song, playlistID) }
    }
}
