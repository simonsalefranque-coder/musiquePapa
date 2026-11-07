import SwiftUI
import UIKit

struct ChordColor: Codable, Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    static let blueDefault = ChordColor(red: 0, green: 0.32, blue: 0.85)
    static let presets: [(String, ChordColor)] = [
        ("Bleu", .blueDefault), ("Rouge", .init(red: 0.8, green: 0.08, blue: 0.12)),
        ("Vert", .init(red: 0.06, green: 0.48, blue: 0.2)), ("Orange", .init(red: 0.85, green: 0.32, blue: 0)),
        ("Violet", .init(red: 0.55, green: 0.15, blue: 0.75)), ("Noir", .init(red: 0, green: 0, blue: 0)), ("Blanc", .init(red: 1, green: 1, blue: 1))
    ]
    var color: Color { Color(red: red, green: green, blue: blue) }
    init(red: Double, green: Double, blue: Double) { self.red = red; self.green = green; self.blue = blue }
    init(_ color: Color) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(red: r, green: g, blue: b)
    }
    /// Preserve the hue while adapting lightness to a minimum 4.5:1 contrast.
    /// The stored choice is unchanged; black/white adapt when the theme changes.
    var readableUIColor: UIColor {
        UIColor { traits in
            let dark = traits.userInterfaceStyle == .dark
            let background: Double = dark ? 0 : 1
            func luminance(_ values: [Double]) -> Double {
                let v = values.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
                return v[0] * 0.2126 + v[1] * 0.7152 + v[2] * 0.0722
            }
            let original = [red, green, blue].map { min(1, max(0, $0)) }
            var values = original
            for step in 0...100 {
                let t = Double(step) / 100
                values = original.map { $0 * (1 - t) + (dark ? 1 : 0) * t }
                let l = luminance(values)
                if (max(l, background) + 0.05) / (min(l, background) + 0.05) >= 4.5 { break }
            }
            return UIColor(red: values[0], green: values[1], blue: values[2], alpha: 1)
        }
    }
}
