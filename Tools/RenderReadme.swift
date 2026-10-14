import AppKit

func previewModel() -> AppModel {
    let model = AppModel()
    // Sleep suppresses display writes; this renders the real controls off-screen.
    model.sleep()
    var settings = Settings()
    settings.enabled = true
    settings.temperature = 1500
    settings.brightness = 0.8
    model.settings = settings
    model.status = "Filtering connected displays"
    return model
}

func previewWindow(_ controls: ControlsView) -> NSWindow {
    let size = NSSize(width: 360, height: controls.fittingSize.height)
    controls.setFrameSize(size)
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                          styleMask: .borderless, backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: .darkAqua)
    window.contentView = controls
    window.displayIfNeeded()
    return window
}

func writePreview(_ view: NSView, to destination: URL) throws {
    view.layoutSubtreeIfNeeded()
    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
        throw CocoaError(.fileWriteUnknown)
    }
    view.cacheDisplay(in: view.bounds, to: bitmap)
    guard let converted = bitmap.converting(to: .sRGB, renderingIntent: .default),
          let png = converted.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try cleanPNG(png).write(to: destination)
}

func cleanPNG(_ png: Data) throws -> Data {
    var result = Data(png.prefix(8))
    var offset = 8
    let allowed = ["IHDR", "PLTE", "IDAT", "IEND", "tRNS", "iCCP", "sRGB", "gAMA", "cHRM"]
    while offset + 12 <= png.count {
        let length = png[offset..<(offset + 4)].reduce(0) { ($0 << 8) | Int($1) }
        let end = offset + length + 12
        guard end <= png.count else { throw CocoaError(.fileWriteUnknown) }
        let kind = String(decoding: png[(offset + 4)..<(offset + 8)], as: UTF8.self)
        if allowed.contains(kind) { result.append(png[offset..<end]) }
        offset = end
    }
    return result
}

let application = NSApplication.shared
application.setActivationPolicy(.prohibited)
let controls = ControlsView(model: previewModel(), compact: true)
let window = previewWindow(controls)
let destination = URL(fileURLWithPath: CommandLine.arguments[1])
try withExtendedLifetime(window) { try writePreview(controls, to: destination) }
