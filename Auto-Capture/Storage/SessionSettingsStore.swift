import Foundation
import OSLog

/// Persists session settings using UserDefaults
@MainActor
protocol SessionSettingsStoreProtocol: AnyObject {
    func loadSettings() -> SessionSettings
    func saveSettings(_ settings: SessionSettings) throws
    func resetSettings() throws
}

enum SessionSettingsStoreError: Error, LocalizedError {
    case invalidSettings
    case encodingFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidSettings:
            return "Settings are out of the allowed range."
        case .encodingFailed(let underlying):
            return "Failed to encode settings: \(underlying.localizedDescription)"
        }
    }
}

@MainActor
final class SessionSettingsStore: SessionSettingsStoreProtocol {
    private enum Constants {
        static let settingsKey = "com.autocapture.sessionSettings"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let logger = Logger(subsystem: "AutoCapture", category: "SessionSettingsStore")

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
    }

    func loadSettings() -> SessionSettings {
        guard let data = defaults.data(forKey: Constants.settingsKey) else {
            return .default
        }

        do {
            let settings = try decoder.decode(SessionSettings.self, from: data)
            if settings.isValid {
                return settings
            } else {
                logger.warning("Loaded settings failed validation; reverting to defaults")
                return .default
            }
        } catch {
            logger.error("Failed to decode settings: \(error.localizedDescription)")
            return .default
        }
    }

    func saveSettings(_ settings: SessionSettings) throws {
        guard settings.isValid else {
            logger.error("Attempted to save invalid settings")
            throw SessionSettingsStoreError.invalidSettings
        }

        do {
            let data = try encoder.encode(settings)
            defaults.set(data, forKey: Constants.settingsKey)
            defaults.synchronize()
            logger.info("Settings saved")
        } catch {
            logger.error("Encoding settings failed: \(error.localizedDescription)")
            throw SessionSettingsStoreError.encodingFailed(underlying: error)
        }
    }

    func resetSettings() throws {
        defaults.removeObject(forKey: Constants.settingsKey)
        defaults.synchronize()
        logger.info("Settings reset to defaults")
    }
}
