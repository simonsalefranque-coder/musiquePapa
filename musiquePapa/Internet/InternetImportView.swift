import SwiftUI
import WebKit
import Combine

@MainActor final class SongBrowser: NSObject, ObservableObject, WKNavigationDelegate {
    let view: WKWebView
    @Published var currentURL = ""
    @Published var error: String?
    @Published var loading = false
    override init() {
        let config = WKWebViewConfiguration(); config.websiteDataStore = .nonPersistent()
        view = WKWebView(frame: .zero, configuration: config)
        super.init(); view.navigationDelegate = self; view.allowsBackForwardNavigationGestures = true
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing"), ProcessInfo.processInfo.arguments.contains("--web-import-fixture"),
           let url = Bundle.main.url(forResource: "WebImportDemo", withExtension: "html"), let html = try? String(contentsOf: url, encoding: .utf8) {
            view.loadHTMLString(html, baseURL: URL(string: "https://www.boiteachansons.net"))
        }
        #endif
    }
    func navigate(_ input: String) {
        do {
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            let url: URL
            if trimmed.contains("://") { url = try WebSongImportService.validatedURL(trimmed) }
            else {
                var search = URLComponents(string: "https://www.google.com/search")!
                search.queryItems = [URLQueryItem(name: "q", value: trimmed + " accords guitare")]
                url = search.url!
            }
            view.load(URLRequest(url: url))
        } catch { self.error = error.localizedDescription }
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { loading = true }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loading = false; currentURL = webView.url?.absoluteString ?? "" }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { loading = false; self.error = error.localizedDescription }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { loading = false; self.error = error.localizedDescription }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let scheme = navigationAction.request.url?.scheme?.lowercased()
        decisionHandler(scheme == "https" || scheme == "http" || scheme == "about" ? .allow : .cancel)
    }

}
struct SongBrowserView: UIViewRepresentable {
    let browser: SongBrowser
    func makeUIView(context: Context) -> WKWebView { browser.view }
    func updateUIView(_ view: WKWebView, context: Context) {}
}
struct InternetImportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var browser = SongBrowser()
    @State private var address = ""
    @State private var pasted = ""
    @State private var title = "Partition convertie"
    @State private var mode: String
    init(initialMode: String = "Internet") { _mode = State(initialValue: initialMode) }
    @State private var draft: ConversionDraft?
    @State private var showRecovery = false
    @State private var selectionHelp = false
    @State private var busy = false
    @State private var worker: Task<Void, Never>?
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("Source", selection: $mode) { Text("Internet").tag("Internet"); Text("Coller un texte").tag("Texte") }.pickerStyle(.segmented)
                Text("Importez uniquement les contenus dont vous pouvez réutiliser les paroles et accords. Aucun accès protégé n’est contourné.").font(.footnote).foregroundStyle(.secondary)
                TextField("Titre de la chanson", text: $title).textFieldStyle(.roundedBorder).accessibilityIdentifier("conversionTitle")
                if mode == "Internet" {
                    HStack {
                        Button { browser.view.goBack() } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Page précédente")
                        TextField("Titre, artiste ou URL https://", text: $address).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder).onSubmit { browser.navigate(address) }
                        Button("Ouvrir / Rechercher") { browser.navigate(address) }
                    }
                    if browser.loading { ProgressView() }
                    if selectionHelp { Text("Appuyez longuement dans la partition, étendez la sélection aux paroles et aux accords, puis touchez « Utiliser le texte de la page ».").font(.callout) }
                    SongBrowserView(browser: browser)
                    Text(browser.currentURL).font(.caption).lineLimit(1).foregroundStyle(.secondary)
                    HStack {
                        Button("Importer cette URL (fichier texte)") { run {
                            let url = try WebSongImportService.validatedURL(address)
                            return try await WebSongImportService.download(url)
                        } }
                        Button("Utiliser le texte de la page") { run {
                            try await WebScoreExtractor.makeDraft(from: browser.view, title: title)
                        } }
                    }.buttonStyle(.bordered)
                } else {
                    TextEditor(text: $pasted).font(.system(size: 18, design: .monospaced)).autocorrectionDisabled().accessibilityIdentifier("conversionPaste")
                    Button("Convertir et vérifier", systemImage: "text.badge.checkmark") { run {
                        guard pasted.utf8.count <= 5_000_000 else { throw MusicError.message("Le texte dépasse 5 Mo.") }
                        let text = pasted, name = title
                        let result = await Task.detached { ChordTextConverter.convert(text, title: name) }.value
                        return ConversionDraft(result: result, originalData: Data(text.utf8))
                    } }.buttonStyle(.borderedProminent).disabled(pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("convertPasted")
                }
                if busy { ProgressView("Préparation…") }
            }.padding().disabled(busy)
                .navigationTitle("Internet et conversion").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { worker?.cancel(); dismiss() } } }
        }.onChange(of: browser.currentURL) { _, value in address = value }
        .fullScreenCover(item: $draft) { ConversionReviewView(draft: $0) }
        .alert("Importation Internet", isPresented: Binding(get: { browser.error != nil }, set: { if !$0 { browser.error = nil } })) { Button("Compris", role: .cancel) {} } message: { Text(browser.error ?? "") }
        .confirmationDialog("Aucune zone musicale fiable détectée", isPresented: $showRecovery, titleVisibility: .visible) {
            Button("Sélectionner dans la page") { selectionHelp = true }
            Button("Coller un texte") { mode = "Texte" }
            Button("Récupérer le contenu pour le corriger") { run {
                try await WebScoreExtractor.makeDraft(from: browser.view, title: title, allowWholePage: true)
            } }
            Button("Annuler", role: .cancel) {}
        } message: { Text("Sélectionnez uniquement la partition, collez son texte ou récupérez le contenu visible pour une correction manuelle.") }
        .onDisappear { worker?.cancel() }
    }
    private func run(_ operation: @escaping @MainActor () async throws -> ConversionDraft) {
        busy = true
        worker = Task { @MainActor in
            defer { busy = false }
            do { let value = try await operation(); try Task.checkCancellation(); draft = value }
            catch is CancellationError {} catch is WebExtractionError { showRecovery = true } catch { browser.error = error.localizedDescription }
        }
    }
}
