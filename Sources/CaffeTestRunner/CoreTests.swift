import Foundation
import CaffeCore

func runCoreTests() {
    // MARK: label
    runTest("labels delle durate") {
        try expectEqual(DurationOption.minutes(10).label, "10 min")
        try expectEqual(DurationOption.minutes(30).label, "30 min")
        try expectEqual(DurationOption.hours(1).label, "1 ora")
        try expectEqual(DurationOption.hours(2).label, "2 ore")
        try expectEqual(DurationOption.hours(5).label, "5 ore")
        try expectEqual(DurationOption.infinite.label, "Infinito")
    }

    // MARK: seconds
    runTest("secondi per durata") {
        try expectEqual(DurationOption.minutes(10).seconds, 600)
        try expectEqual(DurationOption.hours(2).seconds, 7200)
        try expectNil(DurationOption.infinite.seconds)
    }

    // MARK: defaultDurations
    runTest("durate predefinite del menu") {
        try expectEqual(defaultDurations, [
            .minutes(10), .minutes(30), .hours(1), .hours(2), .hours(5), .infinite
        ])
    }

    // MARK: remainingText
    runTest("remainingText: solo minuti") { try expectEqual(remainingText(seconds: 2520), "42 min") }
    runTest("remainingText: 1 ora esatta") { try expectEqual(remainingText(seconds: 3600), "1 ora") }
    runTest("remainingText: ore esatte") { try expectEqual(remainingText(seconds: 7200), "2 ore") }
    runTest("remainingText: ora e minuti") { try expectEqual(remainingText(seconds: 3900), "1 ora e 5 min") }
    runTest("remainingText: ore e minuti") { try expectEqual(remainingText(seconds: 9000), "2 ore e 30 min") }
    runTest("remainingText: meno di un minuto") { try expectEqual(remainingText(seconds: 30), "meno di un minuto") }

    // MARK: riga di stato del menu (senza emoji, con attività)
    runTest("stato: spento") {
        try expectEqual(statusLine(active: false, elapsedSeconds: nil, remainingSeconds: nil),
                        "Caffè spento")
    }
    runTest("stato: attivo infinito con attività") {
        try expectEqual(statusLine(active: true, elapsedSeconds: 4980, remainingSeconds: nil),
                        "Caffè attivo · da 1 ora e 23 min")
    }
    runTest("stato: attivo con countdown") {
        try expectEqual(statusLine(active: true, elapsedSeconds: 300, remainingSeconds: 2520),
                        "Caffè attivo · da 5 min · 42 min rimanenti")
    }
    runTest("stato: attivo senza attività nota") {
        try expectEqual(statusLine(active: true, elapsedSeconds: nil, remainingSeconds: nil),
                        "Caffè attivo")
    }

    // MARK: messaggi notifica
    runTest("messaggio di attivazione") {
        try expectEqual(activationMessage(for: .hours(2)), "Il Mac non dormirà per 2 ore ☕️")
        try expectEqual(activationMessage(for: .minutes(10)), "Il Mac non dormirà per 10 min ☕️")
        try expectEqual(activationMessage(for: .infinite), "Il Mac non dormirà finché non disattivi ☕️")
    }
    runTest("messaggio di disattivazione") {
        try expectEqual(deactivationMessage, "Il Mac può di nuovo andare a dormire 💤")
    }
}
