import SwiftUI
import Combine

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var state = LibraryState()
    @Published var error: String?
    @Published var importReport: String?
    @Published var isImporting = false
    @Published var importProgress: Double = 0
    @Published var importFilename = ""
    private let persistence: LibraryPersistence?
    private var readOnly = false
    var songs: [Song] { state.songs }
    var playlists: [Playlist] { state.playlists }
    var settings: AppSettings { state.settings }

    init(directory: URL? = nil) {
        do {
            let root = try directory ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("MusiquePapa", isDirectory: true)
            let storage = try LibraryPersistence(directory: root)
            persistence = storage
            do { state = try storage.load() }
            catch {
                if let backup = try? storage.loadBackup() {
                    state = backup
                    self.error = "La bibliothèque a été restaurée depuis sa sauvegarde de secours."
                } else {
                    readOnly = true
                    self.error = "La bibliothèque est illisible. Les fichiers sont conservés ; aucune donnée ne sera écrasée. \(error.localizedDescription)"
                }
            }
        } catch { persistence = nil; readOnly = true; self.error = error.localizedDescription }
    }
    @discardableResult
    func commit(_ change: (inout LibraryState) -> Void) -> Bool {
        guard let persistence, !readOnly else { error = "Stockage indisponible. La bibliothèque n’a pas été modifiée."; return false }
        var next = state; change(&next); next.version = 2
        do { try persistence.save(next); state = next; return true }
        catch { self.error = "Enregistrement impossible : \(error.localizedDescription)"; return false }
    }
    func song(_ id: UUID?) -> Song? { songs.first { $0.id == id } }
    func url(for song: Song) -> URL? { persistence?.documentsURL.appendingPathComponent(song.localFilename) }
    func updateSong(_ id: UUID, change: (inout Song) -> Void) {
        commit { state in if let index = state.songs.firstIndex(where: { $0.id == id }) { change(&state.songs[index]) } }
    }
    func open(_ id: UUID) {
        commit { state in state.lastSongID = id; if let i = state.songs.firstIndex(where: { $0.id == id }) { state.songs[i].lastOpened = Date() } }
    }
    func delete(_ song: Song) {
        guard !isImporting else { error = "Attendez la fin de l’importation avant de supprimer une partition."; return }
        if commit({ state in
            state.songs.removeAll { $0.id == song.id }
            for i in state.playlists.indices { state.playlists[i].songIDs.removeAll { $0 == song.id } }
            if state.lastSongID == song.id { state.lastSongID = nil }
        }) {
            // Retain files referenced by the previous catalog, allowing a safe backup recovery.
            // Unreferenced files are reclaimed by the explicit storage-cleanup action.
        }
    }
    func updateSettings(_ change: (inout AppSettings) -> Void) { commit { change(&$0.settings) } }
    func createPlaylist(_ name: String) { let clean = name.trimmingCharacters(in: .whitespacesAndNewlines); if !clean.isEmpty { commit { $0.playlists.append(Playlist(name: clean)) } } }
    func updatePlaylist(_ id: UUID, _ change: (inout Playlist) -> Void) { commit { state in if let i = state.playlists.firstIndex(where: { $0.id == id }) { change(&state.playlists[i]) } } }
    func deletePlaylist(_ id: UUID) { commit { $0.playlists.removeAll { $0.id == id } } }

    @discardableResult
    func accept(_ item: ImportedScore) throws -> String {
        guard let persistence, !readOnly else { throw MusicError.message("Le stockage est indisponible.") }
        // Deduplicated paths may later diverge. Split the aliases before updating
        // so a refresh never alternates one local song between two different files.
        var working = state
        var sourceIndex = item.source.flatMap { source in working.songs.firstIndex { $0.sources.contains(source) } }
        if let i = sourceIndex, let edit = working.songs[i].editing,
           working.songs[i].digest != edit.original.digest {
            if item.digest == edit.original.digest || item.digest == working.songs[i].digest { return "unchanged" }
            throw MusicError.message("\(working.songs[i].title) : le fichier source a changé, mais vos modifications locales sont conservées. Pour comparer les deux versions, importez ce fichier séparément depuis Fichiers ; une nouvelle partition sera créée.")
        }
        if let i = sourceIndex, let source = item.source,
           working.songs[i].digest != item.digest, working.songs[i].sources.count > 1 {
            if working.songs[i].sources.first == source {
                var unchangedAliases = working.songs[i]
                unchangedAliases.id = UUID(); unchangedAliases.sources.removeFirst()
                working.songs[i].sources = [source]
                working.songs.append(unchangedAliases)
            } else {
                working.songs[i].sources.removeAll { $0 == source }
                sourceIndex = nil
            }
        }
        if let duplicate = working.songs.firstIndex(where: { $0.digest == item.digest }), sourceIndex == nil || sourceIndex == duplicate {
            if let source = item.source, !working.songs[duplicate].sources.contains(source) { working.songs[duplicate].sources.append(source) }
            if working.songs != state.songs {
                guard commit({ $0 = working }) else { throw MusicError.message(error ?? "Enregistrement impossible.") }
            }
            return "unchanged"
        }
        let filename = "\(UUID().uuidString).\(item.fileExtension)"
        let destination = persistence.documentsURL.appendingPathComponent(filename)
        try item.data.write(to: destination, options: .atomic)
        let success = commit { state in
            state = working
            if let i = sourceIndex {
                state.songs[i].localFilename = filename; state.songs[i].digest = item.digest
                if !state.songs[i].customTitle { state.songs[i].title = item.title }
                state.songs[i].artist = item.artist; state.songs[i].format = item.format
                state.songs[i].editing = nil
            } else {
                var song = Song(title: item.title, artist: item.artist, format: item.format, localFilename: filename, digest: item.digest)
                song.sources = item.source.map { [$0] } ?? []
                song.preferences.fontSize = state.settings.defaultFontSize
                state.songs.append(song)
            }
        }
        guard success else { try? FileManager.default.removeItem(at: destination); throw MusicError.message(error ?? "Enregistrement impossible.") }
        return sourceIndex == nil ? "added" : "updated"
    }
    func importFiles(_ urls: [URL], folder: Bool = false, link: Bool = false, linkedID: UUID? = nil) async {
        guard !isImporting else { return }
        isImporting = true; importProgress = 0; importReport = nil
        defer { isImporting = false; importFilename = "" }
        var added = 0, updated = 0, unchanged = 0
        var failures: [String] = []
        for root in urls {
            let scope = root.startAccessingSecurityScopedResource()
            defer { if scope { root.stopAccessingSecurityScopedResource() } }
            do {
                var sourceID = linkedID
                if link {
                    var folderLink = try FilesFolderProvider.link(root)
                    if let previous = state.folder,
                       let previousURL = try? FilesFolderProvider().resolve(previous).url,
                       previousURL.standardizedFileURL == root.standardizedFileURL {
                        folderLink.id = previous.id; folderLink.lastRefresh = previous.lastRefresh
                    }
                    guard commit({ $0.folder = folderLink }) else { throw MusicError.message(error ?? "Enregistrement impossible.") }
                    sourceID = folderLink.id
                }
                let files = folder ? try await Task.detached { try DocumentImportService.enumerate(root) }.value : [root]
                for (index, file) in files.enumerated() {
                    importFilename = file.lastPathComponent
                    let relativePath = String(file.path.dropFirst(root.path.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    let source = sourceID.map { "\($0.uuidString)/\(relativePath)" }
                    do {
                        let item = try await Task.detached { try DocumentImportService.read(file, source: source) }.value
                        switch try accept(item) { case "added": added += 1; case "updated": updated += 1; default: unchanged += 1 }
                    } catch { failures.append("\(file.lastPathComponent) : \(error.localizedDescription)") }
                    importProgress = Double(index + 1) / Double(max(1, files.count))
                }
                if sourceID != nil, failures.isEmpty { commit { $0.folder?.lastRefresh = Date() } }
            } catch { failures.append(error.localizedDescription) }
        }
        importProgress = 1
        importReport = "\(added) ajoutée(s), \(updated) mise(s) à jour, \(unchanged) déjà présente(s)." + (failures.isEmpty ? "" : "\n\n\(failures.joined(separator: "\n"))")
    }
    func refreshFolder() async {
        guard let link = state.folder else { return }
        do {
            let resolved = try FilesFolderProvider().resolve(link)
            if let bookmark = resolved.refreshedBookmark { commit { $0.folder?.bookmark = bookmark } }
            await importFiles([resolved.url], folder: true, linkedID: link.id)
        } catch { self.error = "Accès au dossier impossible. Choisissez-le à nouveau dans Fichiers. \(error.localizedDescription)" }
    }
    var storageBytes: Int64 {
        guard let persistence else { return 0 }
        return ((try? FileManager.default.contentsOfDirectory(at: persistence.documentsURL, includingPropertiesForKeys: [.fileSizeKey])) ?? []).reduce(0) { $0 + Int64((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }
    func cleanUnusedFiles() {
        guard let persistence, !isImporting else { return }
        let backupNames = (try? persistence.loadBackup().songs.flatMap(\.retainedFilenames)) ?? []
        let keep = Set(songs.flatMap(\.retainedFilenames) + backupNames)
        do {
            for file in try FileManager.default.contentsOfDirectory(at: persistence.documentsURL, includingPropertiesForKeys: nil) where !keep.contains(file.lastPathComponent) { try FileManager.default.removeItem(at: file) }
            importReport = "Nettoyage terminé. Les partitions actives et la sauvegarde de secours sont conservées."
        } catch { self.error = error.localizedDescription }
    }

    func conversionDraft(for song: Song) throws -> ConversionDraft? {
        guard let origin = song.conversionOrigin, let persistence else { return nil }
        let data = try Data(contentsOf: persistence.documentsURL.appendingPathComponent(origin.filename))
        let text = origin.isPDF ? "" : try ChordProParser.decode(data)
        return ConversionDraft(result: ConversionResult(source: try editableSource(song.id), warnings: origin.warnings, originalText: text, webDiagnostics: origin.webDiagnostics), originalData: data, isPDF: origin.isPDF, sourceURL: origin.sourceURL)
    }

    func editableSource(_ id: UUID) throws -> String {
        guard let song = song(id), song.format == .chordPro, let url = url(for: song) else { throw MusicError.message("Cette partition ChordPro est introuvable.") }
        let data = try Data(contentsOf: url)
        guard data.count <= 5_000_000 else { throw MusicError.message("Ce fichier dépasse 5 Mo. Le lecteur reste disponible ; utilisez un éditeur externe pour modifier un document de cette taille.") }
        return try ChordProParser.decode(data)
    }

    @discardableResult
    func saveChordSource(_ source: String, songID: UUID?, expectedDigest: String?, conversion: ConversionDraft? = nil) throws -> UUID {
        guard let persistence, !readOnly else { throw MusicError.message("Le stockage est indisponible.") }
        guard !isImporting else { throw MusicError.message("Attendez la fin de l’importation avant d’enregistrer. Votre texte reste dans l’éditeur.") }
        let existing = songID.flatMap { song($0) }
        if songID != nil {
            guard let existing, existing.format == .chordPro, existing.digest == expectedDigest else {
                throw MusicError.message("La partition a changé depuis l’ouverture de l’éditeur. Exportez votre texte pour le conserver, puis rouvrez la partition avant de fusionner les modifications.")
            }
        }
        let item = try DocumentImportService.validate(Data(source.utf8), filename: "Chanson.chordpro")
        if let existing, item.digest == existing.digest { return existing.id }
        let filename = "\(UUID().uuidString).chordpro"
        let destination = persistence.documentsURL.appendingPathComponent(filename)
        // The old file remains immutable. Publish its replacement only after an atomic write.
        try item.data.write(to: destination, options: .atomic)
        var edited = existing ?? Song(title: item.title, artist: item.artist, format: .chordPro, localFilename: filename, digest: item.digest)
        var keepCustomTitle = false
        if let existing {
            var history = existing.editing ?? LocalEditHistory(original: ScoreVersion(existing), previous: nil, editedAt: Date())
            history.previous = ScoreVersion(existing); history.editedAt = Date(); edited.editing = history
            if let oldURL = url(for: existing), let old = try? ChordProParser.decode(Data(contentsOf: oldURL)) {
                let oldParsed = ChordProParser.parse(old), newParsed = ChordProParser.parse(source)
                edited.preferences.sourceKeyDidChange(from: oldParsed.key, to: newParsed.key)
                keepCustomTitle = existing.customTitle && oldParsed.title == newParsed.title
            }
        } else { edited.preferences.fontSize = settings.defaultFontSize }
        edited.localFilename = filename; edited.digest = item.digest
        if !keepCustomTitle { edited.title = item.title; edited.customTitle = false }
        edited.artist = item.artist
        var originalURL: URL?
        if let conversion, existing == nil {
            let name = "Original-\(UUID().uuidString).\(conversion.isPDF ? "pdf" : "txt")"
            let target = persistence.documentsURL.appendingPathComponent(name)
            do { try conversion.originalData.write(to: target, options: .atomic) }
            catch { try? FileManager.default.removeItem(at: destination); throw error }
            originalURL = target
            edited.conversionOrigin = ConversionOrigin(filename: name, isPDF: conversion.isPDF, sourceURL: conversion.sourceURL, warnings: conversion.result.warnings, webDiagnostics: conversion.result.webDiagnostics)
        }
        guard commit({ state in
            if let index = state.songs.firstIndex(where: { $0.id == edited.id }) { state.songs[index] = edited }
            else { state.songs.append(edited) }
        }) else { try? FileManager.default.removeItem(at: destination); if let originalURL { try? FileManager.default.removeItem(at: originalURL) }; throw MusicError.message(error ?? "Enregistrement impossible.") }
        return edited.id
    }
    func restorePrevious(_ id: UUID) throws {
        guard !isImporting else { throw MusicError.message("Attendez la fin de l’importation.") }
        guard var song = song(id), var history = song.editing, let previous = history.previous, let persistence else { throw MusicError.message("Aucune version précédente disponible.") }
        let url = persistence.documentsURL.appendingPathComponent(previous.localFilename)
        let item = try DocumentImportService.validate(Data(contentsOf: url), filename: previous.localFilename)
        guard item.digest == previous.digest else { throw MusicError.message("La version précédente est endommagée. Le document actuel est conservé.") }
        history.previous = ScoreVersion(song); history.editedAt = Date()
        song.localFilename = previous.localFilename; song.digest = previous.digest
        song.title = previous.title; song.artist = previous.artist; song.customTitle = previous.customTitle
        song.preferences.originalKey = previous.originalKey; song.editing = history
        guard commit({ state in if let i = state.songs.firstIndex(where: { $0.id == id }) { state.songs[i] = song } }) else { throw MusicError.message(error ?? "Restauration impossible.") }
    }
    @discardableResult
    func duplicateChordSong(_ id: UUID) throws -> UUID {
        guard let original = song(id) else { throw MusicError.message("Partition introuvable.") }
        let source = ChordSourceEditing.setDirective("title", value: original.title + " — copie", in: try editableSource(id))
        return try saveChordSource(source, songID: nil, expectedDigest: nil)
    }
}
