import Foundation

struct GuitarChord: Equatable, Sendable {
    var root: Int
    var quality: String
    var bass: Int?
    static let intervals: [String: [Int]] = ["": [0,4,7], "m": [0,3,7], "7": [0,4,7,10], "maj7": [0,4,7,11], "m7": [0,3,7,10], "sus2": [0,2,7], "sus4": [0,5,7], "dim": [0,3,6], "aug": [0,4,8]]
    static func parse(_ symbol: String) -> GuitarChord? {
        let value = symbol.replacingOccurrences(of: "♯", with: "#").replacingOccurrences(of: "♭", with: "b")
        let parts = value.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count <= 2, let main = parts.first, let first = main.first, "ABCDEFG".contains(first) else { return nil }
        let chars = Array(main), rootCount = chars.count > 1 && (chars[1] == "#" || chars[1] == "b") ? 2 : 1
        guard let root = MusicalKey.pitch(String(chars.prefix(rootCount))) else { return nil }
        var quality = String(chars.dropFirst(rootCount))
        quality = ["maj":"", "M":"", "min":"m", "min7":"m7", "M7":"maj7", "Δ7":"maj7", "-":"m", "-7":"m7", "+":"aug", "°":"dim", "sus":"sus4"][quality] ?? quality
        guard intervals[quality] != nil else { return nil }
        var bass: Int?
        if parts.count == 2 { guard let note = MusicalKey.pitch(String(parts[1])) else { return nil }; bass = note }
        return GuitarChord(root: root, quality: quality, bass: bass)
    }
    var pitches: Set<Int> { Set((Self.intervals[quality] ?? []).map { (root + $0) % 12 }) }
}
struct GuitarBarre: Equatable, Sendable { var fret: Int; var from: Int; var to: Int; var finger = 1 }
struct GuitarFingering: Equatable, Sendable, Identifiable {
    var name: String
    /// Low E to high E. -1 muted, 0 open. Frets are relative to the capo.
    var frets: [Int]
    var fingers: [Int]
    var barres: [GuitarBarre] = []
    var id: String { frets.map(String.init).joined(separator: ",") }
    var firstFret: Int { let positive = frets.filter { $0 > 0 }; return (positive.max() ?? 0) <= 4 ? 1 : positive.min() ?? 1 }
    var pitches: Set<Int> { Set(zip([40,45,50,55,59,64], frets).filter { $0.1 >= 0 }.map { ($0.0 + $0.1) % 12 }) }
    var bass: Int? { zip([40,45,50,55,59,64], frets).filter { $0.1 >= 0 }.map { $0.0 + $0.1 }.min().map { $0 % 12 } }
}

/// Standard tuning E A D G B E. Movable closed shapes retain their intervals under translation.
/// All emitted fingerings must contain exactly the chord tones and the requested bass.
enum ChordFingeringLibrary {
    private static func position(_ name: String, _ frets: [Int], _ fingers: [Int], _ barres: [GuitarBarre] = []) -> GuitarFingering { GuitarFingering(name: name, frets: frets, fingers: fingers, barres: barres) }
    static let open: [String: [GuitarFingering]] = [
        "C": [position("Ouverte", [-1,3,2,0,1,0], [0,3,2,0,1,0])],
        "D": [position("Ouverte", [-1,-1,0,2,3,2], [0,0,0,1,3,2])],
        "E": [position("Ouverte", [0,2,2,1,0,0], [0,2,3,1,0,0])],
        "F": [position("Simplifiée · quatre cordes", [-1,-1,3,2,1,1], [0,0,3,2,1,1], [GuitarBarre(fret: 1, from: 4, to: 5)])],
        "G": [position("Ouverte", [3,2,0,0,0,3], [2,1,0,0,0,3])],
        "A": [position("Ouverte", [-1,0,2,2,2,0], [0,0,1,2,3,0])],
        "Am": [position("Ouverte", [-1,0,2,2,1,0], [0,0,2,3,1,0])],
        "Dm": [position("Ouverte", [-1,-1,0,2,3,1], [0,0,0,2,3,1])],
        "Em": [position("Ouverte", [0,2,2,0,0,0], [0,2,3,0,0,0])],
        "C7": [position("Ouverte", [-1,3,2,3,1,0], [0,3,2,4,1,0])],
        "D7": [position("Ouverte", [-1,-1,0,2,1,2], [0,0,0,2,1,3])],
        "E7": [position("Ouverte", [0,2,0,1,0,0], [0,2,0,1,0,0])],
        "G7": [position("Ouverte", [3,2,0,0,0,1], [3,2,0,0,0,1])],
        "A7": [position("Ouverte", [-1,0,2,0,2,0], [0,0,1,0,2,0])],
        "B7": [position("Ouverte", [-1,2,1,2,0,2], [0,2,1,3,0,4])],
        "Cmaj7": [position("Ouverte", [-1,3,2,0,0,0], [0,3,2,0,0,0])],
        "Dmaj7": [position("Ouverte", [-1,-1,0,2,2,2], [0,0,0,1,1,1], [GuitarBarre(fret: 2, from: 3, to: 5)])],
        "Amaj7": [position("Ouverte", [-1,0,2,1,2,0], [0,0,2,1,3,0])],
        "Am7": [position("Ouverte", [-1,0,2,0,1,0], [0,0,2,0,1,0])],
        "Dm7": [position("Ouverte", [-1,-1,0,2,1,1], [0,0,0,2,1,1], [GuitarBarre(fret: 1, from: 4, to: 5)])],
        "Em7": [position("Ouverte", [0,2,0,0,0,0], [0,2,0,0,0,0])],
        "Asus2": [position("Ouverte", [-1,0,2,2,0,0], [0,0,1,2,0,0])],
        "Dsus2": [position("Ouverte", [-1,-1,0,2,3,0], [0,0,0,1,3,0])],
        "Asus4": [position("Ouverte", [-1,0,2,2,3,0], [0,0,1,2,3,0])],
        "Dsus4": [position("Ouverte", [-1,-1,0,2,3,3], [0,0,0,1,3,4])],
        "C/G": [position("Basse Sol", [3,3,2,0,1,0], [3,4,2,0,1,0])],
        "D/F#": [position("Basse Fa♯", [2,0,0,2,3,2], [1,0,0,2,4,3])]
    ]
    static func positions(for symbol: String) -> [GuitarFingering] {
        guard let chord = GuitarChord.parse(symbol) else { return [] }
        var result: [GuitarFingering] = []
        // Enharmonic spelling does not change a fingering.
        for key in open.keys.sorted() where GuitarChord.parse(key) == chord { result += open[key] ?? [] }
        if chord.bass == nil || chord.bass == chord.root {
            let rootE = (chord.root - 4 + 12) % 12
            let shape: ([Int], [Int])?
            switch chord.quality {
            case "": shape = ([0,2,2,1,0,0], [1,3,4,2,1,1])
            case "m": shape = ([0,2,2,0,0,0], [1,3,4,1,1,1])
            case "7": shape = ([0,2,0,1,0,0], [1,3,1,2,1,1])
            case "m7": shape = ([0,2,0,0,0,0], [1,3,1,1,1,1])
            case "sus4": shape = ([0,2,2,2,0,0], [1,2,3,4,1,1])
            default: shape = nil
            }
            if let shape {
                let fret = rootE == 0 ? 12 : rootE
                result.append(position("Barré · forme de Mi", shape.0.map { $0 + fret }, shape.1, [GuitarBarre(fret: fret, from: 0, to: 5)]))
            }
            let rootD = (chord.root - 2 + 12) % 12
            let fret = rootD == 0 ? 12 : rootD
            let dShapes: [String: ([Int], [Int], [GuitarBarre])] = [
                "": ([0,2,3,2], [1,2,4,3], []),
                "m": ([0,2,3,1], [1,3,4,2], []),
                "7": ([0,2,1,2], [1,3,2,4], []),
                "maj7": ([0,2,2,2], [1,3,3,3], [GuitarBarre(fret: fret + 2, from: 3, to: 5, finger: 3)]),
                "m7": ([0,2,1,1], [1,3,2,2], [GuitarBarre(fret: fret + 1, from: 4, to: 5, finger: 2)]),
                "sus2": ([0,2,3,0], [1,2,3,1], [GuitarBarre(fret: fret, from: 2, to: 5)]),
                "sus4": ([0,2,3,3], [1,2,3,4], []),
                "dim": ([0,1,3,1], [1,2,4,2], [GuitarBarre(fret: fret + 1, from: 3, to: 5, finger: 2)]),
                "aug": ([0,3,3,2], [1,3,4,2], [])
            ]
            if let shape = dShapes[chord.quality] { result.append(position("Quatre cordes · forme de Ré", [-1,-1] + shape.0.map { $0 + fret }, [0,0] + shape.1, shape.2)) }
        }
        var seen: Set<String> = []
        return result.filter { $0.pitches == chord.pitches && $0.bass == (chord.bass ?? chord.root) && seen.insert($0.id).inserted }
    }
}
