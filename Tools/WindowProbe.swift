import AppKit
import CoreGraphics

func frame(_ info: [String: Any], desktopTop: CGFloat) -> CGRect? {
    guard let dictionary = info[kCGWindowBounds as String] as? [String: Any],
          let cg = CGRect(dictionaryRepresentation: dictionary as CFDictionary) else { return nil }
    return CGRect(x: cg.minX, y: desktopTop - cg.maxY, width: cg.width, height: cg.height)
}

func inspect(_ info: [String: Any]) -> Bool {
    guard let top = NSScreen.screens.first?.frame.maxY,
          let bounds = frame(info, desktopTop: top) else { return false }
    let fits = NSScreen.screens.contains { $0.visibleFrame.contains(bounds) }
    print("window_layer=\(info[kCGWindowLayer as String] ?? -1) frame=\(bounds) fully_visible=\(fits)")
    return fits
}

let applications = NSRunningApplication.runningApplications(withBundleIdentifier: "local.redlantern.app")
let pids = applications.map { Int($0.processIdentifier) }
let windows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)
    as? [[String: Any]] ?? []
let panels = windows.filter {
    pids.contains($0[kCGWindowOwnerPID as String] as? Int ?? -1)
}.filter {
    guard let bounds = frame($0, desktopTop: NSScreen.screens.first?.frame.maxY ?? 0) else { return false }
    return bounds.width >= 300 && bounds.height >= 100
}
guard !panels.isEmpty else { print("No app panels allocated"); exit(1) }
let results = panels.map(inspect)
exit(results.allSatisfy { $0 } ? 0 : 1)
