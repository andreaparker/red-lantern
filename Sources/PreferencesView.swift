import AppKit

final class PreferencesView: NSStackView {
    private let model: AppModel
    private let mode = NSPopUpButton()
    private let start = NSDatePicker()
    private let end = NSDatePicker()
    private let latitude = NSTextField(string: "")
    private let longitude = NSTextField(string: "")
    private let useLocation = NSButton(checkboxWithTitle: "Use these coordinates", target: nil, action: nil)
    private let dock = NSButton(checkboxWithTitle: "Show in Dock while window is open", target: nil, action: nil)
    private let login = NSButton(checkboxWithTitle: "Open at login", target: nil, action: nil)

    private func buildSchedule() {
        mode.addItems(withTitles: ScheduleMode.allCases.map(\.rawValue))
        mode.target = self
        mode.action = #selector(scheduleChanged)
        addArrangedSubview(NativeUI.row([NativeUI.label("Schedule"), mode]))
        configureTime(start)
        configureTime(end)
        addArrangedSubview(NativeUI.row([NativeUI.label("Start"), start, NativeUI.label("End"), end]))
        buildLocation()
    }

    private func buildLocation() {
        addArrangedSubview(NativeUI.label("Sunset: north/east positive, south/west negative.", size: 10))
        configureCoordinate(latitude, label: "Latitude")
        configureCoordinate(longitude, label: "Longitude")
        addArrangedSubview(NativeUI.row([latitude, longitude]))
        useLocation.target = self
        useLocation.action = #selector(locationChanged)
        addArrangedSubview(useLocation)
    }

    private func configureTime(_ picker: NSDatePicker) {
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = .hourMinute
        picker.target = self
        picker.action = #selector(timeChanged)
    }

    private func configureCoordinate(_ field: NSTextField, label: String) {
        field.placeholderString = label
        field.setAccessibilityLabel(label)
        field.widthAnchor.constraint(equalToConstant: 135).isActive = true
        field.target = self
        field.action = #selector(locationChanged)
    }

    private func buildBehavior() {
        dock.target = self
        dock.action = #selector(dockChanged)
        login.target = self
        login.action = #selector(loginChanged)
        addArrangedSubview(dock)
        addArrangedSubview(login)
        let note = NativeUI.label("Close the window to keep the filter running in the menu bar. Quit restores colors. For consistent color, turn off Night Shift and True Tone. Warmth is approximate; hardware PWM and dithering are unchanged.", size: 10)
        NativeUI.add(note, to: self)
    }

    func refresh() {
        mode.selectItem(withTitle: model.settings.schedule.rawValue)
        start.dateValue = date(model.settings.startMinute)
        end.dateValue = date(model.settings.endMinute)
        start.isEnabled = model.settings.schedule == .clock
        end.isEnabled = start.isEnabled
        refreshLocation()
        dock.state = model.settings.showInDock ? .on : .off
        login.state = model.loginEnabled ? .on : .off
    }

    private func refreshLocation() {
        let enabled = model.settings.schedule == .sun
        latitude.isEnabled = enabled
        longitude.isEnabled = enabled
        useLocation.isEnabled = enabled
        latitude.doubleValue = model.settings.latitude
        longitude.doubleValue = model.settings.longitude
        useLocation.state = model.settings.locationSet ? .on : .off
    }

    private func date(_ minute: Int) -> Date {
        Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60,
                              second: 0, of: Date()) ?? Date()
    }

    private func minute(_ date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    @objc private func scheduleChanged() {
        model.settings.schedule = ScheduleMode.allCases[mode.indexOfSelectedItem]
    }

    @objc private func timeChanged() {
        var next = model.settings
        next.startMinute = minute(start.dateValue)
        next.endMinute = minute(end.dateValue)
        model.settings = next
    }

    @objc private func locationChanged() {
        var next = model.settings
        next.latitude = min(90, max(-90, latitude.doubleValue))
        next.longitude = min(180, max(-180, longitude.doubleValue))
        next.locationSet = useLocation.state == .on
        model.settings = next
    }

    @objc private func dockChanged() { model.settings.showInDock = dock.state == .on }
    @objc private func loginChanged() { model.setLogin(login.state == .on) }

    required init?(coder: NSCoder) { nil }

    init(model: AppModel) {
        self.model = model
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = 10
        buildSchedule()
        buildBehavior()
        refresh()
    }
}
