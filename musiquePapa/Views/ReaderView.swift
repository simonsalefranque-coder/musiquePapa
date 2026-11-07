import SwiftUI

struct ReaderView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var editor: EditorCoordinator
    @Environment(\.scenePhase) private var scenePhase
    let song: Song
    let url: URL
    @Binding var stage: Bool
    let previous: (() -> Void)?
    let next: (() -> Void)?
    @StateObject private var session = ReaderSession()
    @State private var controlsVisible = true
    @State private var showTonality = false
    @State private var showColor = false
    @State private var showExport = false
    @State private var showConversion = false
    var body: some View {
        VStack(spacing: 0) {
            if !stage {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.title).font(.title2.bold()).lineLimit(1)
                        if !session.metadata.isEmpty { Text(session.metadata).font(.subheadline).foregroundStyle(.secondary).lineLimit(2) }
                    }
                    Spacer()
                    Menu {
                        Button("Imprimer / Exporter en PDF", systemImage: "printer") { session.controller?.setPlaying(false); showExport = true }.accessibilityIdentifier("exportPDF")
                        if song.format == .pdf { Button("Convertir en ChordPro", systemImage: "text.badge.plus") { session.controller?.setPlaying(false); showConversion = true } }
                    } label: { Label("Outils", systemImage: "ellipsis.circle") }.accessibilityIdentifier("readerTools")
                    if song.format == .chordPro {
                        Button("Modifier", systemImage: "square.and.pencil") {
                            session.controller?.setPlaying(false); session.save(); editor.open(song.id)
                        }.buttonStyle(.bordered).accessibilityIdentifier("editChordSong")
                    }
                    Button { library.updateSong(song.id) { $0.favorite.toggle() } } label: {
                        Image(systemName: (library.song(song.id)?.favorite ?? false) ? "star.fill" : "star").font(.title2).frame(width: 48, height: 48)
                    }.accessibilityLabel("Favori")
                }.padding(.horizontal, 24).padding(.vertical, 12)
                Divider()
            }
            ZStack(alignment: .topTrailing) {
                if let error = session.error {
                    ContentUnavailableView("Lecture impossible", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    ScoreReader(song: song, url: url, session: session, resume: library.settings.resumePosition, settings: library.settings)
                        .accessibilityIdentifier("scoreReader")
                }
                if stage {
                    HStack {
                        Button { controlsVisible.toggle() } label: { Image(systemName: controlsVisible ? "slider.horizontal.3" : "play.rectangle").frame(width: 44, height: 44) }.accessibilityLabel("Afficher ou masquer les commandes")
                        Button { stage = false; controlsVisible = true } label: { Image(systemName: "arrow.down.right.and.arrow.up.left").frame(width: 44, height: 44) }.accessibilityLabel("Quitter le mode scène")
                    }.buttonStyle(.bordered).background(.regularMaterial, in: Capsule()).padding(12)
                }
            }
            if controlsVisible {
                VStack(spacing: 10) {
                    ProgressView(value: session.progress).accessibilityLabel("Progression").accessibilityValue("\(Int(session.progress * 100)) pour cent")
                    HStack(spacing: 18) {
                        Button(action: { session.save(); previous?() }) { Image(systemName: "backward.end.fill") }.disabled(previous == nil).accessibilityLabel("Chanson précédente")
                        Button(action: session.beginning) { Image(systemName: "backward.end.alt") }.accessibilityLabel("Retour au début")
                        Button(action: session.playPause) { Label(session.playing ? "Pause" : "Lecture", systemImage: session.playing ? "pause.fill" : "play.fill").frame(minWidth: 105) }
                            .buttonStyle(.borderedProminent).accessibilityIdentifier("playPause")
                        Button(action: session.stop) { Image(systemName: "stop.fill") }.accessibilityLabel("Arrêt").accessibilityIdentifier("stop")
                        Button(action: { session.save(); next?() }) { Image(systemName: "forward.end.fill") }.disabled(next == nil).accessibilityLabel("Chanson suivante")
                        Spacer(minLength: 0)
                        Text("\(Int(session.progress * 100)) %").monospacedDigit().foregroundStyle(.secondary).accessibilityIdentifier("progressLabel")
                        if !stage { Button { stage = true } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }.accessibilityLabel("Mode scène") }
                    }.font(.title3).buttonStyle(.bordered).controlSize(.large)
                    HStack(spacing: 12) {
                        Image(systemName: "tortoise").accessibilityHidden(true)
                        Slider(value: Binding(get: { session.speed }, set: { session.setSpeed($0) }), in: 1...10, step: 0.1).accessibilityLabel("Vitesse de défilement")
                        Menu {
                            Button("Rétablir la vitesse globale (\(library.settings.defaultSpeed, specifier: "%.1f"))", action: session.resetSpeed)
                            Text(session.preferences.speed == nil ? "Vitesse globale" : "Vitesse propre à cette partition")
                        } label: { Text(String(format: "%.1f", session.speed)).monospacedDigit().frame(width: 38) }.accessibilityLabel("Réglage de vitesse").accessibilityIdentifier("speedPreference")
                        Image(systemName: "hare").accessibilityHidden(true)
                        Divider().frame(height: 28)
                        Button(song.format == .pdf ? "−" : "A−") { session.zoom(1 / 1.15) }.accessibilityLabel("Réduire").accessibilityIdentifier("zoomOut")
                        Text(session.zoomLabel).monospacedDigit().frame(minWidth: 55).accessibilityIdentifier("zoomLabel")
                        Button(song.format == .pdf ? "+" : "A+") { session.zoom(1.15) }.accessibilityLabel("Agrandir").accessibilityIdentifier("zoomIn")
                        if song.format == .pdf {
                            Menu { Button("Ajuster à la largeur", action: session.fitWidth); Button("Ajuster à la page", action: session.fitPage) } label: { Image(systemName: "arrow.up.left.and.down.right.magnifyingglass") }.accessibilityLabel("Ajuster le PDF")
                        } else {
                            Button(session.preferences.displayKey?.symbol ?? "Tonalité") { showTonality = true }.accessibilityIdentifier("tonalityButton")
                            Button { showColor = true } label: { Image(systemName: "paintpalette") }.accessibilityLabel("Couleur des accords")
                        }
                    }.buttonStyle(.bordered).controlSize(.large)
                }.padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 12).background(.bar)
                    .disabled(!session.ready)
            }
        }
        .navigationBarHidden(true)
        .toolbar(stage ? .hidden : .visible, for: .tabBar)
        .fullScreenCover(isPresented: $showConversion) { PDFConversionView(url: url, title: song.title).environmentObject(library) }
        .sheet(isPresented: $showExport) { PDFExportView(song: song, url: url, preferences: session.preferences, color: library.settings.chordColor ?? .blueDefault) }
        .sheet(isPresented: $showTonality) { TonalityView(session: session) }
        .sheet(isPresented: $showColor) {
            NavigationStack {
                Form {
                    Section("Pour cette chanson") {
                        ChordColorControls(value: session.preferences.chordColor ?? library.settings.chordColor ?? .blueDefault, onChange: session.setChordColor)
                        Button("Rétablir la couleur par défaut") { session.setChordColor(nil) }
                    }
                }.navigationTitle("Couleur des accords")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Terminé") { showColor = false } } }
            }
        }
        .onAppear {
            session.onSave = { preferences in
                // A dismissed reader may still have a queued save after an editor commit.
                guard library.song(song.id)?.digest == song.digest else { return }
                library.updateSong(song.id) { $0.preferences = preferences }
            }
            session.onEnd = { if library.settings.autoAdvance { next?() } }
            updateIdleTimer()
        }
        .onChange(of: session.playing) { _, _ in updateIdleTimer() }
        .onChange(of: stage) { _, _ in updateIdleTimer() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { session.controller?.setPlaying(false); session.save(); UIApplication.shared.isIdleTimerDisabled = false } else { updateIdleTimer() } }
        .onDisappear { session.controller?.setPlaying(false); session.save(); UIApplication.shared.isIdleTimerDisabled = false; stage = false }
        .background {
            Group {
                Button("Lecture / Pause", action: session.playPause).keyboardShortcut(.space, modifiers: [])
                Button("Suivante") { session.save(); next?() }.keyboardShortcut(.rightArrow, modifiers: [])
                Button("Précédente") { session.save(); previous?() }.keyboardShortcut(.leftArrow, modifiers: [])
            }.hidden()
        }
    }
    private func updateIdleTimer() { UIApplication.shared.isIdleTimerDisabled = session.playing || stage }
}
