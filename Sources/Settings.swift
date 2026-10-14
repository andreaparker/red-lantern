import Foundation

struct RGB: Equatable {
    var red: Float
    var green: Float
    var blue: Float

    func scaled(_ amount: Float) -> RGB {
        RGB(red: red * amount, green: green * amount, blue: blue * amount)
    }

    func blended(toward target: RGB, fraction: Float) -> RGB {
        RGB(red: red + (target.red - red) * fraction,
            green: green + (target.green - green) * fraction,
            blue: blue + (target.blue - blue) * fraction)
    }

    static let neutral = RGB(red: 1, green: 1, blue: 1)
}

struct Preset: Identifiable {
    let name: String
    let temperature: Double
    let brightness: Double
    var id: String { name }

    static let all: [Preset] = [
        Preset(name: "Daylight", temperature: 6500, brightness: 1),
        Preset(name: "Soft", temperature: 4500, brightness: 1),
        Preset(name: "Evening", temperature: 3400, brightness: 0.95),
        Preset(name: "Candle", temperature: 2700, brightness: 0.9),
        Preset(name: "Amber", temperature: 2000, brightness: 0.85),
        Preset(name: "Ember", temperature: 1500, brightness: 0.8),
        Preset(name: "Ruby", temperature: 1000, brightness: 0.75),
        Preset(name: "Deep red", temperature: 500, brightness: 0.7)
    ]
}

enum ColorCurve {
    // Visual warmth anchors; labels are approximate, not calibrated blackbody spectra.
    static let anchors: [(Double, RGB)] = [
        (500, RGB(red: 1, green: 0, blue: 0)),
        (1000, RGB(red: 1, green: 0.04, blue: 0)),
        (1500, RGB(red: 1, green: 0.12, blue: 0.005)),
        (2000, RGB(red: 1, green: 0.26, blue: 0.04)),
        (2700, RGB(red: 1, green: 0.42, blue: 0.13)),
        (3400, RGB(red: 1, green: 0.58, blue: 0.26)),
        (4500, RGB(red: 1, green: 0.75, blue: 0.5)),
        (6500, .neutral)
    ]

    static func gains(temperature: Double) -> RGB {
        let value = min(6500, max(500, temperature))
        let index = anchors.firstIndex { $0.0 >= value } ?? anchors.count - 1
        guard index > 0 else { return anchors[0].1 }
        let lower = anchors[index - 1]
        let upper = anchors[index]
        let fraction = Float((value - lower.0) / (upper.0 - lower.0))
        return lower.1.blended(toward: upper.1, fraction: fraction)
    }
}

enum ScheduleMode: String, Codable, CaseIterable {
    case manual = "Manual"
    case clock = "Clock"
    case sun = "Sunset"
}

struct Settings: Codable {
    var enabled = false
    var temperature = 1500.0
    var brightness = 0.8
    var schedule = ScheduleMode.manual
    var startMinute = 20 * 60
    var endMinute = 7 * 60
    var latitude = 0.0
    var longitude = 0.0
    var locationSet = false
    var showInDock = true

    static func load() -> Settings {
        guard let data = UserDefaults.standard.data(forKey: "settings"),
              let decoded = try? JSONDecoder().decode(Settings.self, from: data)
        else { return Settings() }
        return decoded.validated()
    }

    func validated() -> Settings {
        var result = self
        result.temperature = min(6500, max(500, temperature))
        result.brightness = min(1, max(0.15, brightness))
        result.startMinute = min(1439, max(0, startMinute))
        result.endMinute = min(1439, max(0, endMinute))
        result.latitude = min(90, max(-90, latitude))
        result.longitude = min(180, max(-180, longitude))
        return result
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: "settings")
    }
}
