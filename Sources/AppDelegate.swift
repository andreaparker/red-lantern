import AppKit
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = AppModel()
    private var statusItem: NSStatusItem!
    private var menuPanel: NSPanel?
    private var menuControls: ControlsView?
    private var window: NSWindow?
    private var windowControls: ControlsView?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var runningInBackground = false
    private var hotKey: EventHotKeyRef?
    private var notificationTokens: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenu()
        configureStatusItem()
        configureCallbacks()
        observeWorkspace()
        registerRestoreShortcut()
        model.start()
        if CommandLine.arguments.contains("--show-menu") { toggleMenu() }
        else if !CommandLine.arguments.contains("--background") { showWindow() }
    }

    private func configureCallbacks() {
        model.showSettings = { [weak self] in self?.showWindow() }
        model.changed = { [weak self] in
            self?.menuControls?.refresh()
            self?.windowControls?.refresh()
        }
        model.dockChanged = { [weak self] shown in self?.updateDockVisibility(shown) }
        model.statusChanged = { [weak self] active in
            self?.statusItem.button?.image = NSImage(systemSymbolName: active ? "sun.horizon.fill" : "sun.horizon",
                                                    accessibilityDescription: "Red Lantern")
            self?.statusItem.button?.toolTip = active ? "Red Lantern · On" : "Red Lantern · Off"
        }
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "sun.horizon", accessibilityDescription: "Red Lantern")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggleMenu)
    }

    @objc private func toggleMenu() {
        if menuPanel != nil { closeMenu(); return }
        guard let button = statusItem.button, let host = button.window,
              let screen = host.screen ?? NSScreen.main else { return }
        let controls = ControlsView(model: model, compact: true)
        let anchor = host.convertToScreen(button.convert(button.bounds, to: nil))
        let size = NSSize(width: 360, height: controls.fittingSize.height)
        let frame = WindowPlacement.menu(anchor: anchor, size: size, screen: screen.visibleFrame)
        presentMenu(controls, frame: frame)
    }

    private func presentMenu(_ controls: ControlsView, frame: NSRect) {
        let panel = LanternPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
        panel.level = .popUpMenu
        panel.title = "Red Lantern Quick Controls"
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true
        panel.contentView = NativeUI.document(controls, width: frame.width)
        panel.delegate = self
        menuControls = controls
        menuPanel = panel
        monitorMenuDismissal()
        panel.makeKeyAndOrderFront(nil)
    }

    private func monitorMenuDismissal() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] _ in self?.closeMenu()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] event in
            guard let self else { return event }
            if event.window !== self.menuPanel && event.window !== self.statusItem.button?.window { self.closeMenu() }
            return event
        }
    }

    private func closeMenu() {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
        menuPanel?.orderOut(nil)
        menuPanel = nil
        menuControls = nil
    }

    func showWindow() {
        runningInBackground = false
        updateDockVisibility(model.settings.showInDock)
        closeMenu()
        if window == nil { createWindow() }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createWindow() {
        let controls = ControlsView(model: model, compact: false)
        let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 700),
                             styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        panel.title = "Red Lantern"
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.contentView = NativeUI.document(controls, width: 360)
        panel.appearance = NSAppearance(named: .darkAqua)
        if let screen = preferredScreen() {
            panel.setFrame(WindowPlacement.centered(size: panel.frame.size, screen: screen.visibleFrame), display: false)
        }
        windowControls = controls
        window = panel
    }

    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === menuPanel { closeMenu(); return }
        guard notification.object as? NSWindow === window else { return }
        windowControls = nil
        window = nil
        runningInBackground = true
        updateDockVisibility(model.settings.showInDock)
    }

    private func preferredScreen() -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
    }

    private func screensChanged() {
        if let window, let screen = window.screen ?? preferredScreen() {
            window.setFrame(WindowPlacement.clamp(window.frame, inside: screen.visibleFrame), display: true)
        }
        closeMenu()
        model.displaysChanged()
    }

    private func updateDockVisibility(_ enabled: Bool) {
        let showIcon = enabled && !runningInBackground
        let desired: NSApplication.ActivationPolicy = showIcon ? .regular : .accessory
        if NSApp.activationPolicy() != desired { NSApp.setActivationPolicy(desired) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        model.engine.restore()
        if let hotKey { UnregisterEventHotKey(hotKey) }
    }

    private func observeWorkspace() {
        let center = NSWorkspace.shared.notificationCenter
        notificationTokens.append(center.addObserver(forName: NSWorkspace.willSleepNotification,
                                                     object: nil, queue: .main) { [weak self] _ in self?.model.sleep() })
        notificationTokens.append(center.addObserver(forName: NSWorkspace.didWakeNotification,
                                                     object: nil, queue: .main) { [weak self] _ in self?.model.wake() })
        notificationTokens.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in self?.screensChanged() })
        for name in [Notification.Name.NSSystemClockDidChange, .NSSystemTimeZoneDidChange] {
            notificationTokens.append(NotificationCenter.default.addObserver(
                forName: name, object: nil, queue: .main) { [weak self] _ in self?.model.tick() })
        }
    }

    private func registerRestoreShortcut() {
        let callback: EventHandlerUPP = { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
            delegate.model.reset()
            return noErr
        }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let result = InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType,
                                        Unmanaged.passUnretained(self).toOpaque(), nil)
        guard result == noErr else {
            model.shortcutStatus = "Restore handler unavailable (\(result)); use Restore colors."
            return
        }
        bindRestoreShortcut()
    }

    private func bindRestoreShortcut() {
        let key = EventHotKeyID(signature: 0x524C4E54, id: 1)
        let result = RegisterEventHotKey(UInt32(kVK_ANSI_R), UInt32(controlKey | optionKey | cmdKey),
                                        key, GetApplicationEventTarget(), 0, &hotKey)
        if result != noErr { model.shortcutStatus = "Shortcut unavailable (\(result)); use Restore colors." }
    }

    private func configureMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        appItem.submenu = applicationMenu()
        menu.addItem(appItem)
        menu.addItem(editMenu())
        NSApp.mainMenu = menu
    }

    private func applicationMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(menuCommand("Quick Controls", action: #selector(toggleMenu)))
        menu.addItem(menuCommand("Settings…", action: #selector(openSettings), key: ","))
        let restore = menuCommand("Restore Colors", action: #selector(restoreColors), key: "r")
        restore.keyEquivalentModifierMask = [.command, .control, .option]
        menu.addItem(restore)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Red Lantern", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    private func menuCommand(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func openSettings() { showWindow() }
    @objc private func restoreColors() { model.reset() }

    private func editMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Edit")
        menu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        item.submenu = menu
        return item
    }
}

private final class LanternPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { close() }
}
