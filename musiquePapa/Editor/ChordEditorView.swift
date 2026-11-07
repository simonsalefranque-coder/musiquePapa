import SwiftUI
import UniformTypeIdentifiers

struct ChordEditorView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: ChordEditorModel
    var conversion: ConversionDraft? = nil
    @State private var conversionMode = "Résultat"
    @State private var showWarnings = false
    @State private var previewOnly = false
    @State private var showChords = true
    @State private var showInformation = false
    @State private var showSearch = false
    @State private var confirmDiscard = false
    @State private var confirmRestore = false
    @State private var exporting = false
    @State private var sharing: URL?
    @State private var error: String?
    @State private var query = ""
    @State private var replacement = ""
    @State private var accidental = ""
    @State private var quality = ""
    @State private var manualChord = ""
    private var song: Song? { library.song(model.songID) }
    private var preferences: ReaderPreferences {
        var value = song?.preferences ?? ReaderPreferences()
        value.sourceKeyDidChange(from: model.initialKey, to: model.preview.key)
        return value
    }

    private var previewPreferences: ReaderPreferences { var value = preferences; if conversion != nil { value.fontSize = model.fontSize }; return value }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tools
                if showChords { chordTools }
                if showSearch { searchTools }
                if conversion != nil {
                    HStack {
                        Picker("Mode de conversion", selection: $conversionMode) {
                            Text("Original").tag("Original"); Text("Résultat").tag("Résultat"); Text("Modifier").tag("Modifier")
                        }.pickerStyle(.segmented).accessibilityIdentifier("conversionMode")
                        Button("Continuer à modifier") { conversionMode = "Modifier" }
                        Button("Vérifications (\(conversion?.result.warnings.count ?? 0))") { showWarnings = true }
                    }.padding(10)
                }
                if let diagnostic = conversion?.result.webDiagnostics {
                    Text("\(diagnostic.detected) accords détectés · \(model.preview.lines.flatMap(\.segments).compactMap(\.chord).filter(ChordTextConverter.isChord).count) dans le résultat · \(diagnostic.uncertain) à vérifier")
                        .font(.callout).foregroundStyle(diagnostic.detected == 0 || diagnostic.uncertain > 0 ? .orange : .secondary)
                        .padding(.horizontal).padding(.bottom, 8).accessibilityIdentifier("webChordDiagnostics")
                }
                GeometryReader { geometry in
                    let split = geometry.size.width >= 900
                    let originalWidth = conversion != nil && (split || conversionMode == "Original") ? (split ? geometry.size.width / 2 : geometry.size.width) : 0
                    let available = geometry.size.width - originalWidth
                    let editing = conversion != nil ? conversionMode == "Modifier" : !previewOnly
                    let editWidth = conversion != nil ? (editing ? available : 0) : (split ? available / 2 : editing ? available : 0)
                    HStack(spacing: 0) {
                        if let conversion {
                            ConversionOriginalView(draft: conversion).frame(width: originalWidth).clipped().opacity(originalWidth == 0 ? 0 : 1).accessibilityHidden(originalWidth == 0)
                        }
                        VStack(spacing: 0) {
                            if split { paneTitle("Édition ChordPro") }
                            ChordTextEditor(model: model)
                        }.frame(width: editWidth).clipped().opacity(editWidth == 0 ? 0 : 1)
                            .allowsHitTesting(editWidth > 0).accessibilityHidden(editWidth == 0)
                        VStack(spacing: 0) {
                            if split { paneTitle("Aperçu en direct") }
                            if !model.preview.title.isEmpty { Text(model.preview.title).font(.headline).padding(.top, 12).padding(.horizontal) }
                            ChordPreview(song: model.preview, preferences: previewPreferences, defaultColor: library.settings.chordColor ?? .blueDefault)
                        }.frame(width: max(0, available - editWidth)).clipped().opacity(available == editWidth ? 0 : 1).accessibilityHidden(available == editWidth)
                    }
                }
                HStack {
                    Label(model.dirty ? "Modifications non enregistrées" : "Copie locale", systemImage: model.dirty ? "pencil.circle" : "checkmark.circle")
                    Spacer()
                    if model.warningCount > 0 { Label("\(model.warningCount) syntaxe(s) à vérifier", systemImage: "exclamationmark.triangle").foregroundStyle(.orange).accessibilityIdentifier("syntaxWarnings") }
                }.font(.footnote).foregroundStyle(.secondary).padding(10).background(.bar)
            }
            .navigationTitle(model.songID == nil ? "Nouvelle chanson" : "Modifier la chanson")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { if model.dirty { confirmDiscard = true } else { dismiss() } } }
                ToolbarItem(placement: .primaryAction) {
                    Button(previewOnly ? "Édition" : "Aperçu", systemImage: previewOnly ? "pencil" : "eye") {
                        if conversion != nil { conversionMode = conversionMode == "Modifier" ? "Résultat" : "Modifier" }
                        previewOnly.toggle(); if previewOnly { model.textView?.resignFirstResponder() }
                    }.accessibilityIdentifier("toggleEditorPreview")
                }
                ToolbarItem(placement: .confirmationAction) { Button(conversion != nil && model.songID == nil ? "Enregistrer en ChordPro" : "Enregistrer", action: save).fontWeight(.semibold).accessibilityIdentifier("saveChordSource") }
            }
        }
        .interactiveDismissDisabled(model.dirty)
        .sheet(isPresented: $showWarnings) {
            NavigationStack {
                List {
                    Text("Comparez chaque ligne avec l’original. Les avertissements décrivent la conversion initiale ; ils ne sont pas effacés automatiquement après correction.")
                    ForEach(Array((conversion?.result.warnings ?? []).enumerated()), id: \.offset) { _, warning in Text(warning) }
                }.navigationTitle("À vérifier").toolbar { Button("Continuer à modifier") { showWarnings = false; conversionMode = "Modifier" } }
            }
        }
        .sheet(isPresented: $showInformation) { ChordInformationView(model: model) }
        .sheet(isPresented: Binding(get: { sharing != nil }, set: { if !$0 { sharing = nil } })) { if let sharing { ShareSheet(url: sharing) } }
        .fileExporter(isPresented: $exporting, document: ChordShareDocument(text: model.text), contentType: ChordShareDocument.contentType, defaultFilename: "\(safeFilename).chordpro") { result in
            if case .failure(let failure) = result { error = failure.localizedDescription }
        }
        .alert("Quitter sans enregistrer ?", isPresented: $confirmDiscard) {
            Button("Continuer l’édition", role: .cancel) {}
            Button("Abandonner les modifications", role: .destructive) { dismiss() }
        } message: { Text("Les modifications de cette session seront perdues. La version enregistrée restera intacte.") }
        .alert("Restaurer la version précédente ?", isPresented: $confirmRestore) {
            Button("Annuler", role: .cancel) {}
            Button("Restaurer", role: .destructive) {
                do { if let id = model.songID { try library.restorePrevious(id) }; dismiss() }
                catch { self.error = error.localizedDescription }
            }
        } message: { Text("Le contenu enregistré avant la dernière modification sera rétabli. Le texte non enregistré de l’éditeur sera abandonné. La version remplacée restera restaurable.") }
        .alert("Édition ChordPro", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("Compris", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }
    private func paneTitle(_ text: String) -> some View { Text(text).font(.subheadline.bold()).frame(maxWidth: .infinity).padding(8).background(.quaternary) }
    private var tools: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Button(action: model.undo) { Image(systemName: "arrow.uturn.backward") }.disabled(!model.canUndo).accessibilityLabel("Annuler la dernière modification")
                Button(action: model.redo) { Image(systemName: "arrow.uturn.forward") }.disabled(!model.canRedo).accessibilityLabel("Rétablir la modification")
                Button("A−") { model.fontSize = max(12, model.fontSize - 2) }.accessibilityLabel("Réduire le texte d’édition")
                Text("\(Int(model.fontSize)) pt").monospacedDigit().accessibilityIdentifier("editorFontLabel")
                Button("A+") { model.fontSize = min(40, model.fontSize + 2) }.accessibilityLabel("Agrandir le texte d’édition")
                Button("Informations", systemImage: "info.circle") { showInformation = true }
                Menu {
                    ForEach(ChordSourceEditing.metadata, id: \.0) { name, label in Button(label) { model.insertDirective(name) } }
                    Button("Commentaire") { model.insertDirective("comment") }
                    Divider()
                    Button("Couplet") { model.wrap("verse") }
                    Button("Refrain") { model.wrap("chorus") }
                    Button("Tablature") { model.wrap("tab") }
                } label: { Label("Insérer", systemImage: "plus.square") }
                Button("Accords", systemImage: "music.note") { showChords.toggle() }
                Button { model.textView?.resignFirstResponder() } label: { Image(systemName: "keyboard.chevron.compact.down") }.accessibilityLabel("Masquer le clavier").accessibilityIdentifier("editorHideKeyboard")
                Menu {
                    Button("Rechercher / Remplacer", systemImage: "magnifyingglass") { showSearch.toggle() }
                    Button("Transposer la sélection +1") { model.transposeSelection(by: 1) }.disabled(!model.hasSelection)
                    Button("Transposer la sélection −1") { model.transposeSelection(by: -1) }.disabled(!model.hasSelection)
                    Divider()
                    Button("Exporter le fichier ChordPro", systemImage: "square.and.arrow.up") { exporting = true }
                    Button("Partager le fichier ChordPro", systemImage: "square.and.arrow.up.on.square") { share() }
                    Button("Restaurer la version précédente", systemImage: "clock.arrow.circlepath") { confirmRestore = true }.disabled(song?.editing?.previous == nil)
                } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("Options de l’éditeur")
            }.buttonStyle(.bordered).controlSize(.regular).padding(10)
        }.background(.bar)
    }
    private var chordTools: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Picker("Altération", selection: $accidental) { Text("♮").tag(""); Text("♯").tag("#"); Text("♭").tag("b") }.pickerStyle(.segmented).frame(width: 130)
                Menu {
                    Picker("Type d’accord", selection: $quality) {
                        ForEach(["", "m", "7", "m7", "maj7", "sus2", "sus4", "dim", "aug", "6", "9", "add9"], id: \.self) { Text($0.isEmpty ? "Majeur" : $0).tag($0) }
                    }
                } label: { Text(quality.isEmpty ? "Majeur" : quality).frame(minWidth: 50) }
                ForEach(["C", "D", "E", "F", "G", "A", "B"], id: \.self) { root in
                    let chord = root + accidental + quality
                    Button(chord) { model.insertChord(chord) }.accessibilityLabel("Insérer l’accord \(chord)")
                }
                TextField("Ex. F#m7/C#", text: $manualChord).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder).frame(width: 135).accessibilityIdentifier("manualChord")
                Button("Insérer l’accord") { model.insertChord(manualChord); manualChord = "" }.disabled(!ChordSourceEditing.validChord(manualChord))
            }.buttonStyle(.bordered).padding(.horizontal, 10).padding(.vertical, 7)
        }.background(.thinMaterial)
    }
    private var searchTools: some View {
        HStack {
            TextField("Rechercher", text: $query).accessibilityIdentifier("editorSearch")
            Button("Suivant") { model.find(query) }.disabled(query.isEmpty)
            TextField("Remplacer par", text: $replacement)
            Button("Remplacer") { model.replaceFound(query, with: replacement) }.disabled(query.isEmpty)
            Button { showSearch = false } label: { Image(systemName: "xmark") }.accessibilityLabel("Fermer la recherche")
        }.textFieldStyle(.roundedBorder).buttonStyle(.bordered).padding(10).background(.bar)
    }
    private var safeFilename: String {
        let title = ChordProParser.parse(model.text).title
        let safe = title.components(separatedBy: CharacterSet(charactersIn: "/\\:\n\r")).joined(separator: "-")
        return safe.isEmpty ? "Chanson" : String(safe.prefix(100))
    }
    private func save() {
        do { try library.saveChordSource(model.text, songID: model.songID, expectedDigest: model.expectedDigest, conversion: conversion); dismiss() }
        catch { self.error = error.localizedDescription }
    }
    private func share() {
        do {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Export-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(safeFilename + ".chordpro")
            try Data(model.text.utf8).write(to: url, options: .atomic); sharing = url
        } catch { self.error = error.localizedDescription }
    }
}

struct ChordInformationView: View {
    @ObservedObject var model: ChordEditorModel
    @Environment(\.dismiss) private var dismiss
    @State private var fields: [String: String] = [:]
    var body: some View {
        NavigationStack {
            Form {
                ForEach(ChordSourceEditing.metadata, id: \.0) { name, label in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(label).font(.caption).foregroundStyle(.secondary)
                        TextField(label, text: Binding(get: { fields[name] ?? "" }, set: { fields[name] = $0 }))
                            .accessibilityIdentifier("metadata-\(name)")
                    }.padding(.vertical, 3)
                }
                Text("La tonalité d’origine décrit les accords écrits dans le fichier (ex. C, Bb, F#m). Le capo ne transpose pas les accords. Les autres directives sont conservées.").font(.footnote).foregroundStyle(.secondary)
            }
            .navigationTitle("Informations")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Appliquer") { model.setMetadata(fields); dismiss() } }
            }
        }.onAppear {
            let parsed = ChordProParser.parse(model.text)
            fields = ["title": parsed.title, "artist": parsed.artist, "key": parsed.key, "capo": parsed.capo, "tempo": parsed.tempo, "subtitle": parsed.subtitle]
        }
    }
}
