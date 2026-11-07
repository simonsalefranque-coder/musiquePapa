import XCTest
import UIKit
import PDFKit
@testable import musiquePapa

@MainActor
final class ReaderTests: XCTestCase {
    func testTimeBasedSpeedPauseResumeStopAndEnd() {
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 600, height: 500)); scroll.contentSize = CGSize(width: 600, height: 2000)
        let engine = AutoScrollEngine(); engine.scrollView = scroll; engine.speed = 3
        engine.play(); engine.tick(100); engine.tick(100.1)
        XCTAssertEqual(scroll.contentOffset.y, 2.5, accuracy: 0.001)
        engine.pause(); engine.tick(100.2); XCTAssertEqual(scroll.contentOffset.y, 2.5, accuracy: 0.001)
        engine.play(); engine.tick(101); engine.speed = 10; engine.tick(101.1)
        XCTAssertEqual(scroll.contentOffset.y, 9.9, accuracy: 0.26)
        engine.beginning(); XCTAssertEqual(scroll.contentOffset.y, 0)
        var ended = false; engine.onEnd = { ended = true }
        scroll.contentOffset.y = 1499; engine.tick(101.2)
        XCTAssertEqual(scroll.contentOffset.y, 1500); XCTAssertTrue(ended); XCTAssertFalse(engine.isPlaying)
    }
    func testActualScrollViewAccumulatesFractionalPixelsAtDifferentFrameRates() {
        func distance(hz: Int) -> CGFloat {
            let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 600, height: 500))
            scroll.contentSize = CGSize(width: 600, height: 10000)
            let engine = AutoScrollEngine(); engine.scrollView = scroll; engine.speed = 1; engine.play(); engine.tick(0)
            for frame in 1...(hz * 10) { engine.tick(Double(frame) / Double(hz)) }
            return scroll.contentOffset.y
        }
        XCTAssertEqual(distance(hz: 60), 110, accuracy: 0.5)
        XCTAssertEqual(distance(hz: 30), distance(hz: 60), accuracy: 0.5)
    }
    func testFrameRateIndependenceAndLongGapProtection() {
        var sixty = 0.0; var thirty = 0.0
        for _ in 0..<600 { sixty = ScrollMath.advance(offset: sixty, maximum: 9999, elapsed: 1.0 / 60, speed: 5) }
        for _ in 0..<300 { thirty = ScrollMath.advance(offset: thirty, maximum: 9999, elapsed: 1.0 / 30, speed: 5) }
        XCTAssertEqual(sixty, thirty, accuracy: 0.00001)
        XCTAssertEqual(ScrollMath.advance(offset: 0, maximum: 9999, elapsed: 60, speed: 5), 3.9, accuracy: 0.0001)
    }
    func testChordAlignmentBeforeAndAfterEnlargement() {
        let canvas = ChordCanvas()
        canvas.song = ChordProParser.parse("[Am]Bonjour [G]le monde\n{soc}\n[F#m]Refrain [Bb]ici\n{eoc}\n{sot}\ne|----0     2-----|\n{eot}")
        for size in [18.0, 32.0, 58.0] {
            canvas.fontSize = size; canvas.rebuild(width: 420)
            let chord = canvas.items.first { $0.text == "Am" }!
            let lyric = canvas.items.first { $0.text == "Bonjour " }!
            XCTAssertEqual(chord.origin.x, lyric.origin.x); XCTAssertLessThan(chord.origin.y, lyric.origin.y)
            let tab = canvas.items.first { $0.text.hasPrefix("e|") }!
            XCTAssertEqual(tab.text, "e|----0     2-----|")
            XCTAssertGreaterThan(canvas.measuredSize.height, 0)
        }
    }
    private func controller(format: ScoreFormat) async throws -> (ScoreReaderController, ReaderSession, UIWindow) {
        let url = try XCTUnwrap(Bundle.main.url(forResource: format == .pdf ? "Exercice_10_pages" : "Balade_du_dimanche", withExtension: format == .pdf ? "pdf" : "pro"))
        let song = Song(title: "Test", artist: "", format: format, localFilename: url.lastPathComponent, digest: "test")
        let session = ReaderSession(); let controller = ScoreReaderController(song: song, url: url, session: session, resume: true)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 810, height: 1080)); window.rootViewController = controller; window.isHidden = false
        controller.loadViewIfNeeded(); controller.view.frame = window.bounds; controller.view.setNeedsLayout(); controller.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 20_000_000)
        controller.engine.invalidate() // Drive the production engine deterministically in this test.
        addTeardownBlock { @MainActor in controller.shutdown(); window.isHidden = true }
        return (controller, session, window)
    }
    func testPDFTenPagesZoomAndContinuousScrollingToLastPage() async throws {
        let (controller, session, _) = try await controller(format: .pdf)
        let pdf = try XCTUnwrap(controller.pdfView); let scroll = try XCTUnwrap(controller.engine.scrollView)
        XCTAssertTrue(session.ready); XCTAssertEqual(pdf.document?.pageCount, 10)
        let scale = pdf.scaleFactor; controller.zoom(2); XCTAssertEqual(pdf.scaleFactor, scale * 2, accuracy: 0.01)
        pdf.go(to: try XCTUnwrap(pdf.document?.page(at: 4))); XCTAssertEqual(pdf.scaleFactor, scale * 2, accuracy: 0.01)
        controller.engine.beginning(); controller.engine.speed = 10; controller.setPlaying(true)
        controller.engine.tick(0)
        // The simulator may inherit portrait or landscape from a previous UI run.
        // Compute enough elapsed time from the actual zoomed document height.
        let steps = Int(ceil(controller.engine.maximum / ScrollMath.pointsPerSecond(speed: 10) / 0.1)) + 20
        for step in 1...steps { controller.engine.tick(Double(step) * 0.1) }
        XCTAssertEqual(scroll.contentOffset.y, controller.engine.maximum, accuracy: 0.2)
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(pdf.currentPage.map { pdf.document!.index(for: $0) }, 9)
        XCTAssertFalse(session.playing)
    }
    func testChordZoomPreservesMusicalAnchorAndScrolls() async throws {
        let (controller, session, _) = try await controller(format: .chordPro)
        let scroll = try XCTUnwrap(controller.engine.scrollView); let canvas = try XCTUnwrap(controller.canvas)
        scroll.contentOffset.y = 600
        let anchor = canvas.anchor(at: scroll.contentOffset.y)
        controller.zoom(1.6)
        XCTAssertEqual(canvas.fontSize, 38.4, accuracy: 0.01)
        XCTAssertEqual(canvas.anchor(at: scroll.contentOffset.y).line, anchor.line)
        controller.setPlaying(true); controller.engine.tick(1); let y = scroll.contentOffset.y; controller.engine.tick(1.1)
        XCTAssertGreaterThan(scroll.contentOffset.y, y)
        controller.zoom(1.1); XCTAssertTrue(session.playing)
        controller.setPlaying(false); let paused = scroll.contentOffset.y; controller.engine.tick(1.2)
        XCTAssertEqual(scroll.contentOffset.y, paused)
        controller.engine.beginning(); XCTAssertEqual(scroll.contentOffset.y, 0)
    }
    func testLivePreferencesPreserveZoomAnchorAndSourceForBothFormats() async throws {
        for format in [ScoreFormat.chordPro, .pdf] {
            let (controller, session, window) = try await controller(format: format)
            let originalBytes = try Data(contentsOf: controller.url)
            var saved: ReaderPreferences?
            session.onSave = { saved = $0 }
            var settings = AppSettings(); settings.defaultSpeed = 6
            controller.applySettings(settings)
            XCTAssertEqual(controller.engine.speed, 6)
            session.setSpeed(4); XCTAssertEqual(controller.engine.speed, 4)
            try await Task.sleep(for: .milliseconds(20)); XCTAssertEqual(saved?.speed, 4)
            settings.defaultSpeed = 8; controller.applySettings(settings)
            XCTAssertEqual(controller.engine.speed, 4)
            session.resetSpeed(); XCTAssertEqual(controller.engine.speed, 8)
            try await Task.sleep(for: .milliseconds(20)); XCTAssertNil(saved?.speed)
            controller.zoom(1.4); controller.engine.scrollView?.contentOffset.y = 200
            controller.setPlaying(true)
            if let canvas = controller.canvas, let scroll = controller.engine.scrollView {
                let anchor = canvas.anchor(at: scroll.contentOffset.y), size = canvas.fontSize
                session.setKey(MusicalKey(tonic: "C"), original: true)
                session.setKey(MusicalKey(tonic: "D", mode: .minor), original: false)
                XCTAssertEqual(canvas.transpose, 2)
                session.setChordColor(ChordColor.presets[1].1)
                XCTAssertEqual(canvas.fontSize, size); XCTAssertEqual(canvas.anchor(at: scroll.contentOffset.y).line, anchor.line)
                XCTAssertTrue(session.playing); XCTAssertEqual(canvas.chordColor, ChordColor.presets[1].1)
                controller.zoom(1.1); XCTAssertEqual(canvas.transpose, 2)
                session.resetKey(); XCTAssertEqual(canvas.transpose, 0)
                session.setChordColor(nil); XCTAssertEqual(canvas.chordColor, .blueDefault)
            }
            XCTAssertEqual(try Data(contentsOf: controller.url), originalBytes)
            controller.shutdown(); window.isHidden = true
        }
    }
}
