import AppKit

let target = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: target, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    let scale = CGFloat(size) / 1024
    context.scaleBy(x: scale, y: scale)
    let rect = NSRect(x: 55, y: 55, width: 914, height: 914)
    let background = NSBezierPath(roundedRect: rect, xRadius: 208, yRadius: 208)
    NSGradient(starting: NSColor(srgbRed: 0.16, green: 0.23, blue: 0.36, alpha: 1),
               ending: NSColor(srgbRed: 0.07, green: 0.11, blue: 0.20, alpha: 1))!.draw(in: background, angle: -60)
    let pulse = NSBezierPath()
    pulse.move(to: NSPoint(x: 190, y: 500))
    for point in [NSPoint(x: 345, y: 500), NSPoint(x: 418, y: 690), NSPoint(x: 530, y: 300), NSPoint(x: 635, y: 580), NSPoint(x: 692, y: 500), NSPoint(x: 832, y: 500)] { pulse.line(to: point) }
    pulse.lineWidth = 59
    pulse.lineJoinStyle = .round
    pulse.lineCapStyle = .round
    NSColor(srgbRed: 0.46, green: 0.68, blue: 1, alpha: 1).setStroke()
    pulse.stroke()
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Unable to render icon") }
    let names: [String]
    switch size {
    case 16: names = ["icon_16x16.png"]
    case 32: names = ["icon_16x16@2x.png", "icon_32x32.png"]
    case 64: names = ["icon_32x32@2x.png"]
    case 128: names = ["icon_128x128.png"]
    case 256: names = ["icon_128x128@2x.png", "icon_256x256.png"]
    case 512: names = ["icon_256x256@2x.png", "icon_512x512.png"]
    default: names = ["icon_512x512@2x.png"]
    }
    for name in names { try png.write(to: URL(fileURLWithPath: target).appendingPathComponent(name)) }
}

// Pack standard PNG-backed ICNS chunks directly; no iconutil/CoreUI service is needed.
func chunk(_ type: String, _ payload: Data) -> Data {
    var data = Data(type.utf8)
    var length = UInt32(payload.count + 8).bigEndian
    withUnsafeBytes(of: &length) { data.append(contentsOf: $0) }
    data.append(payload)
    return data
}
var payload = Data()
for (type, name) in [("icp4", "icon_16x16.png"), ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"), ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"), ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png"), ("ic11", "icon_16x16@2x.png"),
    ("ic12", "icon_32x32@2x.png"), ("ic13", "icon_128x128@2x.png"),
    ("ic14", "icon_256x256@2x.png")] {
    let png = try Data(contentsOf: URL(fileURLWithPath: target).appendingPathComponent(name))
    payload.append(chunk(type, png))
}
try chunk("icns", payload).write(to: URL(fileURLWithPath: target).deletingPathExtension().appendingPathExtension("icns"))
