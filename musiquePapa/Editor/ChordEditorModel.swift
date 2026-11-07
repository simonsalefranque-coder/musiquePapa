import SwiftUI
import Combine

@MainActor
final class ChordEditorModel: ObservableObject {
    @Published private(set) var text: String
    @Published private(set) var preview: ChordSong
    @Published private(set) var warningCount = 0
    @Published var fontSize: Double = 20
    @Published var canUndo = false
    @Published var canRedo = false
    @Published var hasSelection = false
    let songID: UUID?
    let expectedDigest: String?
    private let initialText: String
    let initialKey: String
    weak var textView: UITextView?
    private var previewTask: Task<Void, Never>?
    var dirty: Bool { text != initialText }
    init(text: String, song: Song?) {
        let parsed = ChordProParser.parse(text)
        self.text = text; initialText = text; preview = parsed; initialKey = parsed.key
        songID = song?.id; expectedDigest = song?.digest
        warningCount = ChordSyntax.tokens(text).filter(\.warning).count
    }
    func changed(_ value: String) {
        text = value
        previewTask?.cancel()
        previewTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled, let self else { return }
            self.preview = ChordProParser.parse(value)
            self.warningCount = ChordSyntax.tokens(value).filter(\.warning).count
        }
        refreshUndo()
    }
    func refreshUndo() {
        let undo = textView?.undoManager?.canUndo == true, redo = textView?.undoManager?.canRedo == true
        let selection = (textView?.selectedRange.length ?? 0) > 0
        if canUndo != undo { canUndo = undo }; if canRedo != redo { canRedo = redo }
        if hasSelection != selection { hasSelection = selection }
    }
    func undo() { textView?.undoManager?.undo(); synchronize() }
    func redo() { textView?.undoManager?.redo(); synchronize() }
    func synchronize() {
        guard let textView else { return }
        changed(textView.text); ChordSyntax.highlight(textView, fontSize: fontSize)
    }
    func replace(_ range: NSRange, with value: String, selection: NSRange? = nil) {
        guard let view = textView, NSMaxRange(range) <= view.textStorage.length else { return }
        view.becomeFirstResponder()
        view.selectedRange = range
        view.insertText(value) // Native text input keeps keyboard undo/redo and accessibility.
        if let selection { view.selectedRange = selection }
        synchronize()
        view.scrollRangeToVisible(view.selectedRange)
    }
    func insertChord(_ chord: String) {
        guard ChordSourceEditing.validChord(chord), let range = textView?.selectedRange else { return }
        let value = "[\(chord)]"
        replace(NSRange(location: range.location, length: 0), with: value,
                selection: NSRange(location: range.location + (value as NSString).length, length: range.length))
    }
    func insertDirective(_ name: String) {
        guard let range = textView?.selectedRange else { return }
        let prefix = range.location == 0 || (text as NSString).substring(with: NSRange(location: range.location - 1, length: 1)) == "\n" ? "" : "\n"
        replace(NSRange(location: range.location, length: 0), with: prefix + "{\(name): }\n")
    }
    func wrap(_ section: String) {
        guard let range = textView?.selectedRange else { return }
        let selected = (text as NSString).substring(with: range)
        let prefix = range.location == 0 || (text as NSString).substring(with: NSRange(location: range.location - 1, length: 1)) == "\n" ? "" : "\n"
        replace(range, with: prefix + ChordSourceEditing.wrapped(selected, section: section, newline: text.contains("\r\n") ? "\r\n" : "\n"))
    }
    func setMetadata(_ values: [String: String]) {
        var updated = text
        let parsed = ChordProParser.parse(text)
        let current = ["title": parsed.title, "artist": parsed.artist, "key": parsed.key, "capo": parsed.capo, "tempo": parsed.tempo, "subtitle": parsed.subtitle]
        for (key, _) in ChordSourceEditing.metadata {
            if let value = values[key], value != current[key] { updated = ChordSourceEditing.setDirective(key, value: value, in: updated) }
        }
        guard updated != text else { return }
        replace(NSRange(location: 0, length: (text as NSString).length), with: updated, selection: NSRange(location: 0, length: 0))
    }
    func transposeSelection(by interval: Int) {
        guard let range = textView?.selectedRange, range.length > 0 else { return }
        let value = ChordSourceEditing.transposeChords(in: (text as NSString).substring(with: range), by: interval)
        replace(range, with: value, selection: NSRange(location: range.location, length: (value as NSString).length))
    }
    func find(_ query: String) {
        guard !query.isEmpty, let view = textView else { return }
        let ns = text as NSString, start = NSMaxRange(view.selectedRange)
        var range = ns.range(of: query, options: [.caseInsensitive], range: NSRange(location: start, length: ns.length - start))
        if range.location == NSNotFound { range = ns.range(of: query, options: [.caseInsensitive]) }
        if range.location != NSNotFound { view.becomeFirstResponder(); view.selectedRange = range; view.scrollRangeToVisible(range); refreshUndo() }
    }
    func replaceFound(_ query: String, with replacement: String) {
        guard !query.isEmpty, let range = textView?.selectedRange, range.length > 0,
              (text as NSString).substring(with: range).caseInsensitiveCompare(query) == .orderedSame else { find(query); return }
        replace(range, with: replacement); find(query)
    }
}
