import Foundation

runCoreTests()
runCaffeinateProcessTests()

print()
if testFailed == 0 {
    print("✅ \(testTotal)/\(testTotal) test superati")
    exit(0)
} else {
    print("❌ \(testFailed) su \(testTotal) test falliti")
    exit(1)
}
