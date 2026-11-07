import Foundation

enum ScoreFormat: String, Codable, Sendable { case pdf, chordPro
    var label: String { self == .pdf ? "PDF" : "ChordPro" }
}
struct ReaderPreferences: Codable, Equatable, Sendable {
    var fontSize: Double = 24
    var pdfScale: Double = 0 // 0 = first opening, fit width
    var progress: Double = 0
    // nil inherits the global setting; existing numeric values decode unchanged.
    var speed: Double?
    var transpose: Int = 0
    var originalKey: MusicalKey?
    var displayKey: MusicalKey?
    var chordColor: ChordColor?

    func effectiveSpeed(_ settings: AppSettings) -> Double { min(10, max(1, speed ?? settings.defaultSpeed)) }
    func sourceKey(_ parsed: String) -> MusicalKey? { originalKey ?? MusicalKey.parse(parsed) }
    func interval(_ parsed: String) -> Int {
        guard let source = sourceKey(parsed), let target = displayKey else { return transpose }
        return source.interval(to: target)
    }
    mutating func sourceKeyDidChange(from old: String, to new: String) {
        guard old != new else { return }
        originalKey = nil
        if MusicalKey.parse(new) == nil { displayKey = nil; transpose = 0 }
    }
}
struct Song: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var title: String
    var artist: String
    var format: ScoreFormat
    var localFilename: String
    var digest: String
    var addedAt = Date()
    var lastOpened: Date?
    var favorite = false
    var customTitle = false
    var sources: [String] = []
    var preferences = ReaderPreferences()
    var editing: LocalEditHistory?
    var conversionOrigin: ConversionOrigin?
    var retainedFilenames: [String] {
        [localFilename, editing?.original.localFilename, editing?.previous?.localFilename, conversionOrigin?.filename].compactMap { $0 }
    }
}
struct ScoreVersion: Codable, Equatable, Sendable {
    var localFilename: String
    var digest: String
    var title: String
    var artist: String
    var customTitle: Bool
    var originalKey: MusicalKey?
    init(_ song: Song) {
        localFilename = song.localFilename; digest = song.digest; title = song.title
        artist = song.artist; customTitle = song.customTitle; originalKey = song.preferences.originalKey
    }
}
struct LocalEditHistory: Codable, Equatable, Sendable {
    var original: ScoreVersion
    var previous: ScoreVersion?
    var editedAt: Date
}
struct Playlist: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var songIDs: [UUID] = []
    mutating func add(_ id: UUID) { if !songIDs.contains(id) { songIDs.append(id) } }
}
struct FolderLink: Codable, Sendable {
    var id = UUID()
    var name: String
    var bookmark: Data
    var lastRefresh: Date?
}
struct AppSettings: Codable, Sendable {
    var defaultSpeed: Double = 3
    var defaultFontSize: Double = 24
    var theme = "system"
    var autoAdvance = false
    var resumePosition = true
    var chordColor: ChordColor?
}
struct LibraryState: Codable, Sendable {
    var version = 2
    var songs: [Song] = []
    var playlists: [Playlist] = []
    var settings = AppSettings()
    var folder: FolderLink?
    var lastSongID: UUID?
}
enum LibrarySort: String, CaseIterable, Identifiable {
    case az = "Titre A–Z", za = "Titre Z–A", recent = "Dernière consultation", added = "Date d’ajout"
    var id: String { rawValue }
    func sorted(_ songs: [Song]) -> [Song] {
        songs.sorted { a, b in
            switch self {
            case .az: return a.title.localizedStandardCompare(b.title) == .orderedAscending
            case .za: return a.title.localizedStandardCompare(b.title) == .orderedDescending
            case .recent: return (a.lastOpened ?? .distantPast) > (b.lastOpened ?? .distantPast)
            case .added: return a.addedAt > b.addedAt
            }
        }
    }
}
enum MusicError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}
