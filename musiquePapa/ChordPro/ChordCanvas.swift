import UIKit

/// Measures and paints chords/lyrics from the same origin, including after a font-size change.
final class ChordCanvas: UIView {
    struct Item {
        var text: String
        var origin: CGPoint
        var font: UIFont
        var color: UIColor
        var isChord = false
        var bounds: CGRect { CGRect(origin: origin, size: (text as NSString).size(withAttributes: [.font: font])) }
    }
    var onChordTap: ((String, CGRect) -> Void)?
    var song = ChordSong()
    var fontSize: CGFloat = 24
    var transpose = 0
    var displayKey: MusicalKey?
    var chordColor = ChordColor.blueDefault
    private(set) var rowStarts: [CGFloat] = []
    private(set) var lineOrigins: [CGFloat] = []
    private(set) var items: [Item] = []
    private var chorusRects: [CGRect] = []
    private(set) var measuredSize = CGSize.zero

    override init(frame: CGRect) {
        super.init(frame: frame); backgroundColor = .systemBackground; isOpaque = true; contentMode = .redraw
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: ChordCanvas, _: UITraitCollection) in view.setNeedsDisplay() }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @discardableResult
    func rebuild(width: CGFloat) -> CGSize {
        items.removeAll(); chorusRects.removeAll(); lineOrigins.removeAll(); rowStarts.removeAll()
        let margin: CGFloat = 28
        let available = max(120, width - 2 * margin)
        let lyricFont = UIFont.systemFont(ofSize: fontSize)
        let chordFont = UIFont.monospacedSystemFont(ofSize: fontSize * 0.88, weight: .bold)
        let rowHeight = ceil(lyricFont.lineHeight + chordFont.lineHeight + 8)
        var y: CGFloat = 24
        var maxWidth = width
        func measure(_ text: String, _ font: UIFont) -> CGFloat { ceil((text as NSString).size(withAttributes: [.font: font]).width) }
        func add(_ text: String, x: CGFloat, y: CGFloat, font: UIFont, color: UIColor, isChord: Bool = false) {
            items.append(Item(text: text, origin: CGPoint(x: x, y: y), font: font, color: color, isChord: isChord))
        }
        for line in song.lines {
            lineOrigins.append(y); rowStarts.append(y)
            let startY = y
            switch line.kind {
            case .blank: y += fontSize * 0.8
            case .tab:
                let font = UIFont.monospacedSystemFont(ofSize: fontSize * 0.85, weight: .regular)
                // Expand tabs consistently; never reflow tablature strings.
                let text = line.text.replacingOccurrences(of: "\t", with: "    ")
                add(text, x: margin, y: y, font: font, color: .label)
                maxWidth = max(maxWidth, measure(text, font) + 2 * margin)
                y += font.lineHeight + 3
            case .comment, .heading:
                let font = UIFont.systemFont(ofSize: fontSize * (line.kind == .heading ? 0.8 : 0.85), weight: line.kind == .heading ? .bold : .regular)
                var x: CGFloat = 0
                for word in words(line.text) {
                    let w = measure(word, font)
                    if x + w > available, x > 0 { x = 0; y += font.lineHeight + 4; rowStarts.append(y) }
                    add(word, x: margin + x, y: y, font: font, color: line.kind == .heading ? .systemBlue : .secondaryLabel)
                    x += w; maxWidth = max(maxWidth, margin + x + margin)
                }
                y += font.lineHeight + 14
            case .lyrics:
                var x: CGFloat = 0
                let hasChords = line.segments.contains { $0.chord != nil }
                let lyricY: CGFloat = hasChords ? chordFont.lineHeight + 2 : 0
                let height = hasChords ? rowHeight : lyricFont.lineHeight + 8
                for segment in line.segments {
                    var chord = segment.chord.map { value in
                        displayKey.map { Transposer.transpose(value, by: transpose, in: $0) }
                            ?? Transposer.transpose(value, by: transpose, preferFlats: song.key.contains("b"))
                    }
                    var units = words(segment.lyric)
                    if units.isEmpty { units = [""] }
                    for unit in units {
                        // Break a very long word into graphemes so zoom stays readable.
                        var pieces = [unit]
                        if measure(unit, lyricFont) > available {
                            pieces = []; var piece = ""
                            for char in unit {
                                if measure(piece + String(char), lyricFont) > available, !piece.isEmpty { pieces.append(piece); piece = "" }
                                piece.append(char)
                            }
                            if !piece.isEmpty { pieces.append(piece) }
                        }
                        for piece in pieces {
                            let lyricWidth = measure(piece, lyricFont)
                            let chordWidth = chord.map { measure($0, chordFont) + 8 } ?? 0
                            let unitWidth = max(lyricWidth, chordWidth)
                            if x + unitWidth > available, x > 0 { x = 0; y += height; rowStarts.append(y) }
                            if let value = chord { add(value, x: margin + x, y: y, font: chordFont, color: chordColor.readableUIColor, isChord: true) }
                            add(piece, x: margin + x, y: y + lyricY, font: lyricFont, color: .label)
                            x += unitWidth; chord = nil
                            maxWidth = max(maxWidth, margin + x + margin)
                        }
                    }
                }
                y += height
            }
            if line.chorus { chorusRects.append(CGRect(x: 14, y: startY - 2, width: width - 28, height: max(0, y - startY))) }
        }
        measuredSize = CGSize(width: maxWidth, height: y + 60)
        frame.size = measuredSize
        accessibilityElements = items.filter(\.isChord).map { item in
            let element = ChordAccessibilityElement(accessibilityContainer: self)
            element.accessibilityLabel = "Accord " + item.text; element.accessibilityTraits = .button
            element.accessibilityFrameInContainerSpace = item.bounds.insetBy(dx: -4, dy: -3)
            element.activate = { [weak self] in self?.onChordTap?(item.text, item.bounds) }
            return element
        }
        setNeedsDisplay()
        return measuredSize
    }
    func chord(at point: CGPoint) -> Item? { items.first { $0.isChord && $0.bounds.insetBy(dx: -5, dy: -4).contains(point) } }
    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended, let item = chord(at: gesture.location(in: self)) else { return }
        onChordTap?(item.text, item.bounds)
    }
    private func words(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        var result: [String] = []; var current = ""; var wasSpace = false
        for character in text {
            if wasSpace && !character.isWhitespace { result.append(current); current = "" }
            current.append(character); wasSpace = character.isWhitespace
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
    func anchor(at y: CGFloat) -> (line: Int, fraction: CGFloat) {
        guard !lineOrigins.isEmpty else { return (0, 0) }
        let index = lineOrigins.lastIndex { $0 <= y } ?? 0
        let end = index + 1 < lineOrigins.count ? lineOrigins[index + 1] : measuredSize.height
        return (index, (y - lineOrigins[index]) / max(1, end - lineOrigins[index]))
    }
    func offset(for anchor: (line: Int, fraction: CGFloat)) -> CGFloat {
        guard lineOrigins.indices.contains(anchor.line) else { return 0 }
        let start = lineOrigins[anchor.line]
        let end = anchor.line + 1 < lineOrigins.count ? lineOrigins[anchor.line + 1] : measuredSize.height
        return start + (end - start) * anchor.fraction
    }
    override func draw(_ rect: CGRect) {
        UIColor.systemBlue.withAlphaComponent(0.055).setFill()
        for area in chorusRects where area.intersects(rect) { UIBezierPath(roundedRect: area, cornerRadius: 3).fill() }
        for item in items where item.origin.y + item.font.lineHeight >= rect.minY && item.origin.y < rect.maxY {
            (item.text as NSString).draw(at: item.origin, withAttributes: [.font: item.font, .foregroundColor: item.color])
        }
    }
}

private final class ChordAccessibilityElement: UIAccessibilityElement {
    var activate: (() -> Void)?
    override func accessibilityActivate() -> Bool { activate?(); return activate != nil }
}
