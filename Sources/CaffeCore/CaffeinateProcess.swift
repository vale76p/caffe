import Foundation

/// Flag per-processo: distingue lo stop manuale dalla scadenza naturale.
private final class StopFlag {
    var manual = false
}

/// I flag di caffeinate selezionabili dal menu (sezione ASSERTIONS).
public struct CaffeinateFlags: Equatable {
    public var display: Bool  // -d: impedisci sleep del display
    public var idle: Bool     // -i: impedisci sleep del sistema per inattività
    public var disk: Bool     // -m: impedisci sleep del disco
    public var system: Bool   // -s: impedisci sleep del sistema (solo alimentazione AC)

    public init(display: Bool = true, idle: Bool = true, disk: Bool = false, system: Bool = false) {
        self.display = display
        self.idle = idle
        self.disk = disk
        self.system = system
    }

    /// Argomenti da passare a caffeinate, ordine stabile.
    public var arguments: [String] {
        var a: [String] = []
        if display { a.append("-d") }
        if idle { a.append("-i") }
        if disk { a.append("-m") }
        if system { a.append("-s") }
        return a
    }

    /// Combinazione storica dell'app: -di.
    public static let `default` = CaffeinateFlags(display: true, idle: true)
}

/// Gestisce `/usr/bin/caffeinate` come processo figlio.
/// Spegnere = terminate() sul proprio figlio: mai pkill globale.
public final class CaffeinateProcess {

    /// Chiamato sulla expiryQueue quando caffeinate scade da solo (fine timer).
    /// NON viene chiamato su `stop()` né quando una nuova attivazione sostituisce la precedente.
    public var onNaturalExpiry: (() -> Void)?

    /// Coda su cui arrivano onNaturalExpiry e la pulizia dello stato:
    /// main per l'app (tutta la UI legge da lì); una coda privata nei test,
    /// così possono attenderla con sync senza far girare una run loop.
    private let expiryQueue: DispatchQueue

    public init(expiryQueue: DispatchQueue = .main) {
        self.expiryQueue = expiryQueue
    }

    private var process: Process?
    private var stopFlag: StopFlag?

    /// L'opzione attiva, se il caffeinate gira.
    public private(set) var option: DurationOption?

    private var endDate: Date?
    private var startDate: Date?

    public var isRunning: Bool {
        return process?.isRunning ?? false
    }

    /// PID del figlio caffeinate, per verifica funzionale (nil se non attivo).
    public var childProcessIdentifier: Int? {
        return process.map { Int($0.processIdentifier) }
    }

    /// Secondi alla scadenza (nil se non attivo o infinito).
    public func secondsRemaining(now: Date = Date()) -> Int? {
        guard let endDate else { return nil }
        return max(0, Int(endDate.timeIntervalSince(now)))
    }

    /// Secondi da quando il caffeinate è attivo (nil se non attivo).
    public func elapsedSeconds(now: Date = Date()) -> Int? {
        guard let startDate else { return nil }
        return max(0, Int(now.timeIntervalSince(startDate)))
    }

    /// Attiva una durata del menu, sostituendo l'eventuale attivazione in corso.
    public func start(option: DurationOption, flags: CaffeinateFlags = .default) throws {
        try start(seconds: option.seconds, flags: flags)
        self.option = option
    }

    /// Avvio a basso livello (usato dai test per durate brevi).
    public func start(seconds: Int?, flags: CaffeinateFlags = .default) throws {
        stop()

        let flag = StopFlag()
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        var args = flags.arguments
        if let seconds {
            args += ["-t", String(seconds)]
        }
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        let expiryQueue = self.expiryQueue
        p.terminationHandler = { [weak self] terminated in
            guard !flag.manual else { return }
            expiryQueue.async {
                // solo se è ancora "questo" processo a rappresentare lo stato attivo
                guard let self, self.process === terminated else { return }
                self.handleNaturalExpiry()
            }
        }

        try p.run()
        process = p
        stopFlag = flag
        endDate = seconds.map { Date().addingTimeInterval(TimeInterval($0)) }
        startDate = Date()
    }

    /// Spegne il proprio caffeinate figlio, senza notifiche.
    public func stop() {
        guard let p = process else { return }
        stopFlag?.manual = true
        if p.isRunning {
            p.terminate()
        }
        p.waitUntilExit()
        clear()
    }

    private func handleNaturalExpiry() {
        clear()
        onNaturalExpiry?()
    }

    private func clear() {
        process = nil
        stopFlag = nil
        option = nil
        endDate = nil
        startDate = nil
    }
}
