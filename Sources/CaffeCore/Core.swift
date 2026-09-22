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

/// Testo della riga di stato in cima al menu quando attivo.
public func stateRowText(option: DurationOption, secondsRemaining: Int?) -> String {
    switch option {
    case .infinite:
        return "☕️ Attivo — finché non disattivi"
    default:
        guard let s = secondsRemaining else { return "☕️ Attivo" }
        return "☕️ Attivo — \(remainingText(seconds: s)) rimanenti"
    }
}

/// Testo della riga di stato quando inattivo.
public let inactiveStateRowText = "😴 Il Mac può dormire"

/// Corpo della notifica all'attivazione.
public func activationMessage(for option: DurationOption) -> String {
    switch option {
    case .infinite: return "Il Mac non dormirà finché non disattivi ☕️"
    default: return "Il Mac non dormirà per \(option.label) ☕️"
    }
}

/// Corpo della notifica a spegnimento/scadenza.
public let deactivationMessage = "Il Mac può di nuovo andare a dormire 💤"
