import Foundation
import CryptoKit
import PDFKit

struct ImportedScore: Sendable {
    let data: Data
    let title: String
    let artist: String
    let format: ScoreFormat
    let digest: String
    let fileExtension: String
    let source: String?
}
enum DocumentImportService {
    static let extensions: Set<String> = ["pdf", "pro", "chordpro", "chopro", "cho", "txt"]
    static func read(_ url: URL, source: String? = nil) throws -> ImportedScore {
        let ext = url.pathExtension.lowercased()
        guard extensions.contains(ext) else { throw MusicError.message("Format non pris en charge : \(url.lastPathComponent)") }
        var coordinationError: NSError?
        var result: Result<Data, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            result = Result {
                let values = try coordinatedURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                guard values.isRegularFile == true else { throw MusicError.message("Ce document n’est pas un fichier ordinaire.") }
                guard (values.fileSize ?? 0) <= 100_000_000 else { throw MusicError.message("Fichier trop volumineux (limite de 100 Mo).") }
                return try Data(contentsOf: coordinatedURL)
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw MusicError.message("Le fournisseur n’a pas donné accès au fichier.") }
        return try validate(result.get(), filename: url.lastPathComponent, source: source)
    }
    static func validate(_ data: Data, filename: String, source: String? = nil) throws -> ImportedScore {
        let ext = (filename as NSString).pathExtension.lowercased()
        var title = (filename as NSString).deletingPathExtension
        var artist = ""
        let format: ScoreFormat = ext == "pdf" ? .pdf : .chordPro
        if format == .pdf {
            guard let pdf = PDFDocument(data: data), !pdf.isLocked, pdf.pageCount > 0 else { throw MusicError.message("PDF corrompu, vide ou protégé par un mot de passe.") }
            if let metadata = pdf.documentAttributes {
                if let name = metadata[PDFDocumentAttribute.titleAttribute] as? String, !name.isEmpty { title = name }
                artist = metadata[PDFDocumentAttribute.authorAttribute] as? String ?? ""
            }
        } else {
            let text = try ChordProParser.decode(data)
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw MusicError.message("Le fichier est vide.") }
            if ext == "txt", !ChordProParser.looksLikeChordPro(text) { throw MusicError.message("Ce fichier TXT ne contient pas de notation ChordPro.") }
            let parsed = ChordProParser.parse(text)
            if !parsed.title.isEmpty { title = parsed.title }
            artist = parsed.artist
        }
        return ImportedScore(data: data, title: title, artist: artist, format: format,
                             digest: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
                             fileExtension: ext, source: source)
    }
    static func enumerate(_ folder: URL) throws -> [URL] {
        var failure: Error?
        var coordinationError: NSError?
        var files: [URL] = []
        NSFileCoordinator().coordinate(readingItemAt: folder, options: [], error: &coordinationError) { root in
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { _, error in failure = error; return false }) else {
                failure = MusicError.message("Impossible de parcourir ce dossier."); return
            }
            for case let url as URL in enumerator {
                if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true { enumerator.skipDescendants(); continue }
                if extensions.contains(url.pathExtension.lowercased()) { files.append(url) }
            }
        }
        if let error = coordinationError ?? failure as NSError? { throw error }
        return files.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }
}
