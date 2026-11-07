import Foundation

/// All edits operate on the original source, never on a parser re-serialization.
/// Unknown directives, whitespace, tabs and accented characters survive round trips.
enum ChordSourceEditing {
    static let template = "{title: Nouvelle chanson}\n{artist: }\n{key: C}\n{capo: 0}\n\n{start_of_verse}\n[C]Vos paroles ici\n{end_of_verse}\n\n{start_of_chorus}\n[Am]Votre refrain\n{end_of_chorus}\n"
    static let metadata: [(String, String)] = [("title", "Titre"), ("artist", "Artiste"), ("key", "Tonalité d’origine"), ("capo", "Capo"), ("tempo", "Tempo"), ("subtitle", "Sous-titre")]
    static func setDirective(_ name: String, value: String, in source: String) -> String {
        let aliases = name == "title" ? "title|t" : name == "subtitle" ? "subtitle|st" : NSRegularExpression.escapedPattern(for: name)
        let pattern = "(?im)^[\\t ]*\\{[\\t ]*(?:\(aliases))[\\t ]*:[^}\\r\\n]*\\}[\\t ]*(?:\\r?\\n|$)"
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return source }
        let range = NSRange(location: 0, length: (source as NSString).length)
        let matches = expression.matches(in: source, range: range)
        let clean = value.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "{", with: "(").replacingOccurrences(of: "}", with: ")")
        let newline = source.contains("\r\n") ? "\r\n" : "\n"
        let directive = "{\(name): \(clean)}"
        guard let first = matches.first else { return directive + newline + source }
        let result = NSMutableString(string: source)
        for match in matches.reversed() {
            let old = (source as NSString).substring(with: match.range)
            let replacement = match.range == first.range ? directive + (old.hasSuffix("\n") ? newline : "") : ""
            result.replaceCharacters(in: match.range, with: replacement)
        }
        return result as String
    }
    static func wrapped(_ text: String, section: String, newline: String = "\n") -> String {
        "{start_of_\(section)}" + newline + text + (text.hasSuffix("\n") || text.isEmpty ? "" : newline) + "{end_of_\(section)}" + newline
    }
    static func validChord(_ value: String) -> Bool {
        value.range(of: #"^(?:[A-G][#b♯♭]?[a-zA-Z0-9+()°øΔ#b♭♯.,-]*(?:/(?:[A-G][#b♯♭]?|[0-9]+))?|N\.?C\.?)$"#, options: .regularExpression) != nil
    }
    static func transposeChords(in source: String, by interval: Int) -> String {
        let result = NSMutableString(string: source)
        for token in ChordSyntax.tokens(source).reversed() where token.isChord && !token.warning {
            let range = NSRange(location: token.range.location + 1, length: token.range.length - 2)
            let chord = (source as NSString).substring(with: range)
            result.replaceCharacters(in: range, with: Transposer.transpose(chord, by: interval))
        }
        return result as String
    }
}
