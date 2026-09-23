import Foundation

/// Una durata selezionabile dal menu.
public enum DurationOption: Equatable {
    case minutes(Int)
    case hours(Int)
    case infinite

    /// Secondi di durata; nil per l'infinito.
    public var seconds: Int? {
        switch self {
        case .minutes(let m): return m * 60
        case .hours(let h): return h * 3600
        case .infinite: return nil
        }
    }

    /// Etichetta italiana del menu.
    public var label: String {
        switch self {
        case .minutes(let m): return "\(m) min"
        case .hours(let h): return h == 1 ? "1 ora" : "\(h) ore"
        case .infinite: return "Infinito"
        }
    }
}

/// Le durate mostrate nel menu (personalizzabile da qui).
public let defaultDurations: [DurationOption] = [
    .minutes(10), .minutes(30), .hours(1), .hours(2), .hours(5), .infinite
]

/// Formatta i secondi rimanenti: "42 min", "1 ora", "1 ora e 5 min", "2 ore e 30 min".
public func remainingText(seconds: Int) -> String {
    precondition(seconds >= 0)
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    switch (h, m) {
    case (0, 0): return "meno di un minuto"
    case (0, let m): return "\(m) min"
    case (let h, 0): return h == 1 ? "1 ora" : "\(h) ore"
    case (let h, let m): return (h == 1 ? "1 ora" : "\(h) ore") + " e \(m) min"
    }
}

/// Minuti di inattività dopo cui attivare lo screensaver quando il toggle è accesso.
public let screensaverIdleSeconds = 45 * 60

/// Titolo dell'header del menu (riga 1).
public func statusTitle(active: Bool) -> String {
    active ? "Caffè attivo" : "Caffè spento"
}

/// Sottotitolo dell'header del menu (riga 2).
public func statusSubtitle(active: Bool, elapsedSeconds: Int?, remainingSeconds: Int?) -> String {
    guard active else { return "clic per attivare" }
    var s = "da " + remainingText(seconds: elapsedSeconds ?? 0)
    if let r = remainingSeconds {
        s += " · " + remainingText(seconds: r) + " rimanenti"
    }
    return s
}

/// Corpo della notifica all'attivazione.
public func activationMessage(for option: DurationOption) -> String {
    switch option {
    case .infinite: return "Il Mac non dormirà finché non disattivi ☕️"
    default: return "Il Mac non dormirà per \(option.label) ☕️"
    }
}

/// Corpo della notifica a spegnimento/scadenza.
public let deactivationMessage = "Il Mac può di nuovo andare a dormire 💤"
