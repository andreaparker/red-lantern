import CoreGraphics
import Foundation

struct GammaTable: Codable {
    let red: [Float]
    let green: [Float]
    let blue: [Float]

    static func read(_ display: CGDirectDisplayID) -> GammaTable? {
        let capacity = max(256, CGDisplayGammaTableCapacity(display))
        guard capacity <= 65536 else { return nil }
        var red = [Float](repeating: 0, count: Int(capacity))
        var green = red
        var blue = red
        var count: UInt32 = 0
        let result = CGGetDisplayTransferByTable(display, capacity, &red, &green, &blue, &count)
        guard result == .success, count > 0 else { return nil }
        return GammaTable(red: Array(red.prefix(Int(count))),
                          green: Array(green.prefix(Int(count))),
                          blue: Array(blue.prefix(Int(count))))
    }

    func write(to display: CGDirectDisplayID, gains: RGB = .neutral) -> Bool {
        let r = red.map { $0 * gains.red }
        let g = green.map { $0 * gains.green }
        let b = blue.map { $0 * gains.blue }
        return CGSetDisplayTransferByTable(display, UInt32(red.count), r, g, b) == .success
    }

    func matches(_ other: GammaTable, gains: RGB) -> Bool {
        let differences = [zip(red, other.red).map { abs($0 * gains.red - $1) },
                           zip(green, other.green).map { abs($0 * gains.green - $1) },
                           zip(blue, other.blue).map { abs($0 * gains.blue - $1) }]
        guard red.count == other.red.count else { return false }
        return differences.flatMap { $0 }.allSatisfy { $0 < 0.025 }
    }
}

final class DisplayEngine {
    private var originals: [CGDirectDisplayID: GammaTable] = [:]
    private var target = RGB.neutral
    private var guardian: Guardian?
    private(set) var failure: String?
    var displayCount: Int { originals.count }

    static func displays() -> [CGDirectDisplayID] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 32)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(32, &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count)))
    }

    func capture() {
        let ids = Self.displays()
        let previous = Set(originals.keys)
        originals = originals.filter { ids.contains($0.key) }
        for id in ids where originals[id] == nil {
            originals[id] = GammaTable.read(id)
        }
        updateCaptureStatus(total: ids.count)
        if previous != Set(originals.keys) { updateGuardian() }
    }

    private func updateCaptureStatus(total: Int) {
        failure = nil
        if originals.count < total { failure = "Some displays do not expose a usable color table." }
        if originals.isEmpty { failure = "This display does not expose a usable color table." }
    }

    func transition(to gains: RGB) {
        guard gains != target else { return }
        capture()
        target = gains
        apply(gains)
    }

    private func apply(_ gains: RGB) {
        guard !originals.isEmpty else { return }
        let failures = originals.filter { !$0.value.write(to: $0.key, gains: gains) }
        if !failures.isEmpty { failure = "macOS rejected the color adjustment on \(failures.count) display(s)." }
    }

    func refresh() {
        capture()
        apply(target)
    }

    func restore() {
        for (id, table) in originals { _ = table.write(to: id) }
        originals.removeAll()
        target = .neutral
        guardian?.stop()
        guardian = nil
        failure = nil
    }

    private func updateGuardian() {
        guardian?.stop()
        guardian = nil
        guard !originals.isEmpty else { return }
        do {
            guardian = try Guardian(tables: originals)
        } catch {
            failure = "Crash recovery could not start: \(error.localizedDescription)"
        }
    }
}
