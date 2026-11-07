import Foundation

enum ScrollMath {
    static func pointsPerSecond(speed: Double) -> Double { 4 + min(10, max(1, speed)) * 7 }
    static func advance(offset: Double, maximum: Double, elapsed: Double, speed: Double) -> Double {
        min(maximum, max(0, offset + pointsPerSecond(speed: speed) * min(0.1, max(0, elapsed))))
    }
    static func progress(offset: Double, minimum: Double, maximum: Double) -> Double {
        guard maximum > minimum else { return 0 }
        return min(1, max(0, (offset - minimum) / (maximum - minimum)))
    }
}
