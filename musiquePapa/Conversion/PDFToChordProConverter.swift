import Foundation
import PDFKit
import Vision
import UIKit

struct PDFConversion: Sendable { var result: ConversionResult; var scannedPages: Int; var textPages: Int }

enum PDFToChordProConverter {
    /// Use a private PDFDocument on the worker, never the reader's live document.
    static func convert(data: Data, title: String, progress: @escaping @Sendable (Double) -> Void) throws -> PDFConversion {
        guard let document = PDFDocument(data: data), !document.isLocked, document.pageCount > 0 else { throw MusicError.message("PDF illisible ou protégé.") }
        guard document.allowsCopying else { throw MusicError.message("Ce PDF ne permet pas la copie de son contenu.") }
        guard document.pageCount <= 100 else { throw MusicError.message("La conversion est limitée à 100 pages. Importez un extrait du document.") }
        var sources: [String] = [], originals: [String] = [], warnings: [String] = []
        var scanned = 0, textPages = 0
        for pageIndex in 0..<document.pageCount {
            try Task.checkCancellation()
            guard let page = document.page(at: pageIndex) else { continue }
            let result: ConversionResult = try autoreleasepool {
                var characters = extract(page)
                if characters.filter({ !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }).count < 8 {
                    scanned += 1
                    characters = try recognize(page)
                    warnings.append("Page \(pageIndex + 1) : reconnaissance OCR, vérifier chaque accord et les paroles. Les portées ne sont pas interprétées.")
                } else { textPages += 1 }
                if page.rotation != 0 { warnings.append("Page \(pageIndex + 1) : page tournée, ordre des lignes à vérifier.") }
                return ChordTextConverter.convert(lines: group(characters), title: title)
            }
            sources.append(result.source.components(separatedBy: "\n").dropFirst(2).joined(separator: "\n"))
            originals.append(result.originalText)
            warnings += result.warnings.map { "Page \(pageIndex + 1) · \($0)" }
            progress(Double(pageIndex + 1) / Double(document.pageCount))
        }
        warnings.insert("Disposition PDF : vérifiez les colonnes, les sauts de ligne et l’association des accords aux paroles.", at: 0)
        return PDFConversion(result: ConversionResult(source: "{title: \(ChordTextConverter.clean(title))}\n\n" + sources.joined(separator: "\n\n{comment: Page suivante}\n\n"), warnings: warnings, originalText: originals.joined(separator: "\n\n")), scannedPages: scanned, textPages: textPages)
    }
    static func extract(_ page: PDFPage) -> [PositionedCharacter] {
        guard let text = page.string else { return [] }
        let bounds = page.bounds(for: .mediaBox), ns = text as NSString
        var result: [PositionedCharacter] = []
        // PDFPage.string includes synthesized newlines. Keep its UTF-16 ranges,
        // using PDFSelection bounds rather than PDFKit's different glyph indices.
        var index = 0
        while index < ns.length {
            let range = ns.rangeOfComposedCharacterSequence(at: index)
            let value = ns.substring(with: range)
            defer { index = NSMaxRange(range) }
            guard !value.contains("\n"), let selection = page.selection(for: range) else { continue }
            let rect = selection.bounds(for: page)
            if !rect.isEmpty, !rect.isNull {
                result.append(PositionedCharacter(text: value, rect: CGRect(x: rect.minX - bounds.minX, y: bounds.maxY - rect.maxY, width: rect.width, height: rect.height)))
            }
        }
        return result
    }
    static func recognize(_ page: PDFPage) throws -> [PositionedCharacter] {
        let bounds = page.bounds(for: .mediaBox)
        let scale = min(3, 2200 / max(bounds.width, bounds.height))
        let image = page.thumbnail(of: CGSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox)
        guard let cg = image.cgImage else { throw MusicError.message("Impossible de préparer la page pour l’OCR.") }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate; request.recognitionLanguages = ["fr-FR", "en-US"]
        request.usesLanguageCorrection = false // Do not turn chord symbols into guessed words.
        try VNImageRequestHandler(cgImage: cg).perform([request])
        var result: [PositionedCharacter] = []
        for observation in request.results ?? [] {
            guard let text = observation.topCandidates(1).first else { continue }
            for i in text.string.indices {
                let end = text.string.index(after: i)
                guard let box = try text.boundingBox(for: i..<end)?.boundingBox else { continue }
                result.append(PositionedCharacter(text: String(text.string[i]), rect: CGRect(x: box.minX * bounds.width, y: (1 - box.maxY) * bounds.height, width: box.width * bounds.width, height: box.height * bounds.height)))
            }
        }
        return result
    }
    static func group(_ characters: [PositionedCharacter]) -> [PositionedLine] {
        var rows: [[PositionedCharacter]] = []
        for char in characters.sorted(by: { $0.rect.midY < $1.rect.midY }) {
            if let index = rows.indices.last, let first = rows[index].first,
               abs(first.rect.midY - char.rect.midY) < max(2, max(first.rect.height, char.rect.height) * 0.6) { rows[index].append(char) }
            else { rows.append([char]) }
        }
        var lines: [PositionedLine] = []
        var previousBottom: CGFloat?
        for row in rows {
            let sorted = row.sorted { $0.rect.minX < $1.rect.minX }
            guard let first = sorted.first else { continue }
            if let previousBottom, first.rect.minY - previousBottom > first.rect.height * 1.5 { lines.append(PositionedLine(characters: [])) }
            var spaced: [PositionedCharacter] = []
            for char in sorted {
                if let previous = spaced.last, char.rect.minX - previous.rect.maxX > max(1, first.rect.height * 0.18), !previous.text.hasSuffix(" "), !char.text.hasPrefix(" ") {
                    spaced.append(PositionedCharacter(text: " ", rect: CGRect(x: previous.rect.maxX, y: first.rect.minY, width: char.rect.minX - previous.rect.maxX, height: first.rect.height)))
                }
                spaced.append(char)
            }
            lines.append(PositionedLine(characters: spaced)); previousBottom = sorted.map(\.rect.maxY).max()
        }
        return lines
    }
}
