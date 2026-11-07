import XCTest
import UIKit
import PDFKit
@testable import musiquePapa

@MainActor final class ConversionAndDiagramTests: XCTestCase {
    func testTextColumnsAccentsTabsSectionsAndNoInventedChords() {
        let result = ChordTextConverter.convert("    C        G7\nété soleil et vent\n\nRefrain\nAm       F#m7\nUne autre ligne\ne|--0--2--3--|\ntexte libre\n", title: "Test original")
        XCTAssertTrue(result.source.contains("été [C]soleil et[G7] vent"), result.source)
        XCTAssertTrue(result.source.contains("[Am]Une autre[F#m7] ligne"), result.source)
        XCTAssertTrue(result.source.contains("{start_of_tab}\ne|--0--2--3--|\n{end_of_tab}"))
        XCTAssertEqual(ChordProParser.parse(result.source).lines.flatMap(\.segments).compactMap(\.chord), ["C", "G7", "Am", "F#m7"])
        let tab = ChordTextConverter.convert("\tAm\n12345678été")
        XCTAssertTrue(tab.source.contains("12345678[Am]été"))
        let unsupported = ChordTextConverter.convert("notes de portée seules")
        XCTAssertFalse(unsupported.warnings.isEmpty); XCTAssertFalse(unsupported.source.contains("["))
        for name in ["C", "Am", "F#m7", "Bbmaj7", "D/F#", "Cdim", "Caug", "Esus4", "Dsus2", "G7(b9)"] { XCTAssertTrue(ChordTextConverter.isChord(name), name) }
    }
    func testChordProURLDownloadUsingOriginalLocalHTTPFixture() async throws {
        let ready = expectation(description: "Serveur HTTP local prêt")
        let original = "{title: Balade du réseau}\n[C]Bonjour [G7]le réseau\n"
        let server = try LocalTextServer(data: Data(original.utf8)) { ready.fulfill() }
        defer { server.stop() }
        await fulfillment(of: [ready], timeout: 5)
        let port = try XCTUnwrap(server.listener.port?.rawValue)
        let result = try await WebSongImportService.download(URL(string: "http://127.0.0.1:\(port)/Internet_original.chordpro")!)
        XCTAssertTrue(result.result.source.contains("{title: Balade du réseau}"))
        XCTAssertTrue(result.result.source.contains("[C]Bonjour [G7]le réseau"))
        XCTAssertEqual(result.originalData, Data(result.result.originalText.utf8))
        do { _ = try WebSongImportService.validatedURL("file:///etc/passwd"); XCTFail("Local URL accepted") } catch {}
        do { _ = try await WebSongImportService.download(URL(string: "http://127.0.0.1:\(port)/absent.chordpro")!); XCTFail("404 accepted") } catch {}
    }
    private func fixturePDF(scanned: Bool, pages: Int = 1) -> Data {
        let rect = CGRect(x: 0, y: 0, width: 595, height: 842)
        func paint() {
            UIColor.white.setFill(); UIRectFill(rect)
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedSystemFont(ofSize: 24, weight: .regular), .foregroundColor: UIColor.black]
            ("C            G7" as NSString).draw(at: CGPoint(x: 50, y: 90), withAttributes: attributes)
            ("Bonjour le soleil" as NSString).draw(at: CGPoint(x: 50, y: 125), withAttributes: attributes)
            ("Am           F" as NSString).draw(at: CGPoint(x: 50, y: 210), withAttributes: attributes)
            ("La guitare chante" as NSString).draw(at: CGPoint(x: 50, y: 245), withAttributes: attributes)
        }
        return UIGraphicsPDFRenderer(bounds: rect).pdfData { context in
            for _ in 0..<pages {
                context.beginPage()
                if scanned { let image = UIGraphicsImageRenderer(size: rect.size).image { _ in paint() }; image.draw(in: rect) }
                else { paint() }
            }
        }
    }
    func testTextPDFCoordinatesAndOCRScannedOriginal() async throws {
        let textData = fixturePDF(scanned: false, pages: 2)
        let text = try await Task.detached { try PDFToChordProConverter.convert(data: textData, title: "Original PDF") { _ in } }.value
        XCTAssertEqual(text.textPages, 2); XCTAssertEqual(text.scannedPages, 0)
        XCTAssertTrue(text.result.source.contains("[C]Bonjour"), text.result.source)
        XCTAssertTrue(text.result.source.contains("[G7]"), text.result.source)
        let imageData = fixturePDF(scanned: true)
        let scanned = try await Task.detached { try PDFToChordProConverter.convert(data: imageData, title: "Original OCR") { _ in } }.value
        XCTAssertEqual(scanned.scannedPages, 1); XCTAssertEqual(scanned.textPages, 0)
        XCTAssertTrue(scanned.result.originalText.localizedCaseInsensitiveContains("Bonjour"), scanned.result.originalText)
        XCTAssertTrue(scanned.result.warnings.contains { $0.contains("OCR") })
        XCTAssertTrue(scanned.result.source.contains("[C]"), scanned.result.source)
        let attachment = XCTAttachment(data: imageData, uniformTypeIdentifier: "com.adobe.pdf"); attachment.name = "Original-OCR"; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testConversionSaveOriginalRetentionPreferencesAndReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let library = LibraryStore(directory: directory)
        let original = fixturePDF(scanned: false)
        let pdf = try DocumentImportService.validate(original, filename: "Original.pdf")
        try library.accept(pdf)
        let originalSong = try XCTUnwrap(library.songs.first), originalURL = try XCTUnwrap(library.url(for: originalSong))
        library.updateSong(originalSong.id) { $0.favorite = true; $0.preferences.speed = 7; $0.preferences.pdfScale = 2 }
        library.createPlaylist("Concert"); let playlist = try XCTUnwrap(library.playlists.first)
        library.updatePlaylist(playlist.id) { $0.add(originalSong.id) }
        let draft = ConversionDraft(result: ChordTextConverter.convert("C     G\nBonjour le vent", title: "Conversion"), originalData: original, isPDF: true)
        let corrected = draft.result.source + "\n[Am]Parole corrigée"
        let id = try library.saveChordSource(corrected, songID: nil, expectedDigest: nil, conversion: draft)
        library.updatePlaylist(playlist.id) { $0.add(id) }
        library.cleanUnusedFiles()
        let reopened = LibraryStore(directory: directory), song = try XCTUnwrap(reopened.song(id))
        XCTAssertEqual(try reopened.editableSource(id), corrected)
        XCTAssertEqual(try reopened.conversionDraft(for: song)?.originalData, original)
        XCTAssertEqual(try Data(contentsOf: originalURL), original)
        XCTAssertTrue(try XCTUnwrap(reopened.song(originalSong.id)).favorite)
        XCTAssertEqual(reopened.song(originalSong.id)?.preferences.speed, 7)
        XCTAssertEqual(reopened.song(originalSong.id)?.preferences.pdfScale, 2)
        XCTAssertEqual(reopened.playlists.first?.songIDs, [originalSong.id, id])
        try reopened.saveChordSource(corrected + "\nSuite", songID: id, expectedDigest: song.digest)
        XCTAssertNotNil(reopened.song(id)?.conversionOrigin)
    }
    func testPDFExportMultipageVectorTextTranspositionAndOriginalCopy() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let library = LibraryStore(directory: directory)
        let content = "{title: Impression originale}\n{artist: MusiquePapa}\n{key: C}\n{capo: 2}\n" + (1...80).map { "[C]Ligne \($0) de musique [Am]pour la guitare" }.joined(separator: "\n")
        let id = try library.saveChordSource(content, songID: nil, expectedDigest: nil), song = try XCTUnwrap(library.song(id)), url = try XCTUnwrap(library.url(for: song))
        var preferences = song.preferences; preferences.displayKey = MusicalKey(tonic: "D")
        let data = try ScorePDFExporter.render(song: song, url: url, preferences: preferences, color: .blueDefault, fontSize: 18, monochrome: false)
        let pdf = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertGreaterThan(pdf.pageCount, 2)
        XCTAssertTrue(pdf.string?.contains("Bm") == true); XCTAssertTrue(pdf.string?.contains("Ligne 80") == true)
        XCTAssertTrue(UIPrintInteractionController.canPrint(data))
        let export = try ScorePDFExporter.temporaryURL(data: data, title: "Impression originale")
        XCTAssertEqual(export.lastPathComponent, "Impression originale.pdf"); XCTAssertEqual(try Data(contentsOf: export), data)
        let original = fixturePDF(scanned: false, pages: 3), pdfURL = directory.appendingPathComponent("original.pdf")
        try original.write(to: pdfURL)
        let pdfSong = Song(title: "PDF", artist: "", format: .pdf, localFilename: "original.pdf", digest: "test")
        let copy = try ScorePDFExporter.render(song: pdfSong, url: pdfURL, preferences: preferences, color: .blueDefault, fontSize: 16, monochrome: true)
        XCTAssertEqual(copy, original); XCTAssertEqual(PDFDocument(data: copy)?.pageCount, 3); XCTAssertTrue(UIPrintInteractionController.canPrint(copy))
        for index in [0, pdf.pageCount - 1] {
            let image = try XCTUnwrap(pdf.page(at: index)).thumbnail(of: CGSize(width: 900, height: 1273), for: .mediaBox)
            let attachment = XCTAttachment(image: image); attachment.name = "Export-A4-page-\(index + 1)"; attachment.lifetime = .keepAlways; add(attachment)
        }
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "com.adobe.pdf"); attachment.name = "Export-original-multipage"; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testAllCatalogShapesExactNotesBassAndBarres() throws {
        var count = 0
        for group in MusicalKey.chromatic {
            for root in group {
                for quality in GuitarChord.intervals.keys {
                    let symbol = root + quality, chord = try XCTUnwrap(GuitarChord.parse(symbol))
                    let positions = ChordFingeringLibrary.positions(for: symbol)
                    XCTAssertFalse(positions.isEmpty, symbol)
                    for position in positions {
                        count += 1
                        XCTAssertEqual(position.pitches, chord.pitches, symbol)
                        XCTAssertEqual(position.bass, chord.root, symbol)
                        XCTAssertEqual(position.frets.count, 6); XCTAssertEqual(position.fingers.count, 6)
                        for barre in position.barres {
                            for string in barre.from...barre.to { XCTAssertGreaterThanOrEqual(position.frets[string], barre.fret, symbol) }
                        }
                    }
                }
            }
        }
        XCTAssertGreaterThan(count, 200)
        for symbol in ["C", "Am", "G7", "F#m7", "D/F#", "C/G"] { XCTAssertFalse(ChordFingeringLibrary.positions(for: symbol).isEmpty, symbol) }
        XCTAssertTrue(ChordFingeringLibrary.positions(for: "F").contains { $0.barres.contains { $0.from == 0 && $0.to == 5 } })
        XCTAssertTrue(ChordFingeringLibrary.positions(for: "C7(b9)").isEmpty)
        XCTAssertTrue(ChordFingeringLibrary.positions(for: "C/F#").isEmpty)
    }
    func testChordHitTestingTracksZoomAndDisplayedTransposition() {
        let canvas = ChordCanvas(); canvas.song = ChordProParser.parse("{key: C}\n{capo: 2}\n[C]Bonjour [Am]les amis")
        for font in [16.0, 32, 60] {
            canvas.fontSize = font; canvas.transpose = 2; canvas.displayKey = MusicalKey(tonic: "D")
            canvas.rebuild(width: 500)
            let items = canvas.items.filter(\.isChord)
            XCTAssertEqual(items.map(\.text), ["D", "Bm"])
            for item in items { XCTAssertEqual(canvas.chord(at: CGPoint(x: item.bounds.midX, y: item.bounds.midY))?.text, item.text) }
            XCTAssertNil(canvas.chord(at: CGPoint(x: 0, y: canvas.measuredSize.height)))
            XCTAssertFalse(ChordFingeringLibrary.positions(for: items[0].text).isEmpty)
        }
    }
    func testDiagramPausesReaderWithoutChangingPositionSpeedOrZoom() async throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "Balade_du_dimanche", withExtension: "pro"))
        var song = Song(title: "Test", artist: "", format: .chordPro, localFilename: "demo", digest: "test")
        song.preferences.fontSize = 40; song.preferences.speed = 7
        let controller = ScoreReaderController(song: song, url: url, session: ReaderSession(), resume: false)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 810, height: 1080)); window.rootViewController = controller; window.isHidden = false
        controller.loadViewIfNeeded(); controller.view.frame = window.bounds; controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        controller.setPlaying(true); controller.engine.scrollView?.contentOffset.y = 150
        let scroll = try XCTUnwrap(controller.engine.scrollView), canvas = try XCTUnwrap(controller.canvas)
        let position = scroll.contentOffset, size = canvas.fontSize, speed = controller.engine.speed
        controller.showChord("D", rect: CGRect(x: 30, y: 180, width: 40, height: 25))
        XCTAssertFalse(controller.engine.isPlaying); XCTAssertEqual(scroll.contentOffset, position)
        XCTAssertEqual(canvas.fontSize, size); XCTAssertEqual(controller.engine.speed, speed)
        XCTAssertNotNil(controller.presentedViewController)
        controller.dismiss(animated: false); controller.shutdown(); window.isHidden = true
    }
}
