import Foundation

struct LibraryPersistence {
    let directory: URL
    var metadataURL: URL { directory.appendingPathComponent("bibliotheque.json") }
    var backupURL: URL { directory.appendingPathComponent("bibliotheque.backup.json") }
    var documentsURL: URL { directory.appendingPathComponent("Partitions", isDirectory: true) }
    init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
    }
    func load() throws -> LibraryState {
        guard FileManager.default.fileExists(atPath: metadataURL.path) else { return LibraryState() }
        return try JSONDecoder().decode(LibraryState.self, from: Data(contentsOf: metadataURL))
    }
    func loadBackup() throws -> LibraryState { try JSONDecoder().decode(LibraryState.self, from: Data(contentsOf: backupURL)) }
    func save(_ state: LibraryState) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let bytes = try encoder.encode(state)
        // Never replace the recovery copy with an unreadable catalog.
        if let old = try? Data(contentsOf: metadataURL), (try? JSONDecoder().decode(LibraryState.self, from: old)) != nil {
            try old.write(to: backupURL, options: .atomic)
        }
        try bytes.write(to: metadataURL, options: .atomic)
    }
}
