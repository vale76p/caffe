import AppKit
import CaffeCore
import IOKit.ps
import ServiceManagement
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let bundleID = "local.caffe.menubar"
    private let durations = defaultDurations

    private var statusItem: NSStatusItem!
    private let caffeinate = CaffeinateProcess()
    private let screensaver = ScreensaverControl()
    private var switches: [Int: PillSwitchView] = [:]
    private var flags = CaffeinateFlags.default
    private var ticker: Timer?
    private var menu: NSMenu!
    private var lastPowerStateOnAC = true

    private var headerTitleLabel: NSTextField!
    private var headerSubtitleLabel: NSTextField!
    private var durationItems: [(item: NSMenuItem, check: NSImageView)] = []
    private var stopItem: NSMenuItem!

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
        loadFlags()
        buildStatusItem()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        // .common: il countdown deve scorrere anche con il menu aperto (event tracking)
        RunLoop.main.add(t, forMode: .common)
        ticker = t
        startPowerMonitoring()
        if UserDefaults.standard.bool(forKey: SettingsKeys.activateOnLaunch) {
            try? caffeinate.start(option: .infinite, flags: flags)
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

        let menu = NSMenu()
        menu.addItem(headerItem())
        menu.addItem(.separator())
        for (index, option) in durations.enumerated() {
            menu.addItem(durationItem(option: option, index: index))
        }
        menu.addItem(.separator())

        stopItem = actionRow(title: "Disattiva ora", icon: "stop.circle") { [weak self] in
            self?.stopNow()
        }
        stopItem.isHidden = true
        menu.addItem(stopItem)
        menu.addItem(.separator())

        menu.addItem(sectionHeader("ASSERTIONS"))
        menu.addItem(switchItem(title: "Impedisci sleep del display", isOn: flags.display, tag: 10, icon: "display"))
        menu.addItem(switchItem(title: "Impedisci sleep da inattività", isOn: flags.idle, tag: 11, icon: "clock"))
        menu.addItem(switchItem(title: "Impedisci sleep del disco", isOn: flags.disk, tag: 12, icon: "internaldrive"))
        menu.addItem(switchItem(title: "Impedisci sleep di sistema (AC)", isOn: flags.system, tag: 13, icon: "bolt"))
        menu.addItem(.separator())
        menu.addItem(sectionHeader("IMPOSTAZIONI"))
        menu.addItem(switchItem(title: "Attiva al lancio",
                                isOn: UserDefaults.standard.bool(forKey: SettingsKeys.activateOnLaunch),
                                tag: 3, icon: "play"))
        menu.addItem(switchItem(title: "Avvia al login",
                                isOn: SMAppService.mainApp.status == .enabled,
                                tag: 2, icon: "power"))
        menu.addItem(switchItem(title: "Mostra notifiche", isOn: showNotifications, tag: 4, icon: "bell"))
        menu.addItem(switchItem(title: "Screensaver dopo 45 min",
                                isOn: screensaver.isActive, tag: 1, icon: "deskclock"))
        menu.addItem(switchItem(title: "Attiva quando alimentato",
                                isOn: UserDefaults.standard.bool(forKey: SettingsKeys.activateOnPlug),
                                tag: 5, icon: "powerplug"))
        menu.addItem(switchItem(title: "Spegni su batteria",
                                isOn: UserDefaults.standard.bool(forKey: SettingsKeys.deactivateOnUnplug),
                                tag: 6, icon: "battery.75"))

        menu.addItem(.separator())
        menu.addItem(versionItem())
        menu.addItem(actionRow(title: "Esci") { NSApp.terminate(nil) })

        for case let rowView as MenuRow in menu.items.compactMap({ $0.view }) {
            rowView.hostMenu = menu
        }
        self.menu = menu
        menu.delegate = self
        statusItem.button?.action = #selector(statusItemClicked(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        refresh()
    }

    /// Clic sinistro = attiva/disattiva; clic destro (o ⌥-clic) = menu.
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        let rightClick = event.type == .rightMouseUp
        let optionClick = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.option)
        if rightClick || optionClick {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
        } else {
            toggleCaffeinate()
        }
    }

    private func headerItem() -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let view = NSView(frame: NSRect(x: 0, y: 0, width: Grid.width, height: 44))
        headerTitleLabel = NSTextField(labelWithString: statusTitle(active: false))
        headerTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        headerSubtitleLabel = NSTextField(labelWithString: statusSubtitle(active: false,
                                                                         elapsedSeconds: nil,
                                                                         remainingSeconds: nil))
        headerSubtitleLabel.font = .systemFont(ofSize: 11)
        headerSubtitleLabel.textColor = .secondaryLabelColor
        for label in [headerTitleLabel!, headerSubtitleLabel!] {
            label.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(label)
        }
        NSLayoutConstraint.activate([
            headerTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Grid.iconBoxX),
            headerTitleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            headerSubtitleLabel.leadingAnchor.constraint(equalTo: headerTitleLabel.leadingAnchor),
            headerSubtitleLabel.topAnchor.constraint(equalTo: headerTitleLabel.bottomAnchor, constant: 2),
        ])
        item.view = view
        return item
    }

    private func lastDurationOption() -> DurationOption {
        let idx = UserDefaults.standard.integer(forKey: SettingsKeys.lastDurationIndex)
        return defaultDurations.indices.contains(idx) ? defaultDurations[idx] : .infinite
    }

    /// Usato dal clic sull'icona e dalla scorciatoia globale.
    private func toggleCaffeinate() {
        if caffeinate.isRunning {
            caffeinate.stop()
            notify(deactivationMessage)
        } else {
            let option = lastDurationOption()
            do {
                try caffeinate.start(option: option, flags: flags)
            } catch {
                NSSound.beep()
                return
            }
            ensureNotificationAuthorization()
            notify(activationMessage(for: option))
        }
        refresh()
    }

    // MARK: switch del menu

    private enum Grid {
        static let width: CGFloat = 300
        static let height: CGFloat = 26
        static let iconBoxX: CGFloat = 16
        static let iconBoxWidth: CGFloat = 20
        static let labelX: CGFloat = 42
        static let trailing: CGFloat = 16
    }

    private func addIcon(_ symbol: String?, to view: NSView, constraints: inout [NSLayoutConstraint]) {
        guard let symbol,
              let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) else { return }
        let iconView = NSImageView(image: image)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(iconView)
        constraints += [
            iconView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Grid.iconBoxX),
            iconView.widthAnchor.constraint(equalToConstant: Grid.iconBoxWidth),
            iconView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ]
    }

    private func switchItem(title: String, isOn: Bool, tag: Int, icon: String? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let view = MenuRow(frame: NSRect(x: 0, y: 0, width: Grid.width, height: Grid.height))
        var constraints: [NSLayoutConstraint] = []
        addIcon(icon, to: view, constraints: &constraints)
        let label = NSTextField(labelWithString: title)
        label.translatesAutoresizingMaskIntoConstraints = false
        let sw = PillSwitchView()
        sw.isOn = isOn
        sw.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        view.addSubview(sw)
        constraints += [
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Grid.labelX),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            sw.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Grid.trailing),
            sw.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            sw.widthAnchor.constraint(equalToConstant: 38),
            sw.heightAnchor.constraint(equalToConstant: 22),
        ]
        NSLayoutConstraint.activate(constraints)
        item.view = view
        view.onPick = { [weak self] in self?.toggleSetting(tag) }
        switches[tag] = sw
        return item
    }

    private func sectionHeader(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 20))
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        item.view = view
        return item
    }

    private func versionItem() -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let view = NSView(frame: NSRect(x: 0, y: 0, width: Grid.width, height: 22))
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0"
        let label = NSTextField(labelWithString: "Versione \(version)")
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        item.view = view
        return item
    }

    private func toggleSetting(_ tag: Int) {
        let d = UserDefaults.standard
        switch tag {
        case 1:
            if screensaver.isActive { screensaver.disable() } else { screensaver.enable() }
        case 2:
            toggleLoginCore()
        case 3:
            d.set(!d.bool(forKey: SettingsKeys.activateOnLaunch), forKey: SettingsKeys.activateOnLaunch)
        case 4:
            let newValue = !showNotifications
            d.set(newValue, forKey: SettingsKeys.showNotifications)
            if newValue { ensureNotificationAuthorization() }
        case 5:
            d.set(!d.bool(forKey: SettingsKeys.activateOnPlug), forKey: SettingsKeys.activateOnPlug)
        case 6:
            d.set(!d.bool(forKey: SettingsKeys.deactivateOnUnplug), forKey: SettingsKeys.deactivateOnUnplug)
        case 10:
            flags.display.toggle()
            flagsChanged()
        case 11:
            flags.idle.toggle()
            flagsChanged()
        case 12:
            flags.disk.toggle()
            flagsChanged()
        case 13:
            flags.system.toggle()
            flagsChanged()
        default:
            break
        }
        syncSwitches()
    }

    // MARK: azioni menu

    private func durationItem(option: DurationOption, index: Int) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let view = MenuRow(frame: NSRect(x: 0, y: 0, width: Grid.width, height: Grid.height))
        var constraints: [NSLayoutConstraint] = []
        let label = NSTextField(labelWithString: option.label)
        label.translatesAutoresizingMaskIntoConstraints = false
        let check = NSImageView(image: NSImage())
        check.contentTintColor = .labelColor
        check.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        view.addSubview(check)
        constraints += [
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Grid.labelX),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            check.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Grid.trailing),
            check.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ]
        NSLayoutConstraint.activate(constraints)
        view.onPick = { [weak self] in self?.pickDurationIndex(index) }
        view.dismissOnPick = true
        item.view = view
        durationItems.append((item, check))
        return item
    }

    private func pickDurationIndex(_ index: Int) {
        let option = defaultDurations[index]
        do {
            try caffeinate.start(option: option, flags: flags)
        } catch {
            NSSound.beep()
            return
        }
        UserDefaults.standard.set(index, forKey: SettingsKeys.lastDurationIndex)
        ensureNotificationAuthorization()
        notify(activationMessage(for: option))
        refresh()
    }

    private func actionRow(title: String, icon: String? = nil, pick: @escaping () -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let view = MenuRow(frame: NSRect(x: 0, y: 0, width: Grid.width, height: Grid.height))
        var constraints: [NSLayoutConstraint] = []
        addIcon(icon, to: view, constraints: &constraints)
        let label = NSTextField(labelWithString: title)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        constraints += [
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Grid.labelX),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ]
        NSLayoutConstraint.activate(constraints)
        view.onPick = pick
        view.dismissOnPick = true
        item.view = view
        return item
    }

    private func stopNow() {
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
    }

    // MARK: alimentatore

    private func startPowerMonitoring() {
        lastPowerStateOnAC = isOnACPower()
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let callback: IOPowerSourceCallbackType = { userData in
            guard let userData else { return }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { delegate.powerSourceChanged() }
        }
        guard let source = IOPSNotificationCreateRunLoopSource(callback, selfPtr)?.takeRetainedValue() else {
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    private func isOnACPower() -> Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return true
        }
        for ps in sources {
            if let desc = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any],
               let state = desc[kIOPSPowerSourceStateKey] as? String {
                return state == kIOPSACPowerValue // fix minimo: la costante IOKit è kIOPSACPowerValue
            }
        }
        return true
    }

    private func powerSourceChanged() {
        let onAC = isOnACPower()
        defer { lastPowerStateOnAC = onAC }
        guard onAC != lastPowerStateOnAC else { return }
        let d = UserDefaults.standard
        if onAC, d.bool(forKey: SettingsKeys.activateOnPlug), !caffeinate.isRunning {
            let option = lastDurationOption()
            try? caffeinate.start(option: option, flags: flags)
            notify(activationMessage(for: option))
            refresh()
        } else if !onAC, d.bool(forKey: SettingsKeys.deactivateOnUnplug), caffeinate.isRunning {
            caffeinate.stop()
            notify(deactivationMessage)
            refresh()
        }
    }

    // MARK: aggiornamento UI

    private func refresh() {
        let active = caffeinate.isRunning

        headerTitleLabel.stringValue = statusTitle(active: active)
        headerSubtitleLabel.stringValue = statusSubtitle(active: active,
                                                         elapsedSeconds: caffeinate.elapsedSeconds(),
                                                         remainingSeconds: caffeinate.secondsRemaining())

        statusItem.button?.image = statusIcon(active: active)

        for (index, entry) in durationItems.enumerated() {
            entry.check.image = (active && defaultDurations[index] == caffeinate.option)
                ? NSImage(systemSymbolName: "checkmark", accessibilityDescription: "attiva")
                : NSImage()
        }
        stopItem.isHidden = !active
    }

    private func syncSwitches() {
        switches[1]?.isOn = screensaver.isActive
        switches[2]?.isOn = (SMAppService.mainApp.status == .enabled)
        switches[3]?.isOn = UserDefaults.standard.bool(forKey: SettingsKeys.activateOnLaunch)
        switches[4]?.isOn = showNotifications
        switches[5]?.isOn = UserDefaults.standard.bool(forKey: SettingsKeys.activateOnPlug)
        switches[6]?.isOn = UserDefaults.standard.bool(forKey: SettingsKeys.deactivateOnUnplug)
        switches[10]?.isOn = flags.display
        switches[11]?.isOn = flags.idle
        switches[12]?.isOn = flags.disk
        switches[13]?.isOn = flags.system
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

    private func ensureNotificationAuthorization() {
        // UNUserNotificationCenter richiede un bundle: in sviluppo (swift run) niente notifiche
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                guard let self else { return }
                switch settings.authorizationStatus {
                case .notDetermined:
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, _ in
                        if granted { self.notify("Notifiche attive ☕️") }
                    }
                case .denied:
                    self.warnNotificationsDenied()
                default:
                    break
                }
            }
        }
    }

    private func warnNotificationsDenied() {
        let alert = NSAlert()
        alert.messageText = "Le notifiche sono disattivate per Caffè"
        alert.informativeText = """
            Abilitale in Impostazioni di sistema → Notifiche → Caffè \
            per vedere gli avvisi di attivazione e scadenza.
            """
        alert.addButton(withTitle: "Apri Impostazioni")
        alert.addButton(withTitle: "OK")
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings-extension") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func notify(_ body: String) {
        // UNUserNotificationCenter richiede un bundle: in sviluppo (swift run) niente notifiche
        guard Bundle.main.bundleIdentifier != nil else { return }
        guard showNotifications else { return }
        let content = UNMutableNotificationContent()
        content.title = "Caffè"
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: impostazioni persistenti (flag e preferenze)

    private enum SettingsKeys {
        static let activateOnLaunch = "CaffeActivateOnLaunch"
        static let showNotifications = "CaffeShowNotifications"
        static let flagDisplay = "CaffeFlagDisplay"
        static let flagIdle = "CaffeFlagIdle"
        static let flagDisk = "CaffeFlagDisk"
        static let flagSystem = "CaffeFlagSystem"
        static let activateOnPlug = "CaffeActivateOnPlug"
        static let deactivateOnUnplug = "CaffeDeactivateOnUnplug"
        static let lastDurationIndex = "CaffeLastDurationIndex"
    }

    private var showNotifications: Bool {
        UserDefaults.standard.object(forKey: SettingsKeys.showNotifications) as? Bool ?? true
    }

    private func loadFlags() {
        let d = UserDefaults.standard
        flags = CaffeinateFlags(
            display: d.object(forKey: SettingsKeys.flagDisplay) as? Bool ?? true,
            idle: d.object(forKey: SettingsKeys.flagIdle) as? Bool ?? true,
            disk: d.object(forKey: SettingsKeys.flagDisk) as? Bool ?? false,
            system: d.object(forKey: SettingsKeys.flagSystem) as? Bool ?? false
        )
    }

    private func saveFlags() {
        let d = UserDefaults.standard
        d.set(flags.display, forKey: SettingsKeys.flagDisplay)
        d.set(flags.idle, forKey: SettingsKeys.flagIdle)
        d.set(flags.disk, forKey: SettingsKeys.flagDisk)
        d.set(flags.system, forKey: SettingsKeys.flagSystem)
    }

    private func flagsChanged() {
        saveFlags()
        if caffeinate.isRunning, let option = caffeinate.option {
            try? caffeinate.start(option: option, flags: flags) // il figlio riparte coi nuovi flag
        }
    }
}

/// Interruttore disegnato a mano: NSSwitch dentro un NSMenu non ridisegna
/// il proprio stato (resta sempre grigio), qui il repaint è garantito da noi.
private final class PillSwitchView: NSView {
    var isOn = false {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        let pill = NSBezierPath(roundedRect: bounds,
                                xRadius: bounds.height / 2,
                                yRadius: bounds.height / 2)
        (isOn ? NSColor.controlAccentColor : NSColor.systemGray.withAlphaComponent(0.45)).setFill()
        pill.fill()

        let knobD = bounds.height - 4
        let knobX = isOn ? bounds.width - knobD - 2 : 2
        let knob = NSBezierPath(ovalIn: NSRect(x: knobX, y: 2, width: knobD, height: knobD))
        NSColor.white.setFill()
        knob.fill()
    }

    // i click li gestisce la riga intera: la pillola non deve consumarli
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// Riga di menu view-based: click ovunque nella riga; può chiudere il menu dopo l'azione.
private final class MenuRow: NSView {
    var onPick: (() -> Void)?
    var dismissOnPick = false
    weak var hostMenu: NSMenu?
    override func mouseDown(with event: NSEvent) { } // inghiottito: agiamo al rilascio
    override func mouseUp(with event: NSEvent) {
        onPick?()
        if dismissOnPick { hostMenu?.cancelTracking() }
    }
}

// Risincronizza gli switch a ogni apertura del menu (incluse modifiche esterne).
extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        refresh()
        syncSwitches()
    }

    func menuDidClose(_ menu: NSMenu) {
        syncSwitches() // niente visual "congelato" azzurro dopo la chiusura
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
