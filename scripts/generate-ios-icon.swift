import AppKit
let output = CommandLine.arguments[1]
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let background = NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024))
NSGradient(starting: NSColor(srgbRed: 0.16, green: 0.23, blue: 0.36, alpha: 1),
    ending: NSColor(srgbRed: 0.07, green: 0.11, blue: 0.20, alpha: 1))!.draw(in: background, angle: -60)
let pulse = NSBezierPath()
pulse.move(to: NSPoint(x: 170, y: 500))
for point in [NSPoint(x: 335, y: 500), NSPoint(x: 415, y: 700), NSPoint(x: 530, y: 295), NSPoint(x: 635, y: 585), NSPoint(x: 695, y: 500), NSPoint(x: 852, y: 500)] { pulse.line(to: point) }
pulse.lineWidth = 58; pulse.lineJoinStyle = .round; pulse.lineCapStyle = .round
NSColor(srgbRed: 0.46, green: 0.68, blue: 1, alpha: 1).setStroke(); pulse.stroke()
NSGraphicsContext.restoreGraphicsState()
// Draw through a supported RGBA AppKit context, then flatten to an opaque RGB image.
let flat = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 4096,
    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
flat.setFillColor(CGColor(red: 0.07, green: 0.11, blue: 0.20, alpha: 1))
flat.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
flat.draw(bitmap.cgImage!, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
let opaque = NSBitmapImageRep(cgImage: flat.makeImage()!)
precondition(!opaque.hasAlpha)
try opaque.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
