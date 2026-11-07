import SwiftUI
import Combine

struct ConversionOrigin: Codable, Equatable, Sendable {
    var filename: String
    var isPDF: Bool
    var sourceURL: String?
    var warnings: [String]
    var webDiagnostics: WebImportDiagnostics? = nil
}
struct ConversionDraft: Identifiable, Sendable {
    let id = UUID()
    var result: ConversionResult
    var originalData: Data
    var isPDF = false
    var sourceURL: String?
}
struct ConversionReviewView: View {
    let draft: ConversionDraft
    @StateObject private var model: ChordEditorModel
    init(draft: ConversionDraft) {
        self.draft = draft
        _model = StateObject(wrappedValue: ChordEditorModel(text: draft.result.source, song: nil))
    }
    var body: some View { ChordEditorView(model: model, conversion: draft) }
}
struct ConversionOriginalView: View {
    let draft: ConversionDraft
    @State private var size: Double = 18
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(draft.result.webDiagnostics != nil && !draft.isPDF ? "Texte extrait (sans mise en page)" : "Document original").font(.headline)
                Spacer()
                if !draft.isPDF {
                    Button("A−") { size = max(10, size - 2) }
                    Button("A+") { size = min(40, size + 2) }
                }
            }.padding(10).background(.bar)
            if draft.isPDF { PDFPreview(data: draft.originalData) }
            else {
                GeometryReader { geometry in
                    ScrollView([.horizontal, .vertical]) {
                        Text(draft.result.originalText).font(.system(size: size, design: .monospaced)).textSelection(.enabled).fixedSize(horizontal: true, vertical: true).padding()
                            .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
                    }
                }
            }
        }
    }
}

@MainActor final class PDFConversionModel: ObservableObject {
    @Published var progress = 0.0
    @Published var draft: ConversionDraft?
    @Published var error: String?
    private var worker: Task<PDFConversion, Error>?
    func run(url: URL, title: String) async {
        do {
            let data = try await Task.detached { try Data(contentsOf: url) }.value
            let report: @Sendable (Double) -> Void = { [self] value in Task { @MainActor in self.progress = value } }
            let task = Task.detached(priority: .userInitiated) {
                try PDFToChordProConverter.convert(data: data, title: title, progress: report)
            }
            worker = task
            let result = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
            try Task.checkCancellation()
            draft = ConversionDraft(result: result.result, originalData: data, isPDF: true)
        } catch is CancellationError {} catch { self.error = error.localizedDescription }
    }
    func cancel() { worker?.cancel() }
}
struct PDFConversionView: View {
    let url: URL, title: String
    @StateObject private var model = PDFConversionModel()
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Group {
            if let draft = model.draft { ConversionReviewView(draft: draft) }
            else {
                VStack(spacing: 24) {
                    if let error = model.error { Text(error) }
                    else {
                        Text("Conversion du PDF").font(.title)
                        ProgressView(value: model.progress).frame(maxWidth: 450)
                        Text("Extraction des paroles et accords ; OCR si nécessaire. Les portées musicales ne sont pas transcrites.").multilineTextAlignment(.center)
                    }
                    Button("Annuler") { model.cancel(); dismiss() }.buttonStyle(.bordered)
                }.padding(30)
            }
        }.task { await model.run(url: url, title: title) }.onDisappear { model.cancel() }
    }
}
