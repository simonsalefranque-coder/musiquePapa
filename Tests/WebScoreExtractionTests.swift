import XCTest
import WebKit
import PDFKit
@testable import musiquePapa

/// Original synthetic lyrics only. Markup models public page layouts, not copyrighted songs.
@MainActor final class WebScoreExtractionTests: XCTestCase, WKNavigationDelegate {
    private var loaded: XCTestExpectation?
    private var window: UIWindow?
    private var web: WKWebView!
    private func load(_ body: String, css: String = "", host: String = "https://example.org", width: CGFloat = 810) async throws {
        web = WKWebView(frame: CGRect(x: 0, y: 0, width: width, height: 1080))
        web.navigationDelegate = self
        let controller = UIViewController(); controller.view = web
        window = UIWindow(frame: web.frame); window?.rootViewController = controller; window?.isHidden = false
        loaded = expectation(description: "HTML chargé")
        web.loadHTMLString("<!doctype html><meta name='viewport' content='width=device-width,initial-scale=1'><style>body{font:20px monospace}pre{font:20px monospace} \(css)</style>\(body)", baseURL: URL(string: host))
        await fulfillment(of: [loaded!], timeout: 15)
        web.layoutIfNeeded()
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loaded?.fulfill(); loaded = nil }
    override func tearDown() { window?.isHidden = true; window = nil; web = nil; super.tearDown() }
    private func draft() async throws -> ConversionDraft { try await WebScoreExtractor.makeDraft(from: web, title: "Partition convertie") }
    private func chords(_ source: String) -> [String] { ChordProParser.parse(source).lines.flatMap(\.segments).compactMap(\.chord) }

    func testPreformattedColumnsSectionsTabsAndNavigationExcluded() async throws {
        try await load("""
        <nav>MENU C D E F G A B</nav><h1>Le jardin bleu</h1><div class='artist'>Auteur de démonstration</div>
        <pre>Couplet 1
            C        G7
        été soleil et vent

        Refrain
        Am       F#m7
        Une autre ligne
        e|--0--2--3--|
        B|--1--3--1--|
        </pre><footer>FOOTER</footer>
        """)
        let value = try await draft(), source = value.result.source
        XCTAssertTrue(source.contains("été [C]soleil et[G7] vent"), source)
        XCTAssertTrue(source.contains("[Am]Une autre[F#m7] ligne"), source)
        XCTAssertTrue(source.contains("{start_of_chorus:")); XCTAssertTrue(source.contains("{start_of_verse:"))
        XCTAssertTrue(source.contains("{start_of_tab}\ne|--0--2--3--|"))
        XCTAssertEqual(chords(source), ["C", "G7", "Am", "F#m7"])
        XCTAssertEqual(value.result.webDiagnostics?.detected, 4)
        XCTAssertFalse(source.contains("MENU")); XCTAssertFalse(source.contains("FOOTER"))
        XCTAssertEqual(ChordProParser.parse(source).artist, "Auteur de démonstration")
        XCTAssertTrue(value.isPDF); XCTAssertNotNil(PDFDocument(data: value.originalData))
    }

    func testBACEmptyChordSpansPseudoContentDOMAnchorsAndInstrumental() async throws {
        try await load("""
        <nav>MENU</nav><div id='dTitreChanson'>La promenade des nuages</div>
        <div class='dTitreNomArtiste'><a>Auteur original</a><div hidden>AUTRES CHANSONS</div></div>
        <select><option>C D E F G A B</option></select><div class='ads'>PUBLICITE</div>
        <div id='divPartition'>
          <div class='pLI'><span>Intro : </span><span class='ALI'><span class='a' data-aff='Am7/4'></span></span> <span class='ALI'><span class='a' data-aff='D/F#'></span></span></div>
          <div>Couplet 1</div>
          <div class='pL'>Un <span class='sI'><span class='a' data-aff='Bbmaj7'></span></span>matin <span class='sI'><span class='a' data-aff='F#m7'></span></span>paisible</div>
          <div class='pLVV'></div><div>Refrain</div>
          <div class='pL'><span class='sI'><span class='a' data-aff='C'></span></span>Chantons <span class='sI'><span class='a' data-aff='G7'></span></span>ensemble</div>
          <div class='CALI2'>FORME xx2033</div><div><span>(x02033)</span><span>xx2033</span><span>(022033)</span></div><div hidden><span class='a' data-aff='Eb'></span>MASQUE</div>
        </div><aside>DIAGRAMMES</aside>
        """, css: ".a:before{content:attr(data-aff)} .sI{display:inline-block;position:relative;top:-16px;left:-10px} .pL{margin-top:30px}", host: "https://www.boiteachansons.net")
        let value = try await draft(), source = value.result.source
        XCTAssertEqual(chords(source), ["Am7/4", "D/F#", "Bbmaj7", "F#m7", "C", "G7"])
        XCTAssertTrue(source.contains("Un [Bbmaj7]matin [F#m7]paisible"), source)
        XCTAssertTrue(source.contains("Intro : [Am7/4] [D/F#]"))
        XCTAssertEqual(value.result.webDiagnostics?.detected, 6); XCTAssertEqual(value.result.webDiagnostics?.uncertain, 0)
        XCTAssertEqual(ChordProParser.parse(source).title, "La promenade des nuages")
        XCTAssertEqual(ChordProParser.parse(source).artist, "Auteur original")
        for noise in ["MENU", "PUBLICITE", "FORME", "MASQUE", "DIAGRAMMES", "AUTRES CHANSONS", "xx2033", "x02033", "022033"] { XCTAssertFalse(source.contains(noise), noise) }
        let pdf = try XCTUnwrap(PDFDocument(data: value.originalData))
        XCTAssertTrue(pdf.string?.contains("Am7/4") == true)
        XCTAssertFalse(pdf.string?.contains("PUBLICITE") == true)
        let attachment = XCTAttachment(data: value.originalData, uniformTypeIdentifier: "com.adobe.pdf"); attachment.name = "Source-HTML-originale"; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testInlineIndependentSpansAndCSSPositionedChordsAtTwoWidths() async throws {
        for width: CGFloat in [810, 1080] {
            try await load("""
            <h1>Le chemin clair</h1><div class='song-content'>
            <div><span class='chord'>Am</span>Bonjour <span class='chord'>C/G</span>la lune</div>
            <div class='positioned'><span class='chord first'>F#</span><span class='chord second'>Eb</span><span>Bonjour le vent</span></div>
            <div class='instrumental'><span class='chord'>Asus4</span> <span class='chord'>Dsus2</span></div>
            <div>Une nouvelle aurore</div>
            <div class='ads'>PUBLICITE</div><div class='tonality'>C D E F G A B</div>
            </div>
            """, css: ".positioned{position:relative;padding-top:30px;margin-top:15px}.positioned .chord{position:absolute;top:0}.first{left:0}.second{left:8ch}", width: width)
            let value = try await draft(), source = value.result.source
            XCTAssertTrue(source.contains("[Am]Bonjour [C/G]la lune"), source)
            XCTAssertTrue(source.contains("[F#]Bonjour [Eb]le vent"), source)
            XCTAssertTrue(source.contains("[Asus4] [Dsus2]\nUne nouvelle aurore"), source)
            XCTAssertEqual(chords(source), ["Am", "C/G", "F#", "Eb", "Asus4", "Dsus2"])
            XCTAssertFalse(source.contains("PUBLICITE")); XCTAssertFalse(source.contains("C D E F G A B"))
            XCTAssertEqual(value.result.webDiagnostics?.detected, 6)
        }
    }

    func testSeparatePlainChordRowsAndInlineChordPro() async throws {
        try await load("<article><div>C&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;G7</div><div>Bonjour la nuit</div><p>[Am7/4]Un chemin [Bb]doux</p></article>")
        let value = try await draft()
        XCTAssertTrue(value.result.source.contains("[C]Bonjour [G7]la nuit"), value.result.source)
        XCTAssertEqual(chords(value.result.source), ["C", "G7", "Am7/4", "Bb"])
        XCTAssertEqual(value.result.webDiagnostics?.detected, 4)
    }

    func testManualSelectionAndExplicitRecoveryOnly() async throws {
        try await load("<nav>MENU</nav><p id='text'>Avant petit jardin après</p><footer>FIN</footer>")
        do { _ = try await WebScoreExtractor.extract(from: web); XCTFail("Whole body must not be silently converted") } catch is WebExtractionError {} catch { throw error }
        _ = try await web.evaluateJavaScript("const n=document.getElementById('text').firstChild; const r=document.createRange();r.setStart(n,6);r.setEnd(n,18);getSelection().removeAllRanges();getSelection().addRange(r)")
        let selected = try await draft()
        XCTAssertTrue(selected.result.source.contains("petit jardin"), selected.result.source)
        XCTAssertFalse(selected.result.source.contains("Avant")); XCTAssertFalse(selected.result.source.contains("après"))
        XCTAssertEqual(selected.result.webDiagnostics?.detected, 0)
        XCTAssertTrue(selected.result.warnings.contains { $0.contains("Aucun accord") })
        _ = try await web.evaluateJavaScript("getSelection().removeAllRanges()")
        let recovered = try await WebScoreExtractor.makeDraft(from: web, title: "Correction", allowWholePage: true)
        XCTAssertTrue(recovered.result.source.contains("Avant petit jardin après"))
        XCTAssertFalse(recovered.result.source.contains("MENU")); XCTAssertFalse(recovered.result.source.contains("FIN"))
        XCTAssertTrue(recovered.result.warnings.contains { $0.contains("Zone musicale non identifiée") })
    }

    func testUnknownChordHintsAreNeverReportedAsSuccessful() async throws {
        try await load("<div class='song-content'><span class='chord'>H inconnu</span><div>Le jour revient</div></div>")
        // Explicit recovery retains the uncertain text, with a real zero-chord diagnostic.
        let value = try await WebScoreExtractor.makeDraft(from: web, title: "À vérifier", allowWholePage: true)
        XCTAssertEqual(value.result.webDiagnostics?.detected, 0)
        XCTAssertEqual(value.result.webDiagnostics?.uncertain, 1)
        XCTAssertTrue(value.result.source.contains("H inconnu"))
        XCTAssertTrue(value.result.warnings.contains { $0.contains("sans symbole lisible") })
    }

    func testBACFragmentedTabRowsAndSecondSong() async throws {
        let fragment = { (note: String) in "<div class='tabT'>" + ["E","B","G","D","A","E"].map { "<div class='tabR'><span class='tabC tabB'>\($0)</span><span class='tabC tabE'></span><span class='tabC'>\(note)</span></div>" }.joined() + "</div>" }
        try await load("<div id='dTitreChanson'>Rivage original</div><div id='divPartition'>" + fragment("0") + fragment("2h3") + "<div><span class='a' data-aff='Em7'></span>Un rivage</div></div>", css: ".a:before{content:attr(data-aff)}.tabT{display:inline-block}.tabR{display:block;height:24px}.tabC{display:inline-block;min-width:12px}", host: "https://www.boiteachansons.net")
        let value = try await draft(), parsed = ChordProParser.parse(value.result.source)
        XCTAssertEqual(parsed.title, "Rivage original"); XCTAssertEqual(chords(value.result.source), ["Em7"])
        let rows = parsed.lines.filter { $0.kind == .tab }
        XCTAssertEqual(rows.count, 6); XCTAssertTrue(rows.first?.text.contains("2h3") == true)
        XCTAssertTrue(rows.first?.text.contains("-0") == true)
    }

    func testProportionalFontWrappingAndHiddenChords() async throws {
        for width: CGFloat in [290, 600] {
            for font in [18, 30] {
                try await load("""
                <h1>Les mots du soir</h1><div class='song-content'>
                <div><span class='chord'>Cmaj7</span>Un chemin lumineux invite <span class='chord'>G7(b9)</span>les amis à chanter ensemble sous les étoiles.</div>
                <span class='chord' style='display:none'>F#</span>
                <div>Refrain</div><div><span class='chord'>Bb</span>Été tranquille <span class='chord'>D/F#</span>au jardin</div>
                </div>
                """, css: "body{font: \(font)px Georgia}.song-content{width:240px;line-height:1.6}.chord{color:blue}", width: width)
                let value = try await draft()
                XCTAssertEqual(chords(value.result.source), ["Cmaj7", "G7(b9)", "Bb", "D/F#"])
                XCTAssertEqual(value.result.webDiagnostics?.detected, 4)
                XCTAssertTrue(value.result.source.contains("{start_of_chorus:"))
                XCTAssertFalse(value.result.source.contains("[F#]"))
                XCTAssertTrue(value.result.source.contains("[Cmaj7]Un"), value.result.source)
            }
        }
    }

    func testPreformattedDiagnosticCountsAmbiguousChordsNotWarnings() async throws {
        try await load("<pre>          C       G7\nx\n\nAm\ny</pre>")
        let value = try await draft()
        XCTAssertEqual(value.result.webDiagnostics?.detected, 3)
        XCTAssertEqual(value.result.webDiagnostics?.uncertain, 3)
        XCTAssertEqual(chords(value.result.source), ["C", "G7", "Am"])
        XCTAssertFalse(ChordTextConverter.isChord("Bonjour"))
        for symbol in ["Am7/4", "C7alt", "CmMaj7", "G7(b9,#11)", "C6/9"] { XCTAssertTrue(ChordTextConverter.isChord(symbol), symbol) }
    }

    func testMixedPreformattedColumnsInlineChordsAndExplicitTabDirectives() async throws {
        try await load("""
        <pre>{title: Les deux chemins}
        C       G7
        Bonjour le ciel
        [Am7/4]La lumière [Bb]revient
        {start_of_tab}
        C      G
        e|--0--2--|
        {end_of_tab}
        </pre>
        """)
        let value = try await draft()
        XCTAssertEqual(chords(value.result.source), ["C", "G7", "Am7/4", "Bb"])
        XCTAssertEqual(value.result.webDiagnostics?.detected, 4)
        XCTAssertEqual(ChordProParser.parse(value.result.source).title, "Les deux chemins")
        XCTAssertEqual(value.result.source.components(separatedBy: "{title:").count, 2)
        XCTAssertTrue(value.result.source.contains("{start_of_tab}\nC      G\ne|--0--2--|\n{end_of_tab}"))
    }

    func testSaveReopenPreviewTransposeAndInteractiveChordTargets() async throws {
        try await load("<h1>Balade de test</h1><pre>[C]Bonjour [Am7/4]le ciel [D/F#]bleu</pre>")
        let value = try await draft()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = LibraryStore(directory: directory)
        let id = try library.saveChordSource(value.result.source, songID: nil, expectedDigest: nil, conversion: value)
        let reopened = LibraryStore(directory: directory), song = try XCTUnwrap(reopened.song(id))
        let restored = try XCTUnwrap(reopened.conversionDraft(for: song))
        XCTAssertEqual(restored.result.webDiagnostics, value.result.webDiagnostics)
        XCTAssertEqual(restored.originalData, value.originalData)
        XCTAssertEqual(restored.result.source, value.result.source)
        let canvas = ChordCanvas(); canvas.song = ChordProParser.parse(restored.result.source); canvas.transpose = 2
        canvas.fontSize = 30; canvas.rebuild(width: 600)
        let items = canvas.items.filter(\.isChord)
        XCTAssertEqual(items.map(\.text), ["D", "Bm7/4", "E/G#"])
        for item in items { XCTAssertEqual(canvas.chord(at: CGPoint(x: item.bounds.midX, y: item.bounds.midY))?.text, item.text) }
        XCTAssertFalse(ChordFingeringLibrary.positions(for: "D").isEmpty)
        XCTAssertTrue(ChordFingeringLibrary.positions(for: "Bm7/4").isEmpty) // Honest existing unsupported-diagram fallback.
        let image = UIGraphicsImageRenderer(size: canvas.measuredSize).image { context in canvas.layer.render(in: context.cgContext) }
        let attachment = XCTAttachment(image: image); attachment.name = "Apercu-accords-importes"; attachment.lifetime = .keepAlways; add(attachment)
    }
}
