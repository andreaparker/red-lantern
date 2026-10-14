import AppKit
import ServiceManagement

final class AppModel {
    var settings = Settings.load() {
        didSet { settings.save(); update() }
    }
    var pausedUntil: Date?
    var status = "Normal colors"
    var error: String?
    var loginEnabled = SMAppService.mainApp.status == .enabled
    var shortcutStatus = "Emergency restore: ⌃⌥⌘R"
    let engine = DisplayEngine()
    var showSettings: (() -> Void)?
    var changed: (() -> Void)?
    var dockChanged: ((Bool) -> Void)?
    var statusChanged: ((Bool) -> Void)?
    private var timer: Timer?
    private var wasFiltering = false
    private var lastDockPreference: Bool?
    private var sleeping = false

    var active: Bool {
        settings.enabled && !sleeping && pausedUntil == nil && Schedule.isActive(settings)
    }

    func start() { update() }

    func tick() {
        if let pause = pausedUntil, pause <= Date() { pausedUntil = nil }
        update()
    }

    func update() {
        let gains = ColorCurve.gains(temperature: settings.temperature).scaled(Float(settings.brightness))
        let filtering = active && gains != .neutral
        if filtering { engine.transition(to: gains) }
        else if wasFiltering { engine.restore() }
        notifyState(filtering)
        updateStatus()
        error = engine.failure
        reschedule()
        notifyViews()
    }

    private func notifyState(_ filtering: Bool) {
        if wasFiltering != filtering, let callback = statusChanged { callback(filtering) }
        wasFiltering = filtering
        if lastDockPreference == settings.showInDock { return }
        lastDockPreference = settings.showInDock
        if let callback = dockChanged { callback(settings.showInDock) }
    }

    private func updateStatus() {
        if let pause = pausedUntil {
            status = "Paused until \(pause.formatted(date: .omitted, time: .shortened))"
            return
        }
        if active {
            status = wasFiltering ? "Filtering connected displays" : "Daylight · original colors"
            return
        }
        status = settings.enabled ? "Waiting for your schedule" : "Normal colors"
    }

    private func reschedule() {
        timer?.invalidate()
        timer = nil
        guard settings.enabled, !sleeping else { return }
        guard let next = pausedUntil ?? Schedule.nextEvent(settings, after: Date()) else { return }
        let pending = Timer(fire: next, interval: 0, repeats: false) { [weak self] _ in self?.tick() }
        pending.tolerance = 2
        RunLoop.main.add(pending, forMode: .common)
        timer = pending
    }

    private func notifyViews() { if let callback = changed { callback() } }

    func displaysChanged() {
        if wasFiltering { engine.refresh(); error = engine.failure }
        notifyViews()
    }

    func choose(_ preset: Preset) {
        var next = settings
        next.temperature = preset.temperature
        next.brightness = preset.brightness
        next.enabled = true
        pausedUntil = nil
        settings = next
    }

    func toggle() { pausedUntil = nil; settings.enabled.toggle() }
    func pause() { pausedUntil = Date().addingTimeInterval(15 * 60); update() }
    func resume() { pausedUntil = nil; update() }
    func reset() { pausedUntil = nil; settings.enabled = false }
    func sleep() { sleeping = true; update() }
    func wake() { sleeping = false; tick() }

    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval {
                error = "Allow Red Lantern in System Settings → General → Login Items."
            }
        } catch { self.error = "Login setting: \(error.localizedDescription)" }
        notifyViews()
    }
}
