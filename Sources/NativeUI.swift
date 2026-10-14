import AppKit

enum NativeUI {
    static let accent = NSColor(red: 1, green: 0.36, blue: 0.27, alpha: 1)

    static func label(_ text: String, size: CGFloat = 12) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: size)
        field.textColor = .labelColor
        field.preferredMaxLayoutWidth = 324
        return field
    }

    static func row(_ views: [NSView]) -> NSStackView {
        let row = NSStackView(views: views)
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        return row
    }

    static func button(_ title: String, target: AnyObject, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: target, action: action)
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 12)
        return button
    }

    static func assign(_ field: NSTextField, _ value: String) {
        if field.stringValue != value { field.stringValue = value }
    }

    static func add(_ view: NSView, to stack: NSStackView) {
        stack.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    static func document(_ view: NSView, width: CGFloat) -> NSScrollView {
        view.setFrameSize(NSSize(width: width, height: view.fittingSize.height))
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.documentView = view
        return scroll
    }
}

final class ControlsView: NSView {
    override var isFlipped: Bool { true }
    private let model: AppModel
    private let compact: Bool
    private let stack = NSStackView()
    private let status = NativeUI.label("")
    private let temperature = NativeUI.label("", size: 30)
    private let brightness = NativeUI.label("")
    private let warning = NativeUI.label("")
    private let enabled = NSButton(checkboxWithTitle: "Filter on", target: nil, action: nil)
    private let warmth = NSSlider(value: 1500, minValue: 500, maxValue: 6500, target: nil, action: nil)
    private let dimmer = NSSlider(value: 0.8, minValue: 0.15, maxValue: 1, target: nil, action: nil)
    private var pauseButton: NSButton!
    private var preferences: PreferencesView?

    private func configureLayout() {
        appearance = NSAppearance(named: .darkAqua)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.075, alpha: 1).cgColor
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18)
        ])
    }

    private func buildControls() {
        let title = NativeUI.label("☀  Red Lantern", size: 20)
        enabled.target = self
        enabled.action = #selector(toggle)
        NativeUI.add(NativeUI.row([title, enabled]), to: stack)
        NativeUI.add(status, to: stack)
        temperature.textColor = NativeUI.accent
        NativeUI.add(temperature, to: stack)
        addPresets()
        addSliders()
        addActions()
        warning.textColor = .systemOrange
        NativeUI.add(warning, to: stack)
        if !compact { addPreferences() }
        addFooter()
    }

    private func addPresets() {
        for start in [0, 4] {
            let buttons = Preset.all[start..<(start + 4)].map { preset -> NSButton in
                let button = NativeUI.button(preset.name, target: self, action: #selector(choose(_:)))
                button.tag = Preset.all.firstIndex { $0.id == preset.id } ?? 0
                button.font = .systemFont(ofSize: 11)
                return button
            }
            let row = NativeUI.row(buttons)
            row.distribution = .fillEqually
            NativeUI.add(row, to: stack)
        }
    }

    private func addSliders() {
        warmth.target = self
        warmth.action = #selector(adjustWarmth)
        warmth.isContinuous = false
        warmth.setAccessibilityLabel("Color temperature")
        dimmer.target = self
        dimmer.action = #selector(adjustBrightness)
        dimmer.isContinuous = false
        dimmer.setAccessibilityLabel("Software brightness")
        NativeUI.add(NativeUI.label("Warmth · deep red → daylight"), to: stack)
        NativeUI.add(warmth, to: stack)
        NativeUI.add(brightness, to: stack)
        NativeUI.add(dimmer, to: stack)
    }

    private func addActions() {
        pauseButton = NativeUI.button("Pause 15 min", target: self, action: #selector(pause))
        let reset = NativeUI.button("Restore colors", target: self, action: #selector(restore))
        NativeUI.add(NativeUI.row([pauseButton, reset]), to: stack)
    }

    private func addPreferences() {
        let view = PreferencesView(model: model)
        preferences = view
        NativeUI.add(view, to: stack)
    }

    private func addFooter() {
        let quit = NativeUI.button("Quit", target: NSApp, action: #selector(NSApplication.terminate(_:)))
        if compact {
            let settings = NativeUI.button("Settings…", target: self, action: #selector(openSettings))
            NativeUI.add(NativeUI.row([settings, quit]), to: stack)
        } else {
            NativeUI.add(NativeUI.label(model.shortcutStatus, size: 10), to: stack)
            NativeUI.add(quit, to: stack)
        }
    }

    func refresh() {
        NativeUI.assign(status, model.status)
        NativeUI.assign(temperature, "\(Int(model.settings.temperature)) K")
        NativeUI.assign(brightness, "Brightness · \(Int(model.settings.brightness * 100))%")
        NativeUI.assign(warning, model.error ?? "")
        warning.isHidden = model.error == nil
        enabled.state = model.settings.enabled ? .on : .off
        warmth.doubleValue = model.settings.temperature
        dimmer.doubleValue = model.settings.brightness
        pauseButton.title = model.pausedUntil == nil ? "Pause 15 min" : "Resume"
        pauseButton.isEnabled = model.settings.enabled
        preferences?.refresh()
    }

    @objc private func toggle() { model.toggle() }
    @objc private func choose(_ sender: NSButton) { model.choose(Preset.all[sender.tag]) }
    @objc private func adjustWarmth() { model.settings.temperature = (warmth.doubleValue / 50).rounded() * 50 }
    @objc private func adjustBrightness() { model.settings.brightness = dimmer.doubleValue }
    @objc private func restore() { model.reset() }
    @objc private func openSettings() { if let callback = model.showSettings { callback() } }
    @objc private func pause() {
        if model.pausedUntil == nil { model.pause() } else { model.resume() }
    }

    required init?(coder: NSCoder) { nil }

    init(model: AppModel, compact: Bool) {
        self.model = model
        self.compact = compact
        super.init(frame: NSRect(x: 0, y: 0, width: 360, height: 1))
        configureLayout()
        buildControls()
        refresh()
    }
}
