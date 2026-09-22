import Foundation

var testTotal = 0
var testFailed = 0

struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

func runTest(_ name: String, _ body: () throws -> Void) {
    testTotal += 1
    do {
        try body()
        print("✓ \(name)")
    } catch {
        testFailed += 1
        print("✗ \(name) — \(error)")
    }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "") throws {
    let prefix = message.isEmpty ? "" : "\(message): "
    guard actual == expected else {
        throw TestFailure("\(prefix)atteso \(expected), avuto \(actual)")
    }
}

func expectNil(_ value: Any?, _ message: String = "") throws {
    let prefix = message.isEmpty ? "" : "\(message): "
    guard value == nil else {
        throw TestFailure("\(prefix)atteso nil, avuto \(String(describing: value))")
    }
}

func expectTrue(_ condition: Bool, _ message: String = "") throws {
    let prefix = message.isEmpty ? "" : "\(message): "
    guard condition else { throw TestFailure("\(prefix)atteso true") }
}

func expectFalse(_ condition: Bool, _ message: String = "") throws {
    let prefix = message.isEmpty ? "" : "\(message): "
    guard !condition else { throw TestFailure("\(prefix)atteso false") }
}
