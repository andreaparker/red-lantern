import Foundation
import CoreGraphics

var checks = 0
func expect(_ condition: Bool, _ message: String) {
    checks += 1
    guard condition else { fatalError("FAIL: \(message)") }
}

func checkClock() {
    expect(Schedule.contains(minute: 1200, start: 1200, end: 420), "night includes start")
    expect(Schedule.contains(minute: 0, start: 1200, end: 420), "crosses midnight")
    expect(!Schedule.contains(minute: 420, start: 1200, end: 420), "excludes end")
    expect(!Schedule.contains(minute: 900, start: 1200, end: 420), "day outside night")
    expect(Schedule.contains(minute: 600, start: 500, end: 700), "same-day interval")
    expect(!Schedule.contains(minute: 600, start: 600, end: 600), "equal times are off")
}

func checkColors() {
    expect(ColorCurve.gains(temperature: 6500) == .neutral, "neutral preserves channels")
    expect(ColorCurve.gains(temperature: 500) == RGB(red: 1, green: 0, blue: 0), "red removes green and blue")
    expect(ColorCurve.gains(temperature: -500) == ColorCurve.gains(temperature: 500), "temperature clamp")
    let dimmed = RGB.neutral.scaled(0.5)
    expect(dimmed == RGB(red: 0.5, green: 0.5, blue: 0.5), "brightness scales all channels")
    let ramp = ColorCurve.gains(temperature: 3000)
    expect(ramp.green > 0.42 && ramp.green < 0.58, "smooth interpolation")
}

func checkSun() {
    var settings = Settings()
    settings.schedule = .sun
    settings.latitude = 37.7749
    settings.longitude = -122.4194
    settings.locationSet = true
    let formatter = ISO8601DateFormatter()
    let day = formatter.date(from: "2026-10-14T19:00:00Z")!
    let night = formatter.date(from: "2026-10-14T08:00:00Z")!
    expect(!Schedule.isActive(settings, at: day), "San Francisco noon is day")
    expect(Schedule.isActive(settings, at: night), "San Francisco 1 am is night")
    settings.locationSet = false
    expect(!Schedule.isActive(settings, at: night), "sun mode needs coordinates")
}

func checkPolarSun() {
    var settings = Settings()
    settings.schedule = .sun
    settings.locationSet = true
    settings.latitude = 89
    let formatter = ISO8601DateFormatter()
    let summer = formatter.date(from: "2026-06-21T00:00:00Z")!
    let winter = formatter.date(from: "2026-12-21T12:00:00Z")!
    expect(!Schedule.isActive(settings, at: summer), "polar daylight")
    expect(Schedule.isActive(settings, at: winter), "polar night")
}

func checkSettings() {
    var settings = Settings()
    settings.temperature = 10000
    settings.brightness = 0
    settings.latitude = -100
    settings.endMinute = 2000
    let checked = settings.validated()
    expect(checked.temperature == 6500, "restore clamps temperature")
    expect(checked.brightness == 0.15, "restore prevents black screen")
    expect(checked.latitude == -90, "coordinate range")
    expect(checked.endMinute == 1439, "clock range")
}

func checkPlacement() {
    let screen = CGRect(x: 0, y: 80, width: 1024, height: 650)
    let anchor = CGRect(x: 1010, y: 730, width: 22, height: 24)
    let menu = WindowPlacement.menu(anchor: anchor, size: CGSize(width: 360, height: 1200), screen: screen)
    expect(screen.contains(menu), "oversized menu stays below menu bar and above Dock")
    let leftScreen = CGRect(x: -1440, y: -200, width: 1440, height: 850)
    let moved = WindowPlacement.clamp(CGRect(x: 200, y: 2000, width: 360, height: 700), inside: leftScreen)
    expect(leftScreen.contains(moved), "secondary display handles negative coordinates")
}

func checkDockPlacement() {
    let screen = CGRect(x: 0, y: 80, width: 1024, height: 650)
    let frame = WindowPlacement.centered(size: CGSize(width: 360, height: 830), screen: screen)
    expect(screen.contains(frame), "Dock window fits a short display")
}

func checkNextEvent() {
    var settings = Settings()
    let now = ISO8601DateFormatter().date(from: "2026-10-14T19:00:00Z")!
    expect(Schedule.nextEvent(settings, after: now) == nil, "manual mode has no timer")
    settings.schedule = .clock
    let next = Schedule.nextEvent(settings, after: now)!
    expect(next > now && next.timeIntervalSince(now) <= 86400, "clock arms one future boundary")
    settings.endMinute = settings.startMinute
    expect(Schedule.nextEvent(settings, after: now) == nil, "equal clock times need no wakeups")
    settings.schedule = .sun
    expect(Schedule.nextEvent(settings, after: now) == nil, "unset solar location needs no timer")
}

func checkSolarEvent() {
    var settings = Settings()
    settings.schedule = .sun
    settings.locationSet = true
    settings.latitude = 37.7749
    settings.longitude = -122.4194
    let day = ISO8601DateFormatter().date(from: "2026-10-14T19:00:00Z")!
    let sunset = Schedule.nextEvent(settings, after: day)!
    expect(sunset.timeIntervalSince(day) < 43200, "solar mode schedules sunset directly")
    expect(!Schedule.isActive(settings, at: sunset.addingTimeInterval(-5)), "before computed sunset")
    expect(Schedule.isActive(settings, at: sunset.addingTimeInterval(5)), "after computed sunset")
}

checkClock()
checkColors()
expect(Preset.all.count == 8, "eight presets")
checkSun()
checkPolarSun()
checkSettings()
checkPlacement()
checkDockPlacement()
checkNextEvent()
checkSolarEvent()
print("PASS: \(checks) color, schedule, screen-placement and settings checks")
