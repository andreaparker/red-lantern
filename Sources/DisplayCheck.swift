import CoreGraphics
import Foundation

enum DisplayCheck {
    static func run() -> Int32 {
        let displays = DisplayEngine.displays()
        guard !displays.isEmpty else { print("FAIL: no online displays"); return 1 }
        let passed = displays.map(check)
        return passed.allSatisfy { $0 } ? 0 : 1
    }

    private static func check(_ display: CGDirectDisplayID) -> Bool {
        guard let original = GammaTable.read(display) else {
            print("FAIL: display \(display) cannot read gamma table")
            return false
        }
        defer { _ = original.write(to: display) }
        let changedCorrectly = checkTint(original, display: display)
        let redCorrectly = checkRed(original, display: display)
        let recovery = checkRecovery(original, display: display)
        _ = original.write(to: display)
        let restored = GammaTable.read(display).map { original.matches($0, gains: .neutral) } ?? false
        print("Display \(display): samples=\(original.red.count), tint=\(changedCorrectly), red=\(redCorrectly), recovery=\(recovery), restoration=\(restored)")
        return changedCorrectly && redCorrectly && recovery && restored
    }

    private static func checkTint(_ original: GammaTable, display: CGDirectDisplayID) -> Bool {
        let gains = RGB(red: 0.95, green: 0.8, blue: 0.7)
        guard original.write(to: display, gains: gains), let changed = GammaTable.read(display) else { return false }
        return original.matches(changed, gains: gains)
    }

    private static func checkRed(_ original: GammaTable, display: CGDirectDisplayID) -> Bool {
        let red = ColorCurve.gains(temperature: 500).scaled(0.7)
        guard original.write(to: display, gains: red), let changed = GammaTable.read(display) else { return false }
        return original.matches(changed, gains: red)
    }

    private static func checkRecovery(_ original: GammaTable, display: CGDirectDisplayID) -> Bool {
        guard let guardian = try? Guardian(tables: [display: original]) else { return false }
        _ = original.write(to: display, gains: RGB(red: 0.9, green: 0.75, blue: 0.6))
        guard guardian.simulateCrash(), let restored = GammaTable.read(display) else { return false }
        return original.matches(restored, gains: .neutral)
    }
}
