import SwiftUI
import Combine
import UniformTypeIdentifiers

struct EditorRequest: Identifiable { let id = UUID(); var songID: UUID? }
@MainActor final class EditorCoordinator: ObservableObject {
    @Published var request: EditorRequest?
    func open(_ id: UUID? = nil) { request = EditorRequest(songID: id) }
}

struct EditorLoader: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    let request: EditorRequest
    @State private var model: ChordEditorModel?
    @State private var error: String?
    @State private var conversion: ConversionDraft?
    var body: some View {
        Group {
            if let model { ChordEditorView(model: model, conversion: conversion) }
            else if let error {
                VStack(spacing: 24) {
                    ContentUnavailableView("Édition impossible", systemImage: "doc.badge.ellipsis", description: Text(error))
                    Button("Fermer") { dismiss() }.buttonStyle(.borderedProminent)
                }
            } else { ProgressView("Ouverture de l’éditeur…") }
        }.task {
            do {
                let source = try request.songID.map { try library.editableSource($0) } ?? ChordSourceEditing.template
                if let song = library.song(request.songID) { conversion = try library.conversionDraft(for: song) }
                model = ChordEditorModel(text: source, song: library.song(request.songID))
            } catch { self.error = error.localizedDescription }
        }
    }
}

struct ChordShareDocument: FileDocument {
    static let contentType = UTType(importedAs: "fr.musiquepapa.chordpro", conformingTo: .plainText)
    static var readableContentTypes: [UTType] { [contentType, .plainText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws { text = try ChordProParser.decode(configuration.file.regularFileContents ?? Data()) }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(text.utf8)) }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
