import AppKit
import CaffeCore
import ServiceManagement
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let bundleID = "local.caffe.menubar"
    private let durations = defaultDurations

    private var statusItem: NSStatusItem!
    private let caffeinate = CaffeinateProcess()
    private var ticker: Timer?

    private var stateRow: NSMenuItem!
    private var durationItems: [NSMenuItem] = []
    private var stopItem: NSMenuItem!
    private var loginItem: NSMenuItem!

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
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refresh()
        }
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

        stateRow = NSMenuItem(title: inactiveStateRowText, action: nil, keyEquivalent: "")
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

        loginItem = NSMenuItem(title: "Avvia al login",
                               action: #selector(toggleLogin(_:)),
                               keyEquivalent: "")
        loginItem.target = self
        menu.addItem(loginItem)

        let quitItem = NSMenuItem(title: "Esci",
                                  action: #selector(quit(_:)),
                                  keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        refresh()
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

    @objc private func toggleLogin(_ sender: NSMenuItem) {
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
        refreshLoginState()
    }

    @objc private func quit(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }

    // MARK: aggiornamento UI

    private func refresh() {
        let active = caffeinate.isRunning

        stateRow.title = active
            ? stateRowText(option: caffeinate.option ?? .infinite,
                           secondsRemaining: caffeinate.secondsRemaining())
            : inactiveStateRowText

        let symbolName = active ? "cup.and.saucer.fill" : "cup.and.saucer"
        let image = NSImage(systemSymbolName: symbolName,
                            accessibilityDescription: active ? "Caffè attivo" : "Caffè inattivo")
        image?.isTemplate = true // segue aspetto chiaro/scuro e dimensioni standard
        statusItem.button?.image = image

        for item in durationItems {
            let index = item.representedObject as! Int
            item.state = (active && durations[index] == caffeinate.option) ? .on : .off
        }
        stopItem.isHidden = !active

        refreshLoginState()
    }

    private func refreshLoginState() {
        loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
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

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
