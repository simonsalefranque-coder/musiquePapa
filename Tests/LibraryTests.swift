import XCTest
import PDFKit
@testable import musiquePapa

@MainActor
final class LibraryTests: XCTestCase {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
    private func imported(_ title: String, source: String? = nil) throws -> ImportedScore {
        try DocumentImportService.validate(Data("{title: \(title)}\n{artist: Papa}\n[Am]Bonjour".utf8), filename: "essai.pro", source: source)
    }
    func testImportDeduplicationAndOfflinePersistence() throws {
        let root = try directory(); let store = LibraryStore(directory: root)
        XCTAssertEqual(try store.accept(imported("Été")), "added")
        XCTAssertEqual(try store.accept(imported("Été")), "unchanged")
        XCTAssertEqual(store.songs.count, 1)
        let id = try XCTUnwrap(store.songs.first?.id)
        store.updateSong(id) { $0.favorite = true; $0.preferences.pdfScale = 2.3; $0.preferences.fontSize = 36; $0.preferences.progress = 0.7 }
        store.open(id)
        store.createPlaylist("Concert"); let playlistID = try XCTUnwrap(store.playlists.first?.id)
        store.updatePlaylist(playlistID) { $0.add(id); $0.add(id) }
        let reopened = LibraryStore(directory: root)
        XCTAssertEqual(reopened.songs.count, 1); XCTAssertEqual(reopened.state.lastSongID, id)
        XCTAssertEqual(reopened.songs[0].preferences.fontSize, 36); XCTAssertEqual(reopened.songs[0].preferences.progress, 0.7)
        XCTAssertTrue(reopened.songs[0].favorite); XCTAssertEqual(reopened.playlists[0].songIDs, [id])
        let local = try XCTUnwrap(reopened.url(for: reopened.songs[0]))
        XCTAssertEqual(try ChordProParser.parse(ChordProParser.decode(Data(contentsOf: local))).title, "Été")
    }
    func testRefreshPreservesIdentityFavoritesCustomTitleAndPlaylist() throws {
        let store = LibraryStore(directory: try directory())
        try store.accept(imported("Original", source: "folder/song.pro"))
        let id = store.songs[0].id
        store.updateSong(id) { $0.title = "Mon titre"; $0.customTitle = true; $0.favorite = true; $0.preferences.transpose = 3 }
        store.createPlaylist("Scène"); let listID = store.playlists[0].id
        store.updatePlaylist(listID) { $0.add(id) }
        XCTAssertEqual(try store.accept(imported("Modifié", source: "folder/song.pro")), "updated")
        XCTAssertEqual(store.songs.count, 1); XCTAssertEqual(store.songs[0].id, id)
        XCTAssertEqual(store.songs[0].title, "Mon titre"); XCTAssertTrue(store.songs[0].favorite)
        XCTAssertEqual(store.songs[0].preferences.transpose, 3); XCTAssertEqual(store.playlists[0].songIDs, [id])
        store.delete(store.songs[0]); XCTAssertTrue(store.songs.isEmpty); XCTAssertTrue(store.playlists[0].songIDs.isEmpty)
    }
    func testPlaylistOrderingRenamingAndRemovalIndependentOfLibrary() throws {
        let store = LibraryStore(directory: try directory())
        try store.accept(imported("Zèbre")); try store.accept(imported("Arbre")); try store.accept(imported("Été"))
        let ids = store.songs.map(\.id)
        store.createPlaylist("Répétition"); let id = store.playlists[0].id
        store.updatePlaylist(id) { $0.songIDs = ids; $0.songIDs.move(fromOffsets: IndexSet(integer: 2), toOffset: 0); $0.name = "Concert" }
        XCTAssertEqual(store.playlists[0].songIDs, [ids[2], ids[0], ids[1]])
        XCTAssertEqual(LibrarySort.az.sorted(store.songs).map(\.title), ["Arbre", "Été", "Zèbre"])
        XCTAssertEqual(LibrarySort.za.sorted(store.songs).map(\.title), ["Zèbre", "Été", "Arbre"])
        store.updatePlaylist(id) { $0.songIDs.removeFirst() }; XCTAssertEqual(store.songs.count, 3)
        store.deletePlaylist(id); XCTAssertEqual(store.songs.count, 3)
    }
    func testCorruptMetadataRecoversBackupAndKeepsFiles() throws {
        let root = try directory(); let store = LibraryStore(directory: root)
        try store.accept(imported("Sauvegarde")); store.createPlaylist("Secours")
        let persistence = try LibraryPersistence(directory: root)
        try Data("invalide".utf8).write(to: persistence.metadataURL)
        let recovered = LibraryStore(directory: root)
        XCTAssertEqual(recovered.songs.count, 1); XCTAssertNotNil(recovered.error)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(recovered.url(for: recovered.songs[0])).path))
    }
    func testFolderImportAndRefreshFromLocalProvider() async throws {
        let folder = try directory()
        let file = folder.appendingPathComponent("partition.pro")
        try Data("{title: Dossier}\n[C]Essai".utf8).write(to: file)
        try Data("ignorer".utf8).write(to: folder.appendingPathComponent("image.jpg"))
        let store = LibraryStore(directory: try directory())
        await store.importFiles([folder], folder: true, link: true)
        XCTAssertEqual(store.songs.count, 1); XCTAssertNotNil(store.state.folder?.lastRefresh)
        let id = try XCTUnwrap(store.songs.first?.id)
        try Data("{title: Dossier modifié}\n[G]Suite".utf8).write(to: file)
        await store.refreshFolder()
        XCTAssertEqual(store.songs.count, 1); XCTAssertEqual(store.songs[0].id, id); XCTAssertEqual(store.songs[0].title, "Dossier modifié")
    }
    func testDuplicateSourcePathsCanDivergeWithoutOverwritingEachOther() throws {
        let store = LibraryStore(directory: try directory())
        try store.accept(imported("Identique", source: "folder/A.pro"))
        let canonicalID = store.songs[0].id
        try store.accept(imported("Identique", source: "folder/B.pro"))
        XCTAssertEqual(store.songs.count, 1)
        try store.accept(imported("Version B", source: "folder/B.pro"))
        XCTAssertEqual(store.songs.count, 2)
        XCTAssertEqual(store.song(canonicalID)?.title, "Identique")
        XCTAssertEqual(try store.accept(imported("Identique", source: "folder/A.pro")), "unchanged")
        XCTAssertEqual(try store.accept(imported("Version B", source: "folder/B.pro")), "unchanged")
        XCTAssertEqual(store.songs.count, 2)
    }
    func testPDFAndInvalidFiles() throws {
        let pdfURL = try XCTUnwrap(Bundle.main.url(forResource: "Exercice_10_pages", withExtension: "pdf"))
        let score = try DocumentImportService.read(pdfURL)
        XCTAssertEqual(score.format, .pdf)
        XCTAssertEqual(PDFDocument(data: score.data)?.pageCount, 10)
        XCTAssertThrowsError(try DocumentImportService.validate(Data("non PDF".utf8), filename: "invalide.pdf"))
        XCTAssertThrowsError(try DocumentImportService.validate(Data("texte ordinaire".utf8), filename: "notes.txt"))
        XCTAssertThrowsError(try DocumentImportService.validate(Data(), filename: "vide.pro"))
    }
}
