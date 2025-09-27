import XCTest
@testable import Auto_Capture

/// Placeholder for performance validation that requires instrumented hardware.
@MainActor
final class PerformanceTests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        throw XCTSkip("Performance suite requires hardware counters; skipped in CI.")
    }
}
