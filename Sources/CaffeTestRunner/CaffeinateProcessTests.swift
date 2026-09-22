import Foundation
import CaffeCore

func runCaffeinateProcessTests() {
    runTest("avvio infinito: running, opzione, senza scadenza") {
        let c = CaffeinateProcess()
        try c.start(option: .infinite)
        try expectTrue(c.isRunning)
        try expectEqual(c.option, .infinite)
        try expectNil(c.secondsRemaining())
        c.stop()
        try expectFalse(c.isRunning)
    }

    runTest("stop manuale: nessun callback di scadenza") {
        let expiryQueue = DispatchQueue(label: "test.caffe.expiry1")
        let c = CaffeinateProcess(expiryQueue: expiryQueue)
        var expired = false
        c.onNaturalExpiry = { expired = true }
        try c.start(option: .infinite)
        c.stop()
        expiryQueue.sync { } // nessun lavoro in coda: il callback non è mai partito
        try expectFalse(expired)
        try expectNil(c.option)
    }

    runTest("scadenza naturale: callback, poi non running") {
        let expiryQueue = DispatchQueue(label: "test.caffe.expiry2")
        let done = DispatchSemaphore(value: 0)
        let c = CaffeinateProcess(expiryQueue: expiryQueue)
        c.onNaturalExpiry = { done.signal() }
        try c.start(seconds: 1) // caffeinate -t 1
        try expectTrue(c.isRunning)
        try expectEqual(done.wait(timeout: .now() + 10), .success)
        expiryQueue.sync { } // la coda ha finito di pulire lo stato
        try expectFalse(c.isRunning)
        try expectNil(c.option)
    }

    runTest("sostituzione: nessun callback di scadenza") {
        let expiryQueue = DispatchQueue(label: "test.caffe.expiry3")
        var expired = false
        let c = CaffeinateProcess(expiryQueue: expiryQueue)
        c.onNaturalExpiry = { expired = true }
        try c.start(seconds: 1)
        try c.start(option: .infinite) // sostituisce prima della scadenza
        expiryQueue.sync { }
        try expectFalse(expired)
        c.stop()
    }

    runTest("riavvio: il nuovo figlio sostituisce il vecchio") {
        let c = CaffeinateProcess()
        try c.start(option: .minutes(10))
        try c.start(option: .hours(1))
        try expectEqual(c.option, .hours(1))
        try expectTrue(c.secondsRemaining()! > 3000)
        c.stop()
    }

    runTest("countdown: secondi rimanenti nell'intervallo atteso") {
        let c = CaffeinateProcess()
        try c.start(option: .minutes(10))
        let s = c.secondsRemaining()!
        try expectTrue((540...600).contains(s), "atteso 540-600, avuto \(s)")
        c.stop()
    }
}
