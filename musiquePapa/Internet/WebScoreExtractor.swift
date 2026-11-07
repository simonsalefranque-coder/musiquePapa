import Foundation
import WebKit

struct WebImportDiagnostics: Codable, Equatable, Sendable {
    var detected: Int
    var uncertain: Int
    var strategy: String
}

struct WebScoreExtraction: Decodable {
    struct Bounds: Decodable { var x: Double; var y: Double; var width: Double; var height: Double }
    var status: String
    var message: String?
    var title: String?
    var artist: String?
    var body: String?
    var plainText: String?
    var detected: Int?
    var uncertain: Int?
    var warnings: [String]?
    var strategy: String?
    var rect: Bounds?
}

enum WebExtractionError: LocalizedError {
    case noRegion(String)
    var errorDescription: String? { switch self { case .noRegion(let message): return message } }
}

/// Operates on the currently displayed, authorized page. No independent requests or access bypass.
@MainActor enum WebScoreExtractor {
    static func extract(from view: WKWebView, allowWholePage: Bool = false) async throws -> WebScoreExtraction {
        guard let url = Bundle.main.url(forResource: "WebScoreExtractor", withExtension: "js") else {
            throw MusicError.message("Le composant d’extraction Internet est introuvable.")
        }
        let script = try String(contentsOf: url, encoding: .utf8)
            .replacingOccurrences(of: "__OPTIONS__", with: allowWholePage ? "{allowWholePage:true}" : "{allowWholePage:false}")
        let value = try await view.evaluateJavaScript(script)
        let data = try JSONSerialization.data(withJSONObject: value as Any)
        let extraction = try JSONDecoder().decode(WebScoreExtraction.self, from: data)
        if extraction.status == "no-region" { throw WebExtractionError.noRegion(extraction.message ?? "Sélectionnez la partition dans la page.") }
        guard extraction.status == "ok" else { throw MusicError.message(extraction.message ?? "Cette page ne peut pas être convertie.") }
        return extraction
    }

    static func chordCount(_ source: String) -> Int {
        ChordProParser.parse(source).lines.flatMap(\.segments).compactMap(\.chord).filter(ChordTextConverter.isChord).count
    }

    static func makeDraft(from view: WKWebView, title requestedTitle: String, allowWholePage: Bool = false) async throws -> ConversionDraft {
        let extraction = try await extract(from: view, allowWholePage: allowWholePage)
        try Task.checkCancellation()
        let explicitTitle = requestedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = !explicitTitle.isEmpty && explicitTitle != "Partition convertie" ? explicitTitle : (extraction.title?.isEmpty == false ? extraction.title! : "Partition convertie")
        let originalText = extraction.plainText ?? extraction.body ?? ""
        var result: ConversionResult
        if let plain = extraction.plainText {
            result = ChordTextConverter.convert(plain, title: title, recognizeMixedLayout: true)
        } else {
            result = ConversionResult(source: "{title: \(ChordTextConverter.clean(title))}\n\n" + (extraction.body ?? ""), warnings: [], originalText: originalText)
        }
        if let artist = extraction.artist, !artist.isEmpty, ChordProParser.parse(result.source).artist.isEmpty {
            result.source = "{artist: \(ChordTextConverter.clean(artist))}\n" + result.source
        }
        result.warnings += extraction.warnings ?? []
        let kept = chordCount(result.source)
        let detected = extraction.detected ?? 0
        let uncertain = (extraction.uncertain ?? 0) + result.uncertainChordCount
        result.webDiagnostics = WebImportDiagnostics(detected: detected, uncertain: uncertain, strategy: extraction.strategy ?? "Partition Internet")
        if kept == 0 { result.warnings.append("Aucun accord conservé. Si la page affiche des accords, corrigez le résultat ou sélectionnez une autre zone avant d’enregistrer.") }
        if kept < detected { result.warnings.append("\(detected - kept) accord(s) détecté(s) absent(s) du résultat : comparez avec l’original.") }
        result.warnings.append("Comparez les positions avec l’original avant d’enregistrer ; les mises en page Internet peuvent être ambiguës.")
        var original = Data(originalText.utf8), isPDF = false
        do {
            guard let r = extraction.rect, r.height <= 100_000, r.width <= 10_000 else {
                throw MusicError.message("Zone trop grande pour la copie visuelle.")
            }
            let config = WKPDFConfiguration()
            config.rect = CGRect(x: r.x, y: r.y, width: r.width, height: r.height)
            original = try await view.pdf(configuration: config)
            isPDF = true
        } catch {
            result.warnings.append("Copie visuelle indisponible : le panneau de gauche contient uniquement le texte extrait. Comparez aussi avec la page Internet.")
        }
        try Task.checkCancellation()
        return ConversionDraft(result: result, originalData: original, isPDF: isPDF, sourceURL: view.url?.absoluteString)
    }
}
