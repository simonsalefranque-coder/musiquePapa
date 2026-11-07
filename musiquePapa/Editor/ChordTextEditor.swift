import SwiftUI

struct ChordTextEditor: UIViewRepresentable {
    @ObservedObject var model: ChordEditorModel
    func makeCoordinator() -> Coordinator { Coordinator(model) }
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator; view.text = model.text
        view.backgroundColor = .systemBackground; view.alwaysBounceVertical = true
        view.textContainerInset = UIEdgeInsets(top: 16, left: 14, bottom: 80, right: 14)
        view.autocorrectionType = .no; view.autocapitalizationType = .none
        view.smartQuotesType = .no; view.smartDashesType = .no; view.smartInsertDeleteType = .no
        view.accessibilityIdentifier = "chordSourceEditor"
        model.textView = view
        view.addGestureRecognizer(UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pinch(_:))))
        ChordSyntax.highlight(view, fontSize: model.fontSize)
        context.coordinator.lastFont = model.fontSize
        return view
    }
    func updateUIView(_ view: UITextView, context: Context) {
        if context.coordinator.lastFont != model.fontSize {
            ChordSyntax.highlight(view, fontSize: model.fontSize); context.coordinator.lastFont = model.fontSize
        }
    }
    @MainActor final class Coordinator: NSObject, UITextViewDelegate {
        let model: ChordEditorModel
        var lastFont = 20.0
        var pinchStart = 20.0
        init(_ model: ChordEditorModel) { self.model = model }
        func textViewDidChange(_ textView: UITextView) {
            model.changed(textView.text)
            ChordSyntax.highlight(textView, fontSize: model.fontSize)
            DispatchQueue.main.async { [weak self] in self?.model.refreshUndo() }
        }
        func textViewDidChangeSelection(_ textView: UITextView) {
            // UIKit can send this while SwiftUI is updating the font/layout.
            DispatchQueue.main.async { [weak self] in self?.model.refreshUndo() }
        }
        @objc func pinch(_ recognizer: UIPinchGestureRecognizer) {
            if recognizer.state == .began { pinchStart = model.fontSize }
            if recognizer.state == .changed { model.fontSize = min(40, max(12, pinchStart * recognizer.scale)) }
        }
    }
}
