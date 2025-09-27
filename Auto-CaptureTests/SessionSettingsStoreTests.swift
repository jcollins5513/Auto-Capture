import XCTest
@testable import Auto_Capture

@MainActor
final class SessionSettingsStoreTests: XCTestCase {
    private var userDefaults: UserDefaults!
    private var store: SessionSettingsStore!
    private var suiteName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "SessionSettingsStoreTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create UserDefaults suite")
            return
        }
        userDefaults = defaults
        userDefaults.removePersistentDomain(forName: suiteName)
        store = SessionSettingsStore(userDefaults: userDefaults)
    }

    override func tearDownWithError() throws {
        store = nil
        if let suiteName = suiteName {
            userDefaults?.removePersistentDomain(forName: suiteName)
        }
        userDefaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    func testLoadSettingsReturnsDefaultWhenEmpty() {
        let loaded = store.loadSettings()
        XCTAssertEqual(loaded, .default)
    }

    func testSaveAndLoadSettingsRoundTrips() throws {
        let custom = SessionSettings(
            stabilityFrames: 6,
            confidenceThreshold: 0.92,
            shutterDelay: 0.8,
            lockExposure: false,
            jpegQuality: 0.85,
            guideOpacity: 0.5,
            voicePrompts: false,
            exportTarget: .files,
            thermalThreshold: 0.6
        )

        try store.saveSettings(custom)

        let reloaded = store.loadSettings()
        XCTAssertEqual(reloaded, custom)
    }

    func testSavingInvalidSettingsThrows() {
        let invalid = SessionSettings(
            stabilityFrames: 0,
            confidenceThreshold: 0.3,
            shutterDelay: 6.0,
            lockExposure: true,
            jpegQuality: 0.05,
            guideOpacity: -0.1,
            voicePrompts: true,
            exportTarget: .shareSheet,
            thermalThreshold: 1.2
        )

        XCTAssertThrowsError(try store.saveSettings(invalid)) { error in
            guard case SessionSettingsStoreError.invalidSettings = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testResetSettingsClearsStoredValues() throws {
        let custom = SessionSettings(
            stabilityFrames: 7,
            confidenceThreshold: 0.9,
            shutterDelay: 0.7,
            lockExposure: true,
            jpegQuality: 0.95,
            guideOpacity: 0.8,
            voicePrompts: true,
            exportTarget: .shareSheet,
            thermalThreshold: 0.7
        )

        try store.saveSettings(custom)
        try store.resetSettings()

        XCTAssertEqual(store.loadSettings(), .default)
    }
}
