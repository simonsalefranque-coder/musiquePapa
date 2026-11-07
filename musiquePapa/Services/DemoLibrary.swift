import Foundation

@MainActor
enum DemoLibrary {
    static func install(in library: LibraryStore) async {
        let files = [Bundle.main.url(forResource: "Balade_du_dimanche", withExtension: "pro"), Bundle.main.url(forResource: "Exercice_10_pages", withExtension: "pdf")].compactMap { $0 }
        guard files.count == 2 else { library.error = "Les fichiers de démonstration sont absents du paquet de l’application."; return }
        await library.importFiles(files)
    }
}
