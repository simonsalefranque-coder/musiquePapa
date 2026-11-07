import AppKit

// Original geometric guitar icon, drawn with native vector paths.
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 4096, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
NSColor(calibratedRed: 0.08, green: 0.22, blue: 0.43, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
let gradient = NSGradient(starting: NSColor(calibratedRed: 0.20, green: 0.48, blue: 0.76, alpha: 1), ending: NSColor(calibratedRed: 0.07, green: 0.21, blue: 0.42, alpha: 1))!
gradient.draw(in: NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)), angle: -65)
let transform = NSAffineTransform()
transform.translateX(by: 512, yBy: 512)
transform.rotate(byDegrees: -30)
transform.concat()
let cream = NSColor(calibratedRed: 0.98, green: 0.93, blue: 0.80, alpha: 1)
cream.setFill()
let body = NSBezierPath()
body.move(to: NSPoint(x: -48, y: 95))
body.curve(to: NSPoint(x: -172, y: 30), controlPoint1: NSPoint(x: -150, y: 135), controlPoint2: NSPoint(x: -220, y: 95))
body.curve(to: NSPoint(x: -160, y: -70), controlPoint1: NSPoint(x: -140, y: -15), controlPoint2: NSPoint(x: -120, y: -20))
body.curve(to: NSPoint(x: 0, y: -290), controlPoint1: NSPoint(x: -330, y: -245), controlPoint2: NSPoint(x: -140, y: -320))
body.curve(to: NSPoint(x: 160, y: -70), controlPoint1: NSPoint(x: 140, y: -320), controlPoint2: NSPoint(x: 330, y: -245))
body.curve(to: NSPoint(x: 172, y: 30), controlPoint1: NSPoint(x: 120, y: -20), controlPoint2: NSPoint(x: 140, y: -15))
body.curve(to: NSPoint(x: 48, y: 95), controlPoint1: NSPoint(x: 220, y: 95), controlPoint2: NSPoint(x: 150, y: 135))
body.close(); body.fill()
NSBezierPath(roundedRect: NSRect(x: -36, y: 30, width: 72, height: 300), xRadius: 9, yRadius: 9).fill()
NSBezierPath(roundedRect: NSRect(x: -53, y: 290, width: 106, height: 130), xRadius: 22, yRadius: 22).fill()
NSColor(calibratedRed: 0.10, green: 0.28, blue: 0.48, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: -63, y: -95, width: 126, height: 126)).fill()
NSBezierPath(roundedRect: NSRect(x: -74, y: -205, width: 148, height: 24), xRadius: 7, yRadius: 7).fill()
NSColor(calibratedRed: 0.72, green: 0.64, blue: 0.48, alpha: 1).setStroke()
for x in stride(from: -20, through: 20, by: 8) {
 let string = NSBezierPath(); string.lineWidth = 2.5; string.move(to: NSPoint(x: x, y: -190)); string.line(to: NSPoint(x: x, y: 382)); string.stroke()
}
NSGraphicsContext.restoreGraphicsState()
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
