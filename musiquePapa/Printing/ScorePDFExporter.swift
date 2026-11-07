import UIKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct PDFShareDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

@MainActor enum ScorePDFExporter {
    static func filename(_ title: String) -> String {
        let value = title.components(separatedBy: CharacterSet(charactersIn: "/\\:\n\r")).joined(separator: "-")
        return String((value.isEmpty ? "Partition" : value).prefix(100)) + ".pdf"
    }
    static func temporaryURL(data: Data, title: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("PDF-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(filename(title))
        try data.write(to: url, options: .atomic)
        return url
    }
    static func render(song: Song, url: URL, preferences: ReaderPreferences, color: ChordColor, fontSize: Double, monochrome: Bool) throws -> Data {
        if song.format == .pdf {
            let data = try Data(contentsOf: url)
            guard let pdf = PDFDocument(data: data), !pdf.isLocked, pdf.pageCount > 0 else { throw MusicError.message("PDF illisible ou protégé.") }
            return data
        }
        let parsed = ChordProParser.parse(try ChordProParser.decode(Data(contentsOf: url)))
        let canvas = ChordCanvas()
        canvas.song = parsed; canvas.fontSize = min(32, max(10, fontSize))
        canvas.transpose = preferences.interval(parsed.key); canvas.displayKey = preferences.displayKey
        canvas.chordColor = preferences.chordColor ?? color
        canvas.overrideUserInterfaceStyle = .light
        let page = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
        let size = canvas.rebuild(width: page.width - 32)
        let scale = min(1, (page.width - 32) / size.width)
        let top: CGFloat = 108, bottom: CGFloat = 44
        let capacity = (page.height - top - bottom) / scale
        let starts = Array(Set(canvas.rowStarts + [size.height])).sorted()
        var slices: [(CGFloat, CGFloat)] = [], start: CGFloat = 0
        while start < size.height {
            let limit = start + capacity
            let end = starts.last(where: { $0 > start && $0 <= limit }) ?? min(size.height, limit)
            slices.append((start, end)); start = end
        }
        return UIGraphicsPDFRenderer(bounds: page).pdfData { renderer in
            for (index, slice) in slices.enumerated() {
                renderer.beginPage()
                (song.title as NSString).draw(in: CGRect(x: 44, y: 30, width: page.width - 88, height: 30), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 20), .foregroundColor: UIColor.black])
                let key = preferences.displayKey?.symbol ?? preferences.sourceKey(parsed.key).map { Transposer.transpose($0.symbol, by: preferences.transpose) } ?? ""
                let info = [song.artist, key.isEmpty ? "" : "Tonalité : \(key)", parsed.capo.isEmpty ? "" : "Capo : \(parsed.capo)"].filter { !$0.isEmpty }.joined(separator: " • ")
                (info as NSString).draw(in: CGRect(x: 44, y: 66, width: page.width - 88, height: 34), withAttributes: [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.darkGray])
                let ctx = renderer.cgContext
                ctx.saveGState(); ctx.translateBy(x: 16, y: top); ctx.scaleBy(x: scale, y: scale)
                ctx.clip(to: CGRect(x: 0, y: 0, width: size.width, height: slice.1 - slice.0))
                for item in canvas.items where item.origin.y >= slice.0 && item.origin.y < slice.1 {
                    let ink = monochrome ? UIColor.black : item.color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
                    (item.text as NSString).draw(at: CGPoint(x: item.origin.x, y: item.origin.y - slice.0), withAttributes: [.font: item.font, .foregroundColor: ink])
                }
                ctx.restoreGState()
                ("\(index + 1) / \(slices.count)" as NSString).draw(at: CGPoint(x: page.midX - 15, y: page.height - 28), withAttributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.gray])
            }
        }
    }
}

struct PDFPreview: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView(); view.displayMode = .singlePageContinuous; view.displayDirection = .vertical
        view.autoScales = true; view.minScaleFactor = 0.1; view.maxScaleFactor = 8
        view.document = PDFDocument(data: data); return view
    }
    func updateUIView(_ view: PDFView, context: Context) {}
}

struct PrintSheet: UIViewControllerRepresentable {
    let data: Data
    let title: String
    let onError: (String) -> Void
    func makeUIViewController(context: Context) -> PrintPresenter { PrintPresenter(data: data, title: title, onError: onError) }
    func updateUIViewController(_ controller: PrintPresenter, context: Context) {}
}
final class PrintPresenter: UIViewController {
    let data: Data, documentTitle: String, onError: (String) -> Void
    private var shown = false
    init(data: Data, title: String, onError: @escaping (String) -> Void) { self.data = data; documentTitle = title; self.onError = onError; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated); guard !shown else { return }; shown = true
        guard UIPrintInteractionController.canPrint(data) else { onError("Ce PDF ne peut pas être imprimé."); return }
        let printer = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil); info.jobName = documentTitle; info.outputType = .general
        printer.printInfo = info; printer.printingItem = data
        printer.present(from: CGRect(x: view.bounds.midX, y: 20, width: 1, height: 1), in: view, animated: true) { _, _, error in
            if let error { self.onError(error.localizedDescription) }
        }
    }
}

struct PDFExportView: View {
    @Environment(\.dismiss) private var dismiss
    let song: Song, url: URL, preferences: ReaderPreferences, color: ChordColor
    @State private var fontSize = 16.0
    @State private var monochrome = false
    @State private var data: Data?
    @State private var revision = UUID()
    @State private var exporting = false
    @State private var sharing: URL?
    @State private var printing = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            VStack {
                if song.format == .chordPro {
                    HStack {
                        Stepper("Texte : \(Int(fontSize)) pt", value: $fontSize, in: 10...32, step: 2)
                        Toggle("Noir et blanc", isOn: $monochrome)
                        Button("Actualiser l’aperçu", action: generate).buttonStyle(.bordered)
                    }.padding()
                }
                if let data { PDFPreview(data: data).id(revision) }
                else { ProgressView("Préparation du PDF…") }
                HStack(spacing: 20) {
                    Button("Imprimer", systemImage: "printer") { printing = true }.accessibilityIdentifier("printPDF")
                    Button("Enregistrer dans Fichiers", systemImage: "folder") { exporting = true }.accessibilityIdentifier("savePDF")
                    Button("Partager", systemImage: "square.and.arrow.up") {
                        do { if let data { sharing = try ScorePDFExporter.temporaryURL(data: data, title: song.title) } }
                        catch { self.error = error.localizedDescription }
                    }
                }.buttonStyle(.borderedProminent).padding().disabled(data == nil)
            }.navigationTitle("Imprimer et exporter en PDF").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Terminé") { dismiss() } } }
        }.task { generate() }
        .onChange(of: fontSize) { _, _ in generate() }.onChange(of: monochrome) { _, _ in generate() }
        .fileExporter(isPresented: $exporting, document: PDFShareDocument(data: data ?? Data()), contentType: .pdf, defaultFilename: ScorePDFExporter.filename(song.title)) { if case .failure(let e) = $0 { error = e.localizedDescription } }
        .sheet(isPresented: $printing) { VStack { Button("Fermer l’impression") { printing = false }.padding(); if let data { PrintSheet(data: data, title: song.title) { error = $0; printing = false } } } }
        .sheet(isPresented: Binding(get: { sharing != nil }, set: { if !$0 { sharing = nil } })) { if let sharing { ShareSheet(url: sharing) } }
        .alert("Export PDF", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Fermer", role: .cancel) {} } message: { Text(error ?? "") }
    }
    private func generate() {
        do { data = try ScorePDFExporter.render(song: song, url: url, preferences: preferences, color: color, fontSize: fontSize, monochrome: monochrome); revision = UUID() }
        catch { self.error = error.localizedDescription }
    }
}
