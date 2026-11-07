import SwiftUI

struct ChordPreview: UIViewRepresentable {
    let song: ChordSong
    let preferences: ReaderPreferences
    let defaultColor: ChordColor
    func makeUIView(context: Context) -> PreviewScrollView { PreviewScrollView() }
    func updateUIView(_ view: PreviewScrollView, context: Context) {
        let color = preferences.chordColor ?? defaultColor
        guard view.canvas.song != song || view.canvas.fontSize != preferences.fontSize ||
                view.canvas.transpose != preferences.interval(song.key) || view.canvas.displayKey != preferences.displayKey || view.canvas.chordColor != color else { return }
        view.canvas.song = song; view.canvas.fontSize = preferences.fontSize
        view.canvas.transpose = preferences.interval(song.key); view.canvas.displayKey = preferences.displayKey
        view.canvas.chordColor = color; view.needsRebuild = true
        view.setNeedsLayout()
    }
}
final class PreviewScrollView: UIScrollView {
    let canvas = ChordCanvas()
    var needsRebuild = true
    private var previousWidth: CGFloat = 0
    override init(frame: CGRect) {
        super.init(frame: frame); addSubview(canvas); alwaysBounceVertical = true
        accessibilityIdentifier = "chordPreview"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, needsRebuild || previousWidth != bounds.width else { return }
        needsRebuild = false; previousWidth = bounds.width
        let anchor = canvas.anchor(at: contentOffset.y)
        let size = canvas.rebuild(width: bounds.width)
        if contentSize != size { contentSize = size; contentOffset.y = max(0, min(max(0, size.height - bounds.height), canvas.offset(for: anchor))) }
    }
}
