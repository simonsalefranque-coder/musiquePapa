import SwiftUI

@main
struct MusiquePapaApp: App {
    @StateObject private var library: LibraryStore
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MusiquePapaUITests")
            if ProcessInfo.processInfo.arguments.contains("--reset-ui-testing") { try? FileManager.default.removeItem(at: root) }
            _library = StateObject(wrappedValue: LibraryStore(directory: root))
            let fixtures = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("TestsImport")
            try? FileManager.default.createDirectory(at: fixtures, withIntermediateDirectories: true)
            try? Data("{title: Import depuis Fichiers}\n{artist: Test original}\n[Am]Importation native réussie.".utf8).write(to: fixtures.appendingPathComponent("Import_depuis_Fichiers.pro"))
        } else { _library = StateObject(wrappedValue: LibraryStore()) }
        #else
        _library = StateObject(wrappedValue: LibraryStore())
        #endif
    }
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(library)
                .environment(\.locale, Locale(identifier: "fr_FR"))
                .preferredColorScheme(library.settings.theme == "dark" ? .dark : library.settings.theme == "light" ? .light : nil)
                .tint(Color(red: 0.13, green: 0.36, blue: 0.68))
                .onOpenURL { url in Task { await library.importFiles([url]) } }
        }
    }
}
