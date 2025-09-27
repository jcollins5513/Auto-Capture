import XCTest
@testable import Auto_Capture

/// Latency tests currently require live camera + ML pipeline; skipped in CI.
@MainActor
final class LatencyTests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        throw XCTSkip("Latency measurements rely on device hardware and are skipped in this environment.")
    }
}
