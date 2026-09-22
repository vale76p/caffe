import Foundation

/// Controlla l'idle time dello screensaver via `defaults -currentHost`.
/// Reader/writer iniettabili: i test usano stub in memoria, l'app usa i processi reali.
public final class ScreensaverControl {

    public typealias DefaultsReader = () -> String?
    public typealias DefaultsWriter = (Int?) -> Void  // nil = elimina la chiave (default di sistema)

    public let idleSeconds: Int

    private let read: DefaultsReader
    private let write: DefaultsWriter
    private var savedIdleTime: Int?

    public init(idleSeconds: Int = screensaverIdleSeconds,
                reader: @escaping DefaultsReader = ScreensaverControl.processReader,
                writer: @escaping DefaultsWriter = ScreensaverControl.processWriter) {
        self.idleSeconds = idleSeconds
        self.read = reader
        self.write = writer
    }

    /// Il sistema è già configurato con il nostro idle time?
    public var isActive: Bool {
        currentIdleTime() == idleSeconds
    }

    public func currentIdleTime() -> Int? {
        guard let out = read() else { return nil }
        return Int(out.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Imposta lo screensaver a idleSeconds, salvando il valore precedente.
    public func enable() {
        let current = currentIdleTime()
        if savedIdleTime == nil && current != idleSeconds {
            savedIdleTime = current
        }
        write(idleSeconds)
    }

    /// Ripristina il valore precedente (o il default di sistema se non noto).
    public func disable() {
        if let saved = savedIdleTime {
            write(saved)
        } else {
            write(nil)
        }
        savedIdleTime = nil
    }

    // @usableFromInline (non private): referenziati dai default arguments dell'init public
    @usableFromInline static func processReader() -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        p.arguments = ["-currentHost", "read", "com.apple.screensaver", "idleTime"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }

    @usableFromInline static func processWriter(_ value: Int?) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        if let value {
            p.arguments = ["-currentHost", "write", "com.apple.screensaver", "idleTime",
                           "-int", String(value)]
        } else {
            p.arguments = ["-currentHost", "delete", "com.apple.screensaver", "idleTime"]
        }
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
    }
}
