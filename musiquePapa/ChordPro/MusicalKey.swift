import Foundation

/// The tonic and mode describe a key; the capo never enters the interval calculation.
struct MusicalKey: Codable, Equatable, Sendable {
    enum Mode: String, Codable, CaseIterable, Sendable { case major, minor
        var label: String { self == .major ? "Majeur" : "Mineur" }
    }
    var tonic: String
    var mode: Mode = .major
    static let chromatic: [[String]] = [["C"], ["C#", "Db"], ["D"], ["D#", "Eb"], ["E"], ["F"], ["F#", "Gb"], ["G"], ["G#", "Ab"], ["A"], ["A#", "Bb"], ["B"]]
    var symbol: String { tonic + (mode == .minor ? "m" : "") }
    var label: String { "\(Self.french(tonic)) (\(symbol)) · \(mode.label.lowercased())" }
    var pitch: Int { Self.pitch(tonic) ?? 0 }
    var prefersFlats: Bool {
        tonic.contains("b") || (mode == .major ? ["F"].contains(tonic) : ["D", "G", "C", "F"].contains(tonic))
    }
    func interval(to target: MusicalKey) -> Int { let delta = (target.pitch - pitch + 12) % 12; return delta > 6 ? delta - 12 : delta }
    static func french(_ tonic: String) -> String {
        guard let first = tonic.first else { return tonic }
        return (["C": "Do", "D": "Ré", "E": "Mi", "F": "Fa", "G": "Sol", "A": "La", "B": "Si"][String(first)] ?? String(first)) + tonic.dropFirst().replacingOccurrences(of: "#", with: "♯").replacingOccurrences(of: "b", with: "♭")
    }
    static func pitch(_ value: String) -> Int? {
        guard let first = value.first, let base = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11][String(first)] else { return nil }
        let suffix = String(value.dropFirst())
        guard ["", "#", "b"].contains(suffix) else { return nil }
        return (base + (suffix == "#" ? 1 : suffix == "b" ? -1 : 0) + 12) % 12
    }
    static func parse(_ value: String) -> MusicalKey? {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "♯", with: "#").replacingOccurrences(of: "♭", with: "b")
        for (name, symbol) in [("sol", "G"), ("do", "C"), ("ré", "D"), ("re", "D"), ("mi", "E"), ("fa", "F"), ("la", "A"), ("si", "B")] {
            if text.lowercased().hasPrefix(name) { text = symbol + text.dropFirst(name.count); break }
        }
        guard let first = text.first else { return nil }
        text = first.uppercased() + text.dropFirst()
        let chars = Array(text)
        let count = chars.count > 1 && ["#", "b"].contains(String(chars[1])) ? 2 : 1
        let tonic = String(chars.prefix(count))
        guard pitch(tonic) != nil else { return nil }
        let rawSuffix = String(chars.dropFirst(count)).trimmingCharacters(in: .whitespaces)
        if rawSuffix == "M" { return MusicalKey(tonic: tonic) }
        let suffix = rawSuffix.lowercased()
        if ["", "maj", "major", "majeur"].contains(suffix) { return MusicalKey(tonic: tonic) }
        if ["m", "min", "minor", "mineur"].contains(suffix) { return MusicalKey(tonic: tonic, mode: .minor) }
        return nil
    }
    // Spell the seven diatonic notes for this key (including E#, B#, Cb, Fb).
    var noteNames: [String] {
        var names = prefersFlats ? ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"] : ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let letters = ["C", "D", "E", "F", "G", "A", "B"]
        let start = letters.firstIndex(of: String(tonic.prefix(1))) ?? 0
        let intervals = mode == .major ? [0, 2, 4, 5, 7, 9, 11] : [0, 2, 3, 5, 7, 8, 10]
        for (index, interval) in intervals.enumerated() {
            let letter = letters[(start + index) % 7], target = (pitch + interval) % 12
            let delta = (target - (Self.pitch(letter) ?? 0) + 12) % 12
            if delta == 0 { names[target] = letter }
            else if delta == 1 { names[target] = letter + "#" }
            else if delta == 11 { names[target] = letter + "b" }
        }
        return names
    }
}
