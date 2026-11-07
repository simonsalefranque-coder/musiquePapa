import Foundation

enum Transposer {
    static func transpose(_ chord: String, by semitones: Int, preferFlats: Bool = false) -> String {
        guard semitones % 12 != 0 else { return chord }
        let parts = chord.split(separator: "/", omittingEmptySubsequences: false)
        return parts.map { transposeRoot(String($0), by: semitones, flats: preferFlats || chord.contains("b") || chord.contains("♭")) }.joined(separator: "/")
    }
    static func transpose(_ chord: String, by semitones: Int, in key: MusicalKey) -> String {
        chord.split(separator: "/", omittingEmptySubsequences: false).map {
            transposeRoot(String($0), by: semitones, flats: key.prefersFlats, names: key.noteNames)
        }.joined(separator: "/")
    }
    private static func transposeRoot(_ value: String, by amount: Int, flats: Bool, names spelling: [String]? = nil) -> String {
        let chars = Array(value)
        guard let first = chars.first, let base = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11][String(first)] else { return value }
        var note = base; var consumed = 1
        if chars.count > 1 {
            if chars[1] == "#" || chars[1] == "♯" { note += 1; consumed += 1 }
            if chars[1] == "b" || chars[1] == "♭" { note -= 1; consumed += 1 }
        }
        let names = flats ? ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"] : ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        return (spelling ?? names)[((note + amount) % 12 + 12) % 12] + String(chars.dropFirst(consumed))
    }
}
