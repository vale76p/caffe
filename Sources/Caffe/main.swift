import AppKit
import CaffeCore
import ServiceManagement
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let bundleID = "local.caffe.menubar"
    private let durations = defaultDurations

    private var statusItem: NSStatusItem!
    private let caffeinate = CaffeinateProcess()
    private let screensaver = ScreensaverControl()
    private var screensaverSwitch: NSSwitch?
    private var loginSwitch: NSSwitch?
    private var ticker: Timer?

    private var stateRow: NSMenuItem!
    private var durationItems: [NSMenuItem] = []
    private var stopItem: NSMenuItem!

    private var authRequested = false

    // MARK: ciclo di vita

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ensureSingleInstance() else {
            NSApp.terminate(nil)
            return
        }
        caffeinate.onNaturalExpiry = { [weak self] in
            self?.notify(deactivationMessage)
            self?.refresh()
        }
        buildStatusItem()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        // .common: il countdown deve scorrere anche con il menu aperto (event tracking)
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        caffeinate.stop() // uscendo, il Mac torna dormibile
        return .terminateNow
    }

    /// Se un'altra istanza gira già, attivala e chiudi questa.
    private func ensureSingleInstance() -> Bool {
        let myPID = ProcessInfo.processInfo.processIdentifier
        let others = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == bundleID && $0.processIdentifier != myPID
        }
        if let existing = others.first {
            existing.activate()
            return false
        }
        return true
    }

    // MARK: costruzione UI

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        stateRow = NSMenuItem(title: "Caffè spento", action: nil, keyEquivalent: "")
        stateRow.isEnabled = false

        let menu = NSMenu()
        menu.addItem(stateRow)
        menu.addItem(.separator())
        for (index, option) in durations.enumerated() {
            let item = NSMenuItem(title: option.label,
                                  action: #selector(pickDuration(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = index
            menu.addItem(item)
            durationItems.append(item)
        }
        menu.addItem(.separator())

        stopItem = NSMenuItem(title: "Disattiva ora",
                              action: #selector(stopNow(_:)),
                              keyEquivalent: "")
        stopItem.target = self
        stopItem.isHidden = true
        menu.addItem(stopItem)
        menu.addItem(.separator())

        let screensaverItem = switchItem(title: "Screensaver dopo 45 min", isOn: screensaver.isActive, tag: 1)
        menu.addItem(screensaverItem)
        let loginItem = switchItem(title: "Avvia al login",
                                   isOn: SMAppService.mainApp.status == .enabled,
                                   tag: 2)
        menu.addItem(loginItem)

        let quitItem = NSMenuItem(title: "Esci",
                                  action: #selector(quit(_:)),
                                  keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        menu.delegate = self
        statusItem.menu = menu
        refresh()
    }

    // MARK: switch del menu

    private func switchItem(title: String, isOn: Bool, tag: Int) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 26))
        let label = NSTextField(labelWithString: title)
        label.translatesAutoresizingMaskIntoConstraints = false
        let sw = NSSwitch(frame: .zero)
        sw.translatesAutoresizingMaskIntoConstraints = false
        sw.tag = tag
        sw.state = isOn ? .on : .off
        sw.target = self
        sw.action = #selector(toggleSwitch(_:))
        view.addSubview(label)
        view.addSubview(sw)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            sw.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            sw.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        item.view = view
        switch tag {
        case 1: screensaverSwitch = sw
        default: loginSwitch = sw
        }
        return item
    }

    @objc private func toggleSwitch(_ sender: NSSwitch) {
        switch sender.tag {
        case 1:
            if sender.state == .on {
                screensaver.enable()
            } else {
                screensaver.disable()
            }
        case 2:
            toggleLoginCore()
        default:
            break
        }
    }

    // MARK: azioni menu

    @objc private func pickDuration(_ sender: NSMenuItem) {
        let option = durations[sender.representedObject as! Int]
        do {
            try caffeinate.start(option: option)
        } catch {
            NSSound.beep()
            return
        }
        requestNotificationAuthorizationIfNeeded()
        notify(activationMessage(for: option))
        refresh()
    }

    @objc private func stopNow(_ sender: NSMenuItem) {
        caffeinate.stop()
        notify(deactivationMessage)
        refresh()
    }

    private func toggleLoginCore() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Impossibile modificare l'avvio al login"
            alert.informativeText = """
                Errore: \(error.localizedDescription)
                Verifica che Caffè si trovi in ~/Applications e riprova.
                """
            alert.runModal()
        }
        loginSwitch?.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
    }

    @objc private func quit(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }

    // MARK: aggiornamento UI

    private func refresh() {
        let active = caffeinate.isRunning

        stateRow.title = statusLine(active: caffeinate.isRunning,
                                    elapsedSeconds: caffeinate.elapsedSeconds(),
                                    remainingSeconds: caffeinate.secondsRemaining())

        statusItem.button?.image = statusIcon(active: active)

        for item in durationItems {
            let index = item.representedObject as! Int
            item.state = (active && durations[index] == caffeinate.option) ? .on : .off
        }
        stopItem.isHidden = !active
    }

    private func statusIcon(active: Bool) -> NSImage? {
        if active {
            let image = NSImage(systemSymbolName: "cup.and.saucer.fill",
                                accessibilityDescription: "Caffè attivo")
            image?.isTemplate = true // contrasto pieno, segue chiaro/scuro
            return image
        } else {
            let symbol = NSImage(systemSymbolName: "cup.and.saucer",
                                  accessibilityDescription: "Caffè inattivo")
            let gray = NSImage.SymbolConfiguration(paletteColors: [NSColor(white: 0.65, alpha: 1.0)])
            let image = symbol?.withSymbolConfiguration(gray)
            image?.isTemplate = false // rispetta il grigio chiaro richiesto
            return image
        }
    }

    // MARK: notifiche

    private func requestNotificationAuthorizationIfNeeded() {
        guard !authRequested else { return }
        authRequested = true
        // come notify(): senza bundle (sviluppo) il centro notifiche non esiste e
        // UNUserNotificationCenter.current() crasha — non provarci nemmeno
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    private func notify(_ body: String) {
        // UNUserNotificationCenter richiede un bundle: in sviluppo (swift run) niente notifiche
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = "Caffè"
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

// Risincronizza gli switch a ogni apertura del menu (incluse modifiche esterne).
extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        refresh()
        screensaverSwitch?.state = screensaver.isActive ? .on : .off
        loginSwitch?.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
