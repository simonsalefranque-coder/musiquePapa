#if LIVE_WEB_VALIDATION
import XCTest
import WebKit
@testable import musiquePapa

/// Opt-in integration check: OTHER_SWIFT_FLAGS='$(inherited) -DLIVE_WEB_VALIDATION'.
/// Never records lyrics or source PDF. Normal public-page loading, no access bypass.
@MainActor final class WebScoreLiveValidationTests: XCTestCase, WKNavigationDelegate {
    func testRealBACPageWithProductionExtractor() async throws {
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 810, height: 1080))
        let window = UIWindow(frame: web.frame), controller = UIViewController()
        controller.view = web; window.rootViewController = controller; window.isHidden = false
        defer { web.stopLoading(); window.isHidden = true }
        web.load(URLRequest(url: URL(string: "https://www.boiteachansons.net/en/partitions/pink-floyd/wish-you-were-here")!))
        var count = 0
        for _ in 0..<80 {
            try await Task.sleep(for: .milliseconds(500))
            count = (try? await web.evaluateJavaScript("document.querySelectorAll('#divPartition .a').length")) as? Int ?? 0
            if count > 0 { break }
        }
        XCTAssertGreaterThan(count, 0, "Page réelle indisponible ; aucune validation réelle possible.")
        guard count > 0 else { return }
        let extraction = try await WebScoreExtractor.extract(from: web)
        XCTAssertEqual(extraction.status, "ok")
        XCTAssertEqual(extraction.detected, count)
        XCTAssertEqual(extraction.title?.lowercased(), "wish you were here")
        XCTAssertEqual(extraction.artist?.lowercased(), "pink floyd")
        let result = try await WebScoreExtractor.makeDraft(from: web, title: "Partition convertie")
        let kept = WebScoreExtractor.chordCount(result.result.source)
        XCTAssertEqual(kept, count)
        XCTAssertTrue(result.isPDF)
        // Compare source DOM and output symbols without hardcoding the song's harmonic sequence.
        let symbols = try await web.evaluateJavaScript("Array.from(document.querySelectorAll('#divPartition .a')).map(e=>JSON.parse(getComputedStyle(e,'::before').content))") as? [String]
        let actual = ChordProParser.parse(result.result.source).lines.flatMap(\.segments).compactMap(\.chord)
        XCTAssertEqual(actual, symbols)
        XCTAssertFalse(result.result.source.contains("xx2033"))
        XCTAssertFalse(result.result.source.contains("x02033"))
        // Compare every lyric line against its actual DOM chord anchors without logging lyrics.
        let anchoredLines = try await web.evaluateJavaScript("""
        (() => {
            function line(n) {
                if(n.nodeType===3) return n.textContent;
                if(n.nodeType!==1) return '';
                if(n.matches('.a')) return '['+JSON.parse(getComputedStyle(n,'::before').content)+']';
                return Array.from(n.childNodes).map(line).join('');
            }
            return Array.from(document.querySelectorAll('#divPartition .pL')).map(n=>line(n).replace(/\\u00a0/g,' ').trim());
        })()
        """) as? [String] ?? []
        XCTAssertFalse(anchoredLines.isEmpty)
        for (index, line) in anchoredLines.enumerated() { XCTAssertTrue(result.result.source.contains(line), "Position des accords de la ligne DOM \(index + 1)") }
        XCTAssertFalse(result.result.source.contains("Key:"))
        XCTAssertFalse(result.result.source.contains("Other suggested artists"))
        let metadata = "Page réelle : \(count) accords DOM, \(kept) conservés, \(extraction.uncertain ?? -1) à vérifier ; titre/artiste vérifiés ; original PDF : \(result.isPDF)."
        let attachment = XCTAttachment(string: metadata); attachment.name = "Validation-reelle-sans-paroles"; attachment.lifetime = .keepAlways; add(attachment)
        print(metadata)
    }
}
#endif
