import Foundation
import CaffeCore

func runScreensaverControlTests() {
    // stub in memoria: niente defaults reali nei test.
    // Nota (fix minimo rispetto al brief): le closure reader/writer sono escaping
    // (salvate in ScreensaverControl) e non possono catturare parametri inout,
    // quindi lo stato dello stub vive in una class-box invece che in inout var.
    final class DefaultsStub {
        var current: String?
        var written: [Int?] = []
    }

    func makeControl(_ stub: DefaultsStub) -> ScreensaverControl {
        ScreensaverControl(idleSeconds: 2700,
                           reader: { stub.current },
                           writer: { stub.written.append($0); stub.current = $0.map(String.init) })
    }

    runTest("screensaver: enable scrive 45' e salva il precedente") {
        let stub = DefaultsStub()
        stub.current = "300"
        let c = makeControl(stub)
        try expectFalse(c.isActive)
        c.enable()
        try expectEqual(stub.written, [2700])
        try expectTrue(c.isActive)
    }

    runTest("screensaver: disable ripristina il valore precedente") {
        let stub = DefaultsStub()
        stub.current = "300"
        let c = makeControl(stub)
        c.enable()
        c.disable()
        try expectEqual(stub.written, [2700, 300])
        try expectFalse(c.isActive)
    }

    runTest("screensaver: disable senza precedente noto torna al default") {
        let stub = DefaultsStub()
        let c = makeControl(stub)
        c.enable()
        c.disable()
        try expectEqual(stub.written, [2700, nil])
        try expectFalse(c.isActive)
    }

    runTest("screensaver: già a 45' non salva falsi precedenti") {
        let stub = DefaultsStub()
        stub.current = "2700"
        let c = makeControl(stub)
        try expectTrue(c.isActive)
        c.enable()
        try expectEqual(stub.written, [2700])
        c.disable()
        try expectEqual(stub.written, [2700, nil])
    }
}
