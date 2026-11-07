import Foundation
import CoreGraphics

struct ConversionResult: Sendable {
    var source: String
    var warnings: [String]
    var originalText: String
    var webDiagnostics: WebImportDiagnostics? = nil
    var uncertainChordCount: Int = 0
}
struct PositionedCharacter: Sendable {
    var text: String
    var rect: CGRect
}
struct PositionedLine: Sendable {
    var characters: [PositionedCharacter]
    var text: String { characters.map(\.text).joined() }
    var y: CGFloat { characters.first?.rect.minY ?? 0 }
}

/// Chord placement uses original character columns, or PDF/OCR coordinates. No harmonic inference.
enum ChordTextConverter {
    static func isChord(_ value: String) -> Bool {
        value.count <= 60 && value.range(of: #"^(?:[A-G][#b♯♭]?(?:(?:maj|Maj|min|Min|dim|aug|sus|add|omit|alt|dom|no|m|M|Δ|ø|°|\+|-)|\d|[#b♯♭]|[(),.])*(?:/(?:[A-G][#b♯♭]?|\d+))?|N\.?C\.?)$"#, options: .regularExpression) != nil
    }
    static func convert(_ text: String, title: String = "Partition convertie", recognizeMixedLayout: Bool = false) -> ConversionResult {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let bracketPattern = try! NSRegularExpression(pattern: #"\[([^\]\n]+)\]"#)
        let ns = normalized as NSString
        let hasInlineChords = bracketPattern.matches(in: normalized, range: NSRange(location: 0, length: ns.length)).contains { isChord(ns.substring(with: $0.range(at: 1))) }
        if !recognizeMixedLayout && (normalized.range(of: #"(?m)^\s*\{[a-zA-Z_]+(?:\s*:|\})"#, options: .regularExpression) != nil || hasInlineChords) {
            return ConversionResult(source: ChordProParser.parse(normalized).title.isEmpty ? "{title: \(clean(title))}\n" + normalized : normalized, warnings: ["Vérifiez les directives et les accords avant d’enregistrer."], originalText: text)
        }
        let lines = normalized.components(separatedBy: "\n").enumerated().map { lineIndex, line -> PositionedLine in
            var column = 0
            var chars: [PositionedCharacter] = []
            for char in line {
                let count = char == "\t" ? 8 - column % 8 : 1
                for _ in 0..<count { chars.append(PositionedCharacter(text: char == "\t" ? " " : String(char), rect: CGRect(x: column, y: lineIndex * 2, width: 1, height: 1))); column += 1 }
            }
            return PositionedLine(characters: chars)
        }
        var result = convert(lines: lines, title: title, preserveDirectives: recognizeMixedLayout)
        result.originalText = text
        return result
    }
    static func convert(lines: [PositionedLine], title: String, preserveDirectives: Bool = false) -> ConversionResult {
        var output = ["{title: \(clean(title))}", ""], warnings: [String] = [], index = 0, inTab = false
        if preserveDirectives && !ChordProParser.parse(lines.map(\.text).joined(separator: "\n")).title.isEmpty { output = [] }
        var explicitTab = false
        var section: String?
        var uncertainChordCount = 0
        while index < lines.count {
            let line = lines[index], text = line.text
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            if preserveDirectives, trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
                if inTab { output.append("{end_of_tab}"); inTab = false }
                let name = trimmed.dropFirst().dropLast().split(separator: ":", maxSplits: 1).first?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
                if ["start_of_tab", "sot"].contains(name) { explicitTab = true }
                if ["end_of_tab", "eot"].contains(name) { explicitTab = false }
                if ["start_of_chorus", "soc", "start_of_verse", "sov"].contains(name), let opened = section {
                    output.append("{end_of_\(opened)}"); section = nil
                }
                output.append(text); index += 1; continue
            }
            if explicitTab { output.append(text); index += 1; continue }
            let tab = trimmed.range(of: #"^[eEBGDA]?\|[-0-9hpx/\\~().| ]{3,}"#, options: .regularExpression) != nil
            if tab {
                if !inTab { output.append("{start_of_tab}"); inTab = true }
                output.append(text); index += 1; continue
            }
            if inTab { output.append("{end_of_tab}"); inTab = false }
            let chords = chordTokens(line)
            if !chords.isEmpty {
                var uncertainIndices: Set<Int> = chords.count == 1 ? [0] : []
                if index + 1 < lines.count, !lines[index + 1].text.trimmingCharacters(in: .whitespaces).isEmpty,
                   chordTokens(lines[index + 1]).isEmpty, !isSection(lines[index + 1].text),
                   !(preserveDirectives && lines[index + 1].text.trimmingCharacters(in: .whitespaces).hasPrefix("{")),
                   lines[index + 1].text.range(of: #"^[eEBGDA]?\|"#, options: .regularExpression) == nil {
                    let lyric = lines[index + 1]
                    var insertions: [Int: [String]] = [:]
                    for (offset, chord) in chords.enumerated() {
                        // Half-character boundary gives deterministic nearest original column.
                        let position = lyric.characters.firstIndex { $0.rect.midX >= chord.x } ?? lyric.characters.count
                        insertions[position, default: []].append(chord.name)
                        if position == lyric.characters.count { uncertainIndices.insert(offset); warnings.append("Ligne \(index + 1) : accord après la fin des paroles ; position à vérifier.") }
                    }
                    var merged = ""
                    for i in 0...lyric.characters.count {
                        merged += (insertions[i] ?? []).map { "[\($0)]" }.joined()
                        if i < lyric.characters.count { merged += lyric.characters[i].text }
                    }
                    output.append(merged); index += 2
                } else {
                    output.append(chords.map { "[\($0.name)]" }.joined(separator: " "))
                    warnings.append("Ligne \(index + 1) : accords sans paroles associées."); index += 1
                }
                if chords.count == 1 { warnings.append("Ligne \(index) : accord isolé ; vérifiez qu’il ne s’agit pas d’un mot ou d’une lettre.") }
                uncertainChordCount += uncertainIndices.count
                continue
            }
            if isSection(trimmed) {
                if let section { output.append("{end_of_\(section)}") }
                let lower = trimmed.lowercased()
                if lower.contains("refrain") || lower.contains("chorus") { section = "chorus" }
                else if lower.contains("couplet") || lower.contains("verse") { section = "verse" }
                else { section = nil }
                if let section { output.append("{start_of_\(section): \(clean(trimmed))}") }
                else { output.append("{comment: \(clean(trimmed))}") }
            }
            else { output.append(text) }
            index += 1
        }
        if inTab { output.append("{end_of_tab}") }
        if let section { output.append("{end_of_\(section)}") }
        if !output.contains(where: { $0.contains("[") }) { warnings.append("Aucun accord détecté. Une portée musicale ne peut pas être transcrite par reconnaissance de texte.") }
        return ConversionResult(source: output.joined(separator: "\n"), warnings: Array(Set(warnings)).sorted(), originalText: lines.map(\.text).joined(separator: "\n"), uncertainChordCount: uncertainChordCount)
    }
    private static func isSection(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespaces).range(of: #"(?i)^\[?(refrain|chorus|couplet|verse|intro|pont|bridge|outro)(\s*\d*)?\]?:?$"#, options: .regularExpression) != nil
    }
    private static func chordTokens(_ line: PositionedLine) -> [(name: String, x: CGFloat)] {
        var tokens: [(String, CGFloat)] = [], token = "", x: CGFloat = 0
        for character in line.characters + [PositionedCharacter(text: " ", rect: .zero)] {
            if character.text.allSatisfy({ $0.isWhitespace || $0 == "|" }) {
                if !token.isEmpty { tokens.append((token, x)); token = "" }
            } else { if token.isEmpty { x = character.rect.minX }; token += character.text }
        }
        guard !tokens.isEmpty, tokens.allSatisfy({ isChord($0.0) }) else { return [] }
        return tokens
    }
    static func clean(_ text: String) -> String { text.replacingOccurrences(of: "{", with: "(").replacingOccurrences(of: "}", with: ")").replacingOccurrences(of: "\n", with: " ") }
}
