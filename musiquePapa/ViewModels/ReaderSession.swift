import SwiftUI
import Combine

@MainActor
final class ReaderSession: ObservableObject {
    @Published var playing = false
    @Published var progress: Double = 0
    @Published var zoomLabel = ""
    @Published var speed: Double = 3
    @Published var transpose = 0
    @Published var error: String?
    @Published var metadata = ""
    @Published var ready = false
    @Published var preferences = ReaderPreferences()
    @Published var parsedKey = ""
    var originalKey: MusicalKey? { preferences.sourceKey(parsedKey) }
    weak var controller: ScoreReaderController?
    var onEnd: (() -> Void)?
    var onSave: ((ReaderPreferences) -> Void)?
    func playPause() { controller?.setPlaying(!playing) }
    func stop() { controller?.setPlaying(false); controller?.engine.beginning(); controller?.save() }
    func beginning() { controller?.engine.beginning(); controller?.save() }
    func zoom(_ factor: Double) { controller?.zoom(factor) }
    func fitWidth() { controller?.fitPDF(page: false) }
    func fitPage() { controller?.fitPDF(page: true) }
    func setSpeed(_ value: Double) { controller?.setSpeed(value) }
    func resetSpeed() { controller?.setSpeed(nil) }
    func setTranspose(_ value: Int) { transpose = value; controller?.setTranspose(value) }
    func setKey(_ key: MusicalKey, original: Bool) { controller?.setKey(key, original: original) }
    func resetKey() { controller?.resetKey() }
    func setChordColor(_ color: ChordColor?) { controller?.setChordColor(color) }
    func save() { controller?.save() }
}
