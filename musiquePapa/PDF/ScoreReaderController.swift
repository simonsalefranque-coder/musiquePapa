import SwiftUI
import PDFKit

struct ScoreReader: UIViewControllerRepresentable {
    let song: Song
    let url: URL
    let session: ReaderSession
    let resume: Bool
    var settings = AppSettings()
    func makeUIViewController(context: Context) -> ScoreReaderController { ScoreReaderController(song: song, url: url, session: session, resume: resume, settings: settings) }
    func updateUIViewController(_ controller: ScoreReaderController, context: Context) { controller.applySettings(settings) }
    static func dismantleUIViewController(_ controller: ScoreReaderController, coordinator: ()) { controller.shutdown() }
}

@MainActor
final class ScoreReaderController: UIViewController, UIGestureRecognizerDelegate, UIPopoverPresentationControllerDelegate {
    let song: Song
    let url: URL
    let session: ReaderSession
    let resume: Bool
    let engine = AutoScrollEngine()
    private(set) var pdfView: PDFView?
    private(set) var canvas: ChordCanvas?
    private var chordScroll: UIScrollView?
    private var preferences: ReaderPreferences
    private var previousSize = CGSize.zero
    private var initialized = false
    private var pinchStart: CGFloat = 24
    private var pdfPinchStart: CGFloat = 1
    private var pinching = false
    private var lastSaved = Date.distantPast
    private var observedScroll: UIScrollView?
    private var savedPreferences: ReaderPreferences?
    private var closed = false
    private var settings: AppSettings

    init(song: Song, url: URL, session: ReaderSession, resume: Bool, settings: AppSettings = AppSettings()) {
        self.song = song; self.url = url; self.session = session; self.resume = resume; self.preferences = song.preferences
        self.settings = settings
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        session.controller = self
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.closed else { return }
            self.publishPreferences()
            self.session.playing = false; self.session.error = nil
        }
        engine.speed = preferences.effectiveSpeed(settings)
        engine.onSample = { [weak self] in self?.sample() }
        engine.onEnd = { [weak self] in guard let self else { return }; self.setPlaying(false); self.save(); self.session.onEnd?() }
        engine.isInteracting = { [weak self] in self?.pinching == true }
        do {
            if song.format == .pdf {
                guard let document = PDFDocument(url: url), !document.isLocked, document.pageCount > 0 else { throw MusicError.message("Impossible de lire ce PDF : fichier absent, corrompu ou protégé.") }
                let pdf = PDFView(); pdfView = pdf
                pdf.displayMode = .singlePageContinuous; pdf.displayDirection = .vertical
                pdf.displaysPageBreaks = true; pdf.pageBreakMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
                pdf.autoScales = false; pdf.minScaleFactor = 0.1; pdf.maxScaleFactor = 8
                pdf.document = document; pdf.backgroundColor = .secondarySystemBackground
                embed(pdf)
                let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinchPDF(_:)))
                pinch.delegate = self; pdf.addGestureRecognizer(pinch)
                let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapPDF(_:)))
                doubleTap.numberOfTapsRequired = 2; doubleTap.delegate = self; pdf.addGestureRecognizer(doubleTap)
                let metadata = "\(document.pageCount) page(s) • PDF"
                DispatchQueue.main.async { [weak session] in session?.metadata = metadata }
            } else {
                let parsed = ChordProParser.parse(try ChordProParser.decode(Data(contentsOf: url)))
                let scroll = UIScrollView(); chordScroll = scroll
                scroll.alwaysBounceVertical = true; scroll.alwaysBounceHorizontal = false
                scroll.contentInsetAdjustmentBehavior = .never
                let canvas = ChordCanvas(); self.canvas = canvas
                canvas.song = parsed; canvas.fontSize = preferences.fontSize; canvas.transpose = preferences.interval(parsed.key)
                canvas.displayKey = preferences.displayKey
                canvas.chordColor = preferences.chordColor ?? settings.chordColor ?? .blueDefault
                canvas.onChordTap = { [weak self] symbol, rect in self?.showChord(symbol, rect: rect) }
                scroll.addSubview(canvas); embed(scroll)
                let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinchChord(_:))); pinch.delegate = self; scroll.addGestureRecognizer(pinch)
                connect(scroll)
            }
        } catch {
            let message = error.localizedDescription
            DispatchQueue.main.async { [weak session] in session?.error = message }
        }
    }
    func showChord(_ symbol: String, rect: CGRect) {
        guard presentedViewController == nil, let canvas else { return }
        setPlaying(false)
        let diagram = UIViewController()
        let hosting = UIHostingController(rootView: ChordDiagramView(symbol: symbol, capo: canvas.song.capo, close: { [weak self] in self?.dismiss(animated: true) }))
        diagram.addChild(hosting); diagram.view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([hosting.view.leadingAnchor.constraint(equalTo: diagram.view.leadingAnchor), hosting.view.trailingAnchor.constraint(equalTo: diagram.view.trailingAnchor), hosting.view.topAnchor.constraint(equalTo: diagram.view.topAnchor), hosting.view.bottomAnchor.constraint(equalTo: diagram.view.bottomAnchor)])
        hosting.didMove(toParent: diagram)
        diagram.modalPresentationStyle = .popover
        diagram.preferredContentSize = CGSize(width: 350, height: canvas.song.capo.isEmpty ? 590 : 680)
        diagram.popoverPresentationController?.sourceView = canvas
        diagram.popoverPresentationController?.sourceRect = rect
        diagram.popoverPresentationController?.permittedArrowDirections = [.up, .down]
        diagram.popoverPresentationController?.delegate = self
        present(diagram, animated: true)
    }
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle { .none }
    private func embed(_ child: UIView) {
        view.addSubview(child); child.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([child.leadingAnchor.constraint(equalTo: view.leadingAnchor), child.trailingAnchor.constraint(equalTo: view.trailingAnchor), child.topAnchor.constraint(equalTo: view.topAnchor), child.bottomAnchor.constraint(equalTo: view.bottomAnchor)])
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard view.bounds.width > 0, view.bounds.height > 0, session.error == nil else { return }
        let changed = previousSize != view.bounds.size
        if let canvas, let scroll = chordScroll, changed {
            let anchor = canvas.anchor(at: scroll.contentOffset.y)
            scroll.contentSize = canvas.rebuild(width: scroll.bounds.width)
            if initialized { scroll.contentOffset.y = min(engine.maximum, max(engine.minimum, canvas.offset(for: anchor))) }
        }
        if let pdf = pdfView {
            pdf.layoutIfNeeded()
            if let scroll = findScroll(in: pdf), scroll !== observedScroll { connect(scroll) }
            if !initialized {
                if preferences.pdfScale > 0 { pdf.scaleFactor = preferences.pdfScale }
                else { fitPDF(page: false) }
                pdf.layoutDocumentView(); pdf.layoutIfNeeded()
            }
            // autoScales stays off: changing pages/rotating never resets a chosen magnification.
        }
        previousSize = view.bounds.size
        if !initialized, engine.scrollView != nil {
            initialized = true
            engine.restore(resume ? preferences.progress : 0)
            DispatchQueue.main.async { [weak session] in session?.ready = true }
            sample()
        }
    }
    private func findScroll(in view: UIView) -> UIScrollView? {
        if let scroll = view as? UIScrollView { return scroll }
        for child in view.subviews { if let scroll = findScroll(in: child) { return scroll } }
        return nil
    }
    private func connect(_ scroll: UIScrollView) {
        observedScroll?.panGestureRecognizer.removeTarget(self, action: #selector(manualPan(_:)))
        observedScroll = scroll; engine.attach(scroll)
        // Handle PDF magnification through PDFView.scaleFactor. This keeps the
        // document vector-rendered and gives both pinch and buttons one anchor policy.
        if pdfView != nil { scroll.pinchGestureRecognizer?.isEnabled = false }
        scroll.panGestureRecognizer.addTarget(self, action: #selector(manualPan(_:)))
    }
    @objc private func manualPan(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began, !pinching, gesture.numberOfTouches < 2 { setPlaying(false) }
        if gesture.state == .ended { save() }
    }
    func setPlaying(_ playing: Bool) {
        guard initialized else { return }
        if playing { engine.play() } else { engine.pause() }
        session.playing = playing
        if !playing { save() }
    }
    func zoom(_ factor: Double) {
        if let pdf = pdfView {
            setPDFScale(pdf.scaleFactor * factor, focalPoint: CGPoint(x: pdf.bounds.midX, y: pdf.bounds.midY))
        } else { resizeChord(to: (canvas?.fontSize ?? 24) * factor, focalY: 0) }
        sample(); save()
    }
    private func setPDFScale(_ scale: CGFloat, focalPoint: CGPoint) {
        guard let pdf = pdfView else { return }
        let page = pdf.page(for: focalPoint, nearest: true)
        let anchor = page.map { pdf.convert(focalPoint, to: $0) }
        pdf.scaleFactor = min(pdf.maxScaleFactor, max(pdf.minScaleFactor, scale))
        pdf.layoutDocumentView(); pdf.layoutIfNeeded()
        if let page, let anchor, let scroll = engine.scrollView {
            let moved = pdf.convert(anchor, from: page)
            let x = scroll.contentOffset.x + moved.x - focalPoint.x
            let y = scroll.contentOffset.y + moved.y - focalPoint.y
            scroll.contentOffset = CGPoint(x: max(-scroll.adjustedContentInset.left, min(max(0, scroll.contentSize.width - scroll.bounds.width + scroll.adjustedContentInset.right), x)), y: min(engine.maximum, max(engine.minimum, y)))
        }
    }
    @objc private func pinchPDF(_ pinch: UIPinchGestureRecognizer) {
        guard let pdf = pdfView else { return }
        if pinch.state == .began { pdfPinchStart = pdf.scaleFactor; pinching = true }
        if pinch.state == .changed { setPDFScale(pdfPinchStart * pinch.scale, focalPoint: pinch.location(in: pdf)) }
        if pinch.state == .ended || pinch.state == .cancelled || pinch.state == .failed { pinching = false; sample(); save() }
    }
    @objc private func doubleTapPDF(_ tap: UITapGestureRecognizer) {
        guard let pdf = pdfView else { return }
        setPDFScale(pdf.scaleFactor * 1.5, focalPoint: tap.location(in: pdf)); sample(); save()
    }
    func fitPDF(page: Bool) {
        guard let pdf = pdfView, let current = pdf.currentPage ?? pdf.document?.page(at: 0) else { return }
        let bounds = current.bounds(for: pdf.displayBox)
        let width = max(1, pdf.bounds.width - 24) / max(1, bounds.width)
        let height = max(1, pdf.bounds.height - 24) / max(1, bounds.height)
        let factor = page ? min(width, height) : width
        if initialized { zoom(Double(factor / max(0.01, pdf.scaleFactor))) }
        else { pdf.scaleFactor = factor }
    }
    @objc private func pinchChord(_ pinch: UIPinchGestureRecognizer) {
        guard let canvas, let scroll = chordScroll else { return }
        if pinch.state == .began { pinchStart = canvas.fontSize; pinching = true }
        if pinch.state == .changed {
            let focalY = pinch.location(in: view).y
            resizeChord(to: pinchStart * pinch.scale, focalY: focalY)
            scroll.setNeedsLayout()
        }
        if pinch.state == .ended || pinch.state == .cancelled || pinch.state == .failed { pinching = false; sample(); save() }
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
    private func resizeChord(to size: CGFloat, focalY: CGFloat) {
        guard let canvas, let scroll = chordScroll else { return }
        let anchor = canvas.anchor(at: scroll.contentOffset.y + focalY)
        canvas.fontSize = min(64, max(12, size))
        scroll.contentSize = canvas.rebuild(width: scroll.bounds.width)
        scroll.contentOffset.y = min(engine.maximum, max(engine.minimum, canvas.offset(for: anchor) - focalY))
    }
    func setTranspose(_ value: Int) {
        preferences.displayKey = nil; preferences.transpose = value
        updateChordAppearance(); publishPreferences(); save()
    }
    func setKey(_ key: MusicalKey, original: Bool) {
        if original { preferences.originalKey = key; preferences.displayKey = nil; preferences.transpose = 0 }
        else { guard preferences.sourceKey(canvas?.song.key ?? "") != nil else { return }; preferences.displayKey = key; preferences.transpose = 0 }
        updateChordAppearance(); publishPreferences(); save()
    }
    func resetKey() {
        preferences.displayKey = nil; preferences.transpose = 0
        updateChordAppearance(); publishPreferences(); save()
    }
    func setChordColor(_ color: ChordColor?) {
        preferences.chordColor = color
        updateChordAppearance(); publishPreferences(); save()
    }
    func setSpeed(_ value: Double?) {
        preferences.speed = value.map { min(10, max(1, $0)) }
        engine.speed = preferences.effectiveSpeed(settings)
        publishPreferences(); save()
    }
    func applySettings(_ value: AppSettings) {
        let changed = settings.chordColor != value.chordColor
        let speedChanged = settings.defaultSpeed != value.defaultSpeed
        settings = value
        if changed { updateChordAppearance() }
        if speedChanged {
            engine.speed = preferences.effectiveSpeed(settings)
            DispatchQueue.main.async { [weak self] in self?.publishPreferences() }
        }
    }
    private func publishPreferences() {
        guard !closed else { return }
        session.preferences = preferences; session.parsedKey = canvas?.song.key ?? ""
        session.transpose = preferences.interval(session.parsedKey)
        session.speed = engine.speed
        if let parsed = canvas?.song {
            var parts = ["Origine : " + (preferences.sourceKey(parsed.key)?.symbol ?? "non renseignée")]
            if let display = preferences.displayKey { parts.append("Affichage : " + display.symbol) }
            else if preferences.transpose != 0 { parts.append("\(preferences.transpose > 0 ? "+" : "")\(preferences.transpose) demi-tons") }
            if !parsed.capo.isEmpty { parts.append("Capo : \(parsed.capo)") }
            if !parsed.tempo.isEmpty { parts.append("Tempo : \(parsed.tempo)") }
            if !parsed.subtitle.isEmpty { parts.append(parsed.subtitle) }
            if !parsed.unknownDirectives.isEmpty { parts.append("\(parsed.unknownDirectives.count) directive(s) non affichée(s)") }
            session.metadata = parts.joined(separator: " • ")
        }
    }
    private func updateChordAppearance() {
        canvas?.transpose = preferences.interval(canvas?.song.key ?? "")
        canvas?.displayKey = preferences.displayKey
        canvas?.chordColor = preferences.chordColor ?? settings.chordColor ?? .blueDefault
        resizeChord(to: canvas?.fontSize ?? 24, focalY: 0)
    }
    private func snapshot() -> ReaderPreferences {
        var value = preferences
        value.fontSize = canvas.map { Double($0.fontSize) } ?? value.fontSize
        value.pdfScale = pdfView.map { Double($0.scaleFactor) } ?? value.pdfScale
        value.progress = engine.progress
        return value
    }
    private func sample() {
        // Layout callbacks can occur inside a SwiftUI update. Publish on the next
        // main-loop turn so document layout never mutates SwiftUI state reentrantly.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.initialized, !self.closed else { return }
            let progress = self.engine.progress
            let zoom = self.canvas.map { "\(Int($0.fontSize.rounded())) pt" } ?? "\(Int((self.pdfView?.scaleFactor ?? 1) * 100)) %"
            if self.session.progress != progress { self.session.progress = progress }
            if self.session.zoomLabel != zoom { self.session.zoomLabel = zoom }
            if Date().timeIntervalSince(self.lastSaved) > 2 { self.save() }
        }
    }
    func save() {
        guard initialized, !closed else { return }
        let value = snapshot()
        if value != savedPreferences {
            let onSave = session.onSave
            DispatchQueue.main.async { onSave?(value) }
            savedPreferences = value
        }
        lastSaved = Date()
    }
    func shutdown() { guard !closed else { return }; save(); closed = true; engine.invalidate(); DispatchQueue.main.async { [weak session] in session?.playing = false }; observedScroll?.panGestureRecognizer.removeTarget(self, action: #selector(manualPan(_:))) }
}
