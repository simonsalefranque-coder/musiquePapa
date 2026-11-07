import UIKit

@MainActor
final class AutoScrollEngine: NSObject {
    weak var scrollView: UIScrollView?
    var isPlaying = false
    var speed: Double = 3
    var onEnd: (() -> Void)?
    var onSample: (() -> Void)?
    var isInteracting: (() -> Bool)?
    private var displayLink: CADisplayLink?
    private var lastTime: CFTimeInterval?
    private var lastSample: CFTimeInterval = 0
    private var preciseOffset: Double?
    private var lastAppliedOffset: CGFloat?
    private var proxy: DisplayLinkProxy?

    func attach(_ scrollView: UIScrollView) {
        self.scrollView = scrollView
        guard displayLink == nil else { return }
        let proxy = DisplayLinkProxy(); proxy.engine = self; self.proxy = proxy
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common); displayLink = link
    }
    func invalidate() { displayLink?.invalidate(); displayLink = nil; proxy = nil; lastTime = nil; isPlaying = false }
    func play() { lastTime = nil; preciseOffset = nil; lastAppliedOffset = nil; isPlaying = true }
    func pause() { isPlaying = false; lastTime = nil; preciseOffset = nil; lastAppliedOffset = nil }
    func beginning() {
        guard let scrollView else { return }
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: -scrollView.adjustedContentInset.top), animated: false)
        onSample?()
    }
    var minimum: CGFloat { -(scrollView?.adjustedContentInset.top ?? 0) }
    var maximum: CGFloat {
        guard let scrollView else { return 0 }
        return max(minimum, scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)
    }
    var progress: Double { ScrollMath.progress(offset: Double(scrollView?.contentOffset.y ?? 0), minimum: Double(minimum), maximum: Double(maximum)) }
    func restore(_ progress: Double) {
        guard let scrollView else { return }
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: minimum + (maximum - minimum) * min(1, max(0, progress))), animated: false)
    }
    func tick(_ timestamp: CFTimeInterval) {
        let elapsed = lastTime.map { timestamp - $0 } ?? 0
        lastTime = timestamp
        if isPlaying, let scrollView, !scrollView.isDragging, !scrollView.isDecelerating, !scrollView.isZooming, isInteracting?() != true {
            // UIScrollView rounds offsets to display pixels. Retain fractional displacement
            // independently, otherwise low speeds vary with the display refresh rate.
            if preciseOffset == nil || lastAppliedOffset != scrollView.contentOffset.y {
                preciseOffset = Double(scrollView.contentOffset.y)
            }
            let y = min(Double(maximum), (preciseOffset ?? 0) + ScrollMath.pointsPerSecond(speed: speed) * min(0.1, max(0, elapsed)))
            preciseOffset = y
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: y), animated: false)
            lastAppliedOffset = scrollView.contentOffset.y
            if y >= maximum - 0.1 { pause(); onEnd?() }
        }
        if timestamp - lastSample >= 0.2 { lastSample = timestamp; onSample?() }
    }
}
@MainActor
private final class DisplayLinkProxy: NSObject {
    weak var engine: AutoScrollEngine?
    @objc func tick(_ link: CADisplayLink) { engine?.tick(link.timestamp) }
}
