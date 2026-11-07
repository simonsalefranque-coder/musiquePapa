import XCTest
import SwiftUI
@testable import musiquePapa

@MainActor final class UpdateTests: XCTestCase {
    private func directory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
    private let source = "{t: Été}\n{artist: Papa}\n{key: C}\n{capo: 2}\n{future_songbook: garder EXACTEMENT}\n\n[Cmaj7]Été [Am7]à vélo [F/G]ici\n{sot}\ne|--0   2--|\n{eot}\n"
    private func imported(_ source: String, path: String? = nil) throws -> ImportedScore {
        try DocumentImportService.validate(Data(source.utf8), filename: "source.pro", source: path)
    }
    func testAllTonalitiesModesAndConsistentChordSpelling() {
        XCTAssertEqual(MusicalKey.chromatic.count, 12)
        let c = MusicalKey(tonic: "C")
        for names in MusicalKey.chromatic {
            for tonic in names {
                for mode in MusicalKey.Mode.allCases {
                    let key = MusicalKey(tonic: tonic, mode: mode)
                    XCTAssertEqual(MusicalKey.parse(key.symbol), key)
                    XCTAssertEqual(Transposer.transpose("C", by: c.interval(to: key), in: key), tonic)
                }
            }
        }
        XCTAssertEqual(MusicalKey.parse("Mi mineur"), MusicalKey(tonic: "E", mode: .minor))
        XCTAssertEqual(MusicalKey.parse("Ré♭ majeur"), MusicalKey(tonic: "Db"))
        XCTAssertNil(MusicalKey.parse("inconnue"))
        let target = MusicalKey(tonic: "Db")
        XCTAssertEqual(Transposer.transpose("Am7", by: 1, in: target), "Bbm7")
        XCTAssertEqual(Transposer.transpose("C/G", by: 1, in: target), "Db/Ab")
        XCTAssertEqual(Transposer.transpose("F#m", by: 1, in: target), "Gm")
        XCTAssertEqual(Transposer.transpose("Bbmaj7", by: 1, in: target), "Bmaj7")
        XCTAssertEqual(Transposer.transpose("E", by: 1, in: MusicalKey(tonic: "F#")), "E#")
        var preferences = ReaderPreferences(); preferences.displayKey = MusicalKey(tonic: "E", mode: .minor)
        XCTAssertEqual(preferences.interval("Am"), -5)
        preferences.originalKey = MusicalKey(tonic: "D", mode: .minor)
        XCTAssertEqual(preferences.interval("Am"), 2)
    }
    func testLegacyCatalogMigratesWithoutLosingDataOrSpeed() throws {
        let root = try directory(), store = LibraryStore(directory: root)
        try store.accept(imported(source)); let id = store.songs[0].id
        store.updateSong(id) { $0.favorite = true; $0.preferences.speed = 7; $0.preferences.transpose = -3 }
        store.createPlaylist("Concert"); store.updatePlaylist(store.playlists[0].id) { $0.add(id) }
        let storage = try LibraryPersistence(directory: root)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: storage.metadataURL)) as? [String: Any])
        json["version"] = 1
        try JSONSerialization.data(withJSONObject: json).write(to: storage.metadataURL)
        let reopened = LibraryStore(directory: root)
        XCTAssertNil(reopened.error); XCTAssertEqual(reopened.songs[0].id, id)
        XCTAssertEqual(reopened.songs[0].preferences.speed, 7); XCTAssertEqual(reopened.songs[0].preferences.transpose, -3)
        XCTAssertNil(reopened.songs[0].preferences.displayKey); XCTAssertTrue(reopened.songs[0].favorite)
        XCTAssertEqual(reopened.playlists[0].songIDs, [id]); XCTAssertEqual(try reopened.editableSource(id), source)
        reopened.updateSettings { $0.defaultSpeed = 4 }
        XCTAssertEqual(reopened.state.version, 2)
    }
    func testSpeedsColorsAndKeysPersistByStableIDAndResetToGlobal() throws {
        let root = try directory(), store = LibraryStore(directory: root)
        store.updateSettings { $0.defaultSpeed = 6; $0.chordColor = ChordColor.presets[2].1 }
        try store.accept(imported(source)); try store.accept(imported(source + "\nSuite"))
        let first = store.songs[0].id, second = store.songs[1].id
        XCTAssertNil(store.songs[0].preferences.speed)
        XCTAssertEqual(store.songs[0].preferences.effectiveSpeed(store.settings), 6)
        store.updateSong(first) { $0.preferences.speed = 4; $0.preferences.chordColor = ChordColor.presets[1].1; $0.preferences.displayKey = MusicalKey(tonic: "G", mode: .minor); $0.title = "Renommée" }
        store.updateSong(second) { $0.preferences.speed = 7 }
        let reopened = LibraryStore(directory: root)
        XCTAssertEqual(reopened.song(first)?.preferences.speed, 4); XCTAssertEqual(reopened.song(second)?.preferences.speed, 7)
        XCTAssertEqual(reopened.song(first)?.preferences.chordColor, ChordColor.presets[1].1)
        XCTAssertEqual(reopened.song(first)?.preferences.displayKey?.symbol, "Gm")
        reopened.updateSong(first) { $0.preferences.speed = nil; $0.preferences.chordColor = nil }
        reopened.updateSettings { $0.defaultSpeed = 8 }
        let reset = LibraryStore(directory: root)
        XCTAssertEqual(reset.song(first)?.preferences.effectiveSpeed(reset.settings), 8)
        XCTAssertNil(reset.song(first)?.preferences.chordColor)
        XCTAssertEqual(reset.song(second)?.preferences.speed, 7)
    }
    func testMetadataAndSyntaxPreserveUnknownDirectivesTabsAndAccents() {
        let edited = ChordSourceEditing.setDirective("title", value: "Nouvel été", in: source + "{title: Doublon}\n")
        XCTAssertEqual(ChordProParser.parse(edited).title, "Nouvel été")
        XCTAssertFalse(edited.contains("{t:")); XCTAssertEqual(edited.components(separatedBy: "{title:").count, 2)
        XCTAssertTrue(edited.contains("{future_songbook: garder EXACTEMENT}"))
        XCTAssertTrue(edited.contains("e|--0   2--|")); XCTAssertTrue(edited.contains("Été [Am7]à vélo"))
        let wrapped = ChordSourceEditing.wrapped("[C]Bonjour\n[Am]Été", section: "chorus")
        XCTAssertTrue(ChordProParser.parse(wrapped).lines.contains { $0.chorus && $0.segments.first?.chord == "Am" })
        XCTAssertEqual(ChordSourceEditing.transposeChords(in: "[C/G]Été [Am7]à vélo", by: 2), "[D/A]Été [Bm7]à vélo")
        XCTAssertEqual(ChordSourceEditing.transposeChords(in: "{unknown: [Am]}\n{sot}\n[Am]\n{eot}\n[Am]Été", by: 2), "{unknown: [Am]}\n{sot}\n[Am]\n{eot}\n[Bm]Été")
        XCTAssertTrue(ChordSourceEditing.validChord("F#m7/C#")); XCTAssertFalse(ChordSourceEditing.validChord("[C]"))
        XCTAssertEqual(ChordSyntax.tokens("[C]Été\n[Am\n{title: sans fin\n{sot}\n[tab]\n{eot}").filter(\.warning).count, 2)
    }
    func testSafeSaveReopenRestoreConflictAndCleanup() throws {
        let root = try directory(), store = LibraryStore(directory: root)
        try store.accept(imported(source, path: "dropbox/chanson.pro"))
        let original = store.songs[0], originalURL = try XCTUnwrap(store.url(for: original))
        store.updateSong(original.id) { $0.favorite = true; $0.preferences.speed = 4 }
        store.createPlaylist("Concert"); store.updatePlaylist(store.playlists[0].id) { $0.add(original.id) }
        let edited = source.replacingOccurrences(of: "Été", with: "Été modifié")
        try store.saveChordSource(edited, songID: original.id, expectedDigest: original.digest)
        XCTAssertEqual(store.songs.count, 1); XCTAssertEqual(store.songs[0].id, original.id)
        XCTAssertEqual(try String(contentsOf: originalURL, encoding: .utf8), source)
        XCTAssertEqual(try store.editableSource(original.id), edited)
        XCTAssertTrue(store.songs[0].favorite); XCTAssertEqual(store.songs[0].preferences.speed, 4)
        XCTAssertEqual(store.playlists[0].songIDs, [original.id])
        XCTAssertEqual(try store.accept(imported(source, path: "dropbox/chanson.pro")), "unchanged")
        XCTAssertThrowsError(try store.accept(imported(source + "Changé à distance", path: "dropbox/chanson.pro")))
        XCTAssertEqual(try store.editableSource(original.id), edited)
        XCTAssertThrowsError(try store.saveChordSource("[G]Une autre version", songID: original.id, expectedDigest: original.digest))
        store.cleanUnusedFiles()
        let reopened = LibraryStore(directory: root)
        XCTAssertEqual(try reopened.editableSource(original.id), edited)
        try reopened.restorePrevious(original.id)
        XCTAssertEqual(try reopened.editableSource(original.id), source)
        try reopened.restorePrevious(original.id)
        XCTAssertEqual(try reopened.editableSource(original.id), edited)
        let duplicateID = try reopened.duplicateChordSong(original.id)
        XCTAssertNotEqual(duplicateID, original.id); XCTAssertEqual(reopened.songs.count, 2)
        XCTAssertTrue(try reopened.editableSource(duplicateID).contains("{future_songbook: garder EXACTEMENT}"))
        XCTAssertTrue(try XCTUnwrap(reopened.song(duplicateID)).sources.isEmpty)
    }
    func testFailedCatalogWriteDoesNotCorruptScoreOrPublishReplacement() throws {
        let root = try directory(), store = LibraryStore(directory: root)
        try store.accept(imported(source)); let original = store.songs[0]
        let storage = try LibraryPersistence(directory: root)
        let before = try FileManager.default.contentsOfDirectory(atPath: storage.documentsURL.path)
        try FileManager.default.removeItem(at: storage.metadataURL)
        try FileManager.default.createDirectory(at: storage.metadataURL, withIntermediateDirectories: true)
        XCTAssertThrowsError(try store.saveChordSource(source + "Suite", songID: original.id, expectedDigest: original.digest))
        XCTAssertEqual(store.songs[0], original); XCTAssertEqual(try store.editableSource(original.id), source)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: storage.documentsURL.path), before)
    }
    func testEditingPreservesCustomTitleAndRebasesDisplayedKey() throws {
        let store = LibraryStore(directory: try directory())
        try store.accept(imported(source)); let original = store.songs[0]
        store.updateSong(original.id) {
            $0.title = "Titre de scène"; $0.customTitle = true
            $0.preferences.originalKey = MusicalKey(tonic: "C")
            $0.preferences.displayKey = MusicalKey(tonic: "G")
        }
        let changedKey = ChordSourceEditing.setDirective("key", value: "D", in: source)
        try store.saveChordSource(changedKey, songID: original.id, expectedDigest: original.digest)
        XCTAssertEqual(store.songs[0].title, "Titre de scène"); XCTAssertTrue(store.songs[0].customTitle)
        XCTAssertNil(store.songs[0].preferences.originalKey)
        XCTAssertEqual(store.songs[0].preferences.interval("D"), 5)
        let withoutKey = ChordSourceEditing.setDirective("key", value: "", in: changedKey)
        try store.saveChordSource(withoutKey, songID: original.id, expectedDigest: store.songs[0].digest)
        XCTAssertNil(store.songs[0].preferences.displayKey)
        XCTAssertEqual(store.songs[0].preferences.interval(""), 0)
    }
    func testChordColorAffectsOnlyChordsAndAdaptsToBothThemes() {
        let canvas = ChordCanvas(); canvas.song = ChordProParser.parse(source + "\n{c: Commentaire}")
        canvas.rebuild(width: 700)
        let lyricsBefore = canvas.items.first { $0.text == "Été " }!
        canvas.chordColor = ChordColor.presets[1].1; canvas.rebuild(width: 700)
        XCTAssertEqual(canvas.items.first { $0.text == "Été " }?.color, lyricsBefore.color)
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            XCTAssertEqual(canvas.items.first { $0.text == "Cmaj7" }?.color.resolvedColor(with: traits), ChordColor.presets[1].1.readableUIColor.resolvedColor(with: traits))
            for color in ChordColor.presets.map(\.1) {
                let adapted = color.readableUIColor.resolvedColor(with: traits)
                XCTAssertNotEqual(adapted, style == .dark ? UIColor.black : UIColor.white)
            }
        }
    }
    func testEditorInsertionSelectionUndoRedoAndHighlighting() async throws {
        let model = ChordEditorModel(text: "Été à vélo", song: nil)
        let host = UIHostingController(rootView: ChordTextEditor(model: model))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 810, height: 1080)); window.rootViewController = host; window.makeKeyAndVisible()
        addTeardownBlock { @MainActor in window.isHidden = true }
        host.view.layoutIfNeeded(); try await Task.sleep(for: .milliseconds(100))
        let view = try XCTUnwrap(model.textView)
        view.selectedRange = NSRange(location: 0, length: 3)
        model.insertChord("F#m7/C#")
        XCTAssertEqual(model.text, "[F#m7/C#]Été à vélo")
        XCTAssertEqual(view.selectedRange, NSRange(location: 9, length: 3))
        let selected = view.selectedRange
        ChordSyntax.highlight(view, fontSize: 32)
        XCTAssertEqual(view.selectedRange, selected)
        try await Task.sleep(for: .milliseconds(100))
        model.undo(); XCTAssertEqual(model.text, "Été à vélo")
        model.redo(); XCTAssertEqual(model.text, "[F#m7/C#]Été à vélo")
        view.selectedRange = NSRange(location: 0, length: (model.text as NSString).length)
        model.wrap("chorus")
        XCTAssertTrue(model.text.contains("{start_of_chorus}")); XCTAssertTrue(model.text.contains("[F#m7/C#]Été à vélo"))
    }
}
