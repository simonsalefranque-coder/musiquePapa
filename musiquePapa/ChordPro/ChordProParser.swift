import Foundation

struct ChordSegment: Equatable, Sendable {
    var chord: String?
    var lyric: String
}
struct ChordLine: Equatable, Sendable {
    enum Kind: Equatable, Sendable { case lyrics, comment, tab, heading, blank }
    var kind: Kind
    var segments: [ChordSegment] = []
    var text = ""
    var chorus = false
}
struct ChordSong: Equatable, Sendable {
    var title = ""
    var subtitle = ""
    var artist = ""
    var key = ""
    var capo = ""
    var tempo = ""
    var lines: [ChordLine] = []
    var unknownDirectives: [String] = []
}
enum ChordProParser {
    static func decode(_ data: Data) throws -> String {
        let bytes = Array(data.prefix(4))
        let encoding: String.Encoding?
        if bytes.starts(with: [0xFF, 0xFE]) || bytes.starts(with: [0xFE, 0xFF]) { encoding = .utf16 }
        else { encoding = nil }
        let text = encoding.flatMap { String(data: data, encoding: $0) }
            ?? String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .windowsCP1252)
            ?? String(data: data, encoding: .isoLatin1)
        guard let text, !text.contains("\0") else { throw MusicError.message("Encodage illisible. Exportez ce fichier en UTF-8 depuis SongBook.") }
        return text.replacingOccurrences(of: "\u{FEFF}", with: "")
    }
    static func looksLikeChordPro(_ text: String) -> Bool {
        text.range(of: #"\{\s*(title|t|artist|subtitle|st|key|capo|tempo)\s*:|\[[A-G][^\]\r\n]*\]"#, options: [.regularExpression, .caseInsensitive]) != nil
    }
    static func parse(_ text: String) -> ChordSong {
        var song = ChordSong()
        var chorus = false
        var tab = false
        for raw in text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n") {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") { continue }
            if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
                let inner = String(trimmed.dropFirst().dropLast())
                let parts = inner.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                let name = (parts.first.map(String.init) ?? "").trimmingCharacters(in: .whitespaces).lowercased()
                let value = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : ""
                switch name {
                case "title", "t": song.title = value
                case "subtitle", "st": song.subtitle = value
                case "artist": song.artist = value
                case "key": song.key = value
                case "capo": song.capo = value
                case "tempo": song.tempo = value
                case "comment", "c", "comment_italic", "ci", "comment_box", "cb": song.lines.append(ChordLine(kind: .comment, text: value, chorus: chorus))
                case "start_of_chorus", "soc": chorus = true; song.lines.append(ChordLine(kind: .heading, text: value.isEmpty ? "Refrain" : value, chorus: true))
                case "end_of_chorus", "eoc": chorus = false
                case "start_of_verse", "sov": song.lines.append(ChordLine(kind: .heading, text: value.isEmpty ? "Couplet" : value))
                case "end_of_verse", "eov": break
                case "start_of_tab", "sot": tab = true
                case "end_of_tab", "eot": tab = false
                default: song.unknownDirectives.append(inner)
                }
            } else if tab { song.lines.append(ChordLine(kind: .tab, text: raw, chorus: chorus)) }
            else if trimmed.isEmpty { song.lines.append(ChordLine(kind: .blank)) }
            else { song.lines.append(ChordLine(kind: .lyrics, segments: segments(raw), chorus: chorus)) }
        }
        return song
    }
    static func segments(_ line: String) -> [ChordSegment] {
        var result: [ChordSegment] = []
        var text = ""
        var chord: String?
        var index = line.startIndex
        while index < line.endIndex {
            if line[index] == "[", let end = line[index...].firstIndex(of: "]") {
                if !text.isEmpty || chord != nil { result.append(ChordSegment(chord: chord, lyric: text)) }
                chord = String(line[line.index(after: index)..<end]); text = ""
                index = line.index(after: end)
            } else { text.append(line[index]); index = line.index(after: index) }
        }
        if !text.isEmpty || chord != nil { result.append(ChordSegment(chord: chord, lyric: text)) }
        return result
    }
}
