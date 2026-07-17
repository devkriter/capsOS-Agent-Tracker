import Cocoa
import ServiceManagement

/// Menu bar controller: owns the LED/blink engine, listens for state-change
/// signals from `caps-signal`, and exposes manual testing + permission setup.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let ledController = LEDController()
    private lazy var blinkEngine = BlinkEngine(led: ledController)
    private var statusItem: NSStatusItem!
    private let signalNotificationName = Notification.Name("com.furkansenturk.capslockled.signal")
    private var diagnosticMessage: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        blinkEngine.onStateChange = { [weak self] state in
            self?.updateStatusItemTitle(for: state)
        }
        updateStatusItemTitle(for: .idle)

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleSignal(_:)),
            name: signalNotificationName,
            object: nil
        )

        // Never block launch on a modal alert here: an .accessory app that
        // hasn't been user-activated can show a dialog that never becomes
        // key/visible, which looks exactly like the app hanging. Diagnostics
        // are surfaced in the menu instead, non-blocking.
        refreshDiagnostics()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.isVisible = true
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let stateItem = NSMenuItem(title: "State: idle", action: nil, keyEquivalent: "")
        stateItem.tag = 100
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        menu.addItem(.separator())

        let testItem = NSMenuItem(title: "Test Blink", action: nil, keyEquivalent: "")
        let testMenu = NSMenu()
        for (title, selector) in [
            ("Working", #selector(testWorking)),
            ("Needs Input", #selector(testNeedsInput)),
            ("Done", #selector(testDone)),
            ("Off", #selector(testIdle))
        ] {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.target = self
            testMenu.addItem(item)
        }
        menu.setSubmenu(testMenu, for: testItem)
        menu.addItem(testItem)

        menu.addItem(.separator())

        let setupHooksItem = NSMenuItem(
            title: "Set Up Claude Code Hooks",
            action: #selector(setUpHooks),
            keyEquivalent: ""
        )
        setupHooksItem.target = self
        menu.addItem(setupHooksItem)

        let removeHooksItem = NSMenuItem(
            title: "Remove Claude Code Hooks",
            action: #selector(removeHooks),
            keyEquivalent: ""
        )
        removeHooksItem.target = self
        menu.addItem(removeHooksItem)

        menu.addItem(.separator())

        let diagnosticItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        diagnosticItem.tag = 101
        diagnosticItem.isHidden = true
        diagnosticItem.isEnabled = false
        menu.addItem(diagnosticItem)

        let recheckItem = NSMenuItem(
            title: "Recheck Permission",
            action: #selector(recheckDiagnostics),
            keyEquivalent: ""
        )
        recheckItem.target = self
        menu.addItem(recheckItem)

        let permItem = NSMenuItem(
            title: "Open Input Monitoring Settings…",
            action: #selector(openInputMonitoringSettings),
            keyEquivalent: ""
        )
        permItem.target = self
        menu.addItem(permItem)

        let loginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }

    @objc private func testWorking() { blinkEngine.setState(.working) }
    @objc private func testNeedsInput() { blinkEngine.setState(.needsInput) }
    @objc private func testDone() { blinkEngine.setState(.done) }
    @objc private func testIdle() { blinkEngine.setState(.idle) }

    @objc private func setUpHooks() {
        do {
            let message = try HookInstaller.run(remove: false)
            showAlert(title: "Hooks Installed", message: message, style: .informational)
        } catch {
            showAlert(title: "Couldn't Install Hooks", message: error.localizedDescription)
        }
    }

    @objc private func removeHooks() {
        do {
            let message = try HookInstaller.run(remove: true)
            showAlert(title: "Hooks Removed", message: message, style: .informational)
        } catch {
            showAlert(title: "Couldn't Remove Hooks", message: error.localizedDescription)
        }
    }

    @objc private func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
                sender.state = .off
            } else {
                try SMAppService.mainApp.register()
                sender.state = .on
            }
        } catch {
            showAlert(title: "Couldn't update Launch at Login", message: error.localizedDescription)
        }
    }

    @objc private func handleSignal(_ note: Notification) {
        guard let raw = note.object as? String, let state = LEDState(rawValue: raw) else { return }
        blinkEngine.setState(state)
    }

    private func updateStatusItemTitle(for state: LEDState) {
        let symbolName: String
        let color: NSColor
        if diagnosticMessage != nil {
            symbolName = "exclamationmark.triangle.fill"
            color = .systemYellow
        } else {
            switch state {
            case .idle: symbolName = "circle"; color = .secondaryLabelColor
            case .working: symbolName = "circle.fill"; color = .systemBlue
            case .needsInput: symbolName = "circle.fill"; color = .systemOrange
            case .done: symbolName = "circle.fill"; color = .systemGreen
            }
        }
        statusItem.button?.title = ""
        statusItem.button?.image = symbolImage(name: symbolName, color: color)
        statusItem.menu?.item(withTag: 100)?.title = "State: \(state.rawValue)"
    }

    private func symbolImage(name: String, color: NSColor) -> NSImage? {
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return nil }
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        let colored = base.withSymbolConfiguration(config)
        colored?.isTemplate = false
        return colored
    }

    @objc private func recheckDiagnostics() {
        refreshDiagnostics()
    }

    /// Non-blocking: never shows a modal dialog. Surfaces problems as a
    /// disabled line in the menu and a warning icon in the menu bar instead.
    private func refreshDiagnostics() {
        if !ledController.hasCapsLockDevice {
            diagnosticMessage = "No Caps Lock LED found on this keyboard"
        } else if LEDController.checkAccess() == .denied {
            diagnosticMessage = "Input Monitoring permission not granted"
        } else {
            diagnosticMessage = nil
        }

        if let diagnosticItem = statusItem.menu?.item(withTag: 101) {
            diagnosticItem.isHidden = diagnosticMessage == nil
            diagnosticItem.title = diagnosticMessage.map { "⚠️ \($0)" } ?? ""
        }
        updateStatusItemTitle(for: blinkEngine.state)
    }

    /// Only ever called from a menu action the user just clicked, so the app
    /// already has activation context and the alert can safely become key.
    private func showAlert(title: String, message: String, style: NSAlert.Style = .warning) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.runModal()
    }
}
