import AppKit

func drawBackground(_ context: CGContext) {
    let rect = CGRect(x: 60, y: 60, width: 904, height: 904)
    let shape = NSBezierPath(roundedRect: rect, xRadius: 210, yRadius: 210)
    let colors = [NSColor(red: 0.23, green: 0.045, blue: 0.07, alpha: 1), .black]
    NSGradient(colors: colors)?.draw(in: shape, angle: -90)
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.1).cgColor)
    context.setLineWidth(3)
    context.strokePath()
}

func drawSun(_ context: CGContext) {
    context.saveGState()
    context.setShadow(offset: .zero, blur: 100, color: NSColor.systemRed.cgColor)
    let sun = NSBezierPath(ovalIn: CGRect(x: 280, y: 335, width: 464, height: 464))
    let colors = [NSColor(red: 1, green: 0.68, blue: 0.25, alpha: 1), .systemRed]
    NSGradient(colors: colors)?.draw(in: sun, angle: -90)
    context.restoreGState()
    drawHorizon()
}

func drawHorizon() {
    NSColor(red: 0.10, green: 0.025, blue: 0.035, alpha: 1).setFill()
    NSBezierPath(rect: CGRect(x: 110, y: 120, width: 804, height: 370)).fill()
    let horizon = NSBezierPath(roundedRect: CGRect(x: 190, y: 478, width: 644, height: 15), xRadius: 7, yRadius: 7)
    NSColor(red: 1, green: 0.4, blue: 0.24, alpha: 1).setFill()
    horizon.fill()
}

func makeIcon(size: Int, path: String) {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    drawBackground(context)
    drawSun(context)
    NSGraphicsContext.restoreGraphicsState()
    try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let destination = CommandLine.arguments[1]
let iconset = destination + "/AppIcon.iconset"
try FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    makeIcon(size: size, path: iconset + "/icon_\(size)x\(size).png")
    makeIcon(size: size * 2, path: iconset + "/icon_\(size)x\(size)@2x.png")
}
let compiler = Process()
compiler.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
compiler.arguments = ["-c", "icns", iconset, "-o", destination + "/AppIcon.icns"]
try compiler.run()
compiler.waitUntilExit()
guard compiler.terminationStatus == 0 else { exit(1) }
try FileManager.default.removeItem(atPath: iconset)
