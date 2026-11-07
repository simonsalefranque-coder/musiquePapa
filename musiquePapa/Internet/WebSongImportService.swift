import Foundation

/// Direct text downloads only. HTML is read from the user's visible browser on explicit request.
enum WebSongImportService {
    static func validatedURL(_ input: String) throws -> URL {
        guard let url = URL(string: input.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil,
              url.user == nil, url.password == nil else { throw MusicError.message("Saisissez une adresse https:// valide, sans identifiants intégrés.") }
        return url
    }
    static func download(_ url: URL, session: URLSession = .shared) async throws -> ConversionDraft {
        _ = try validatedURL(url.absoluteString)
        var request = URLRequest(url: url); request.timeoutInterval = 30
        let (stream, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw MusicError.message("Le serveur n’autorise pas le téléchargement de ce document.") }
        guard response.expectedContentLength <= 5_000_000 else { throw MusicError.message("Le fichier texte dépasse 5 Mo.") }
        if response.mimeType?.lowercased().contains("html") == true { throw MusicError.message("Cette adresse est une page web. Ouvrez-la dans le navigateur et utilisez « Utiliser le texte de la page » ou collez le texte autorisé.") }
        let mime = response.mimeType?.lowercased() ?? ""
        guard mime.isEmpty || mime.hasPrefix("text/") || ["application/octet-stream", "application/x-chordpro", "application/chordpro"].contains(mime) else {
            throw MusicError.message("Cette URL ne désigne pas un fichier texte ou ChordPro. Importez les PDF depuis Fichiers, puis utilisez Convertir en ChordPro.")
        }
        var data = Data()
        for try await byte in stream {
            try Task.checkCancellation()
            guard data.count < 5_000_000 else { throw MusicError.message("Le fichier texte dépasse 5 Mo.") }
            data.append(byte)
        }
        let text = try ChordProParser.decode(data)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !text.lowercased().contains("<html") else { throw MusicError.message("Aucun texte de partition exploitable dans ce document.") }
        let result = ChordTextConverter.convert(text, title: url.deletingPathExtension().lastPathComponent)
        // Keep bytes/encoding of the source; the new ChordPro is always UTF-8.
        return ConversionDraft(result: result, originalData: data, sourceURL: response.url?.absoluteString ?? url.absoluteString)
    }
}
