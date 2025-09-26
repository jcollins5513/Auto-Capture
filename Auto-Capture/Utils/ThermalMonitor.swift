import Foundation
import OSLog

/// Monitors device thermal state and manages performance throttling
final class ThermalMonitor {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "AutoCapture", category: "ThermalMonitor")
    private let processInfo = ProcessInfo.processInfo
    
    private var _currentThermalState: ProcessInfo.ThermalState
    private var _isThrottling = false
    private var _throttleLevel: ThrottleLevel = .none
    
    // Event handlers
    var onThermalStateChange: ((ProcessInfo.ThermalState) -> Void)?
    var onThrottlingStart: (() -> Void)?
    var onThrottlingEnd: (() -> Void)?
    
    // MARK: - Computed Properties
    
    var currentThermalState: ProcessInfo.ThermalState {
        return _currentThermalState
    }
    
    var isThrottling: Bool {
        return _isThrottling
    }
    
    var throttleLevel: ThrottleLevel {
        return _throttleLevel
    }
    
    // MARK: - Initialization
    
    init() {
        _currentThermalState = processInfo.thermalState
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Monitoring
    
    private func startMonitoring() {
        // Monitor thermal state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateDidChange),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
        
        logger.info("Thermal monitoring started")
    }
    
    private func stopMonitoring() {
        NotificationCenter.default.removeObserver(self)
        logger.info("Thermal monitoring stopped")
    }
    
    @objc private func thermalStateDidChange() {
        let newState = processInfo.thermalState
        
        if newState != _currentThermalState {
            _currentThermalState = newState
            logger.info("Thermal state changed to: \(newState.rawValue)")
            
            // Update throttling based on thermal state
            updateThrottling()
            
            // Notify observers
            onThermalStateChange?(newState)
        }
    }
    
    // MARK: - Throttling Management
    
    private func updateThrottling() {
        let previousThrottling = _isThrottling
        let previousLevel = _throttleLevel
        
        switch _currentThermalState {
        case .nominal, .fair:
            _isThrottling = false
            _throttleLevel = .none
            
        case .serious:
            _isThrottling = true
            _throttleLevel = .moderate
            
        case .critical:
            _isThrottling = true
            _throttleLevel = .aggressive
            
        @unknown default:
            _isThrottling = false
            _throttleLevel = .none
        }
        
        // Notify observers of throttling changes
        if _isThrottling && !previousThrottling {
            logger.warning("Thermal throttling started at level: \(self._throttleLevel)")
            onThrottlingStart?()
        } else if !_isThrottling && previousThrottling {
            logger.info("Thermal throttling ended")
            onThrottlingEnd?()
        } else if _throttleLevel != previousLevel {
            logger.info("Thermal throttling level changed to: \(self._throttleLevel)")
        }
    }
    
    // MARK: - Performance Management
    
    func getRecommendedSettings() -> ThermalSettings {
        switch _throttleLevel {
        case .none:
            return ThermalSettings(
                inferenceThrottle: 1.0,
                previewFrameRate: 30.0,
                captureQuality: 0.9,
                processingDelay: 0.0
            )
        case .moderate:
            return ThermalSettings(
                inferenceThrottle: 0.5,
                previewFrameRate: 24.0,
                captureQuality: 0.8,
                processingDelay: 0.1
            )
        case .aggressive:
            return ThermalSettings(
                inferenceThrottle: 0.25,
                previewFrameRate: 15.0,
                captureQuality: 0.7,
                processingDelay: 0.2
            )
        }
    }
    
    func shouldThrottleInference() -> Bool {
        return _isThrottling
    }
    
    func getInferenceThrottleFactor() -> Double {
        return getRecommendedSettings().inferenceThrottle
    }
    
    func shouldReducePreviewFrameRate() -> Bool {
        return _isThrottling
    }
    
    func getRecommendedFrameRate() -> Double {
        return getRecommendedSettings().previewFrameRate
    }
    
    func shouldReduceCaptureQuality() -> Bool {
        return _isThrottling
    }
    
    func getRecommendedCaptureQuality() -> Float {
        return getRecommendedSettings().captureQuality
    }
    
    func getProcessingDelay() -> TimeInterval {
        return getRecommendedSettings().processingDelay
    }
    
    // MARK: - Thermal State Queries
    
    func isThermalStateNormal() -> Bool {
        return _currentThermalState == .nominal
    }
    
    func isThermalStateFair() -> Bool {
        return _currentThermalState == .fair
    }
    
    func isThermalStateSerious() -> Bool {
        return _currentThermalState == .serious
    }
    
    func isThermalStateCritical() -> Bool {
        return _currentThermalState == .critical
    }
    
    func getThermalStateDescription() -> String {
        switch _currentThermalState {
        case .nominal:
            return "Normal"
        case .fair:
            return "Fair"
        case .serious:
            return "Serious"
        case .critical:
            return "Critical"
        @unknown default:
            return "Unknown"
        }
    }
    
    func getThermalStateColor() -> String {
        switch _currentThermalState {
        case .nominal:
            return "green"
        case .fair:
            return "yellow"
        case .serious:
            return "orange"
        case .critical:
            return "red"
        @unknown default:
            return "gray"
        }
    }
    
    // MARK: - Thermal Statistics
    
    func getThermalStatistics() -> ThermalStatistics {
        return ThermalStatistics(
            currentState: _currentThermalState,
            isThrottling: _isThrottling,
            throttleLevel: _throttleLevel,
            recommendedSettings: getRecommendedSettings()
        )
    }
    
    func getThermalStatusDescription() -> String {
        if _isThrottling {
            return "Thermal throttling active (\(_throttleLevel.description))"
        } else {
            return "Thermal state: \(getThermalStateDescription())"
        }
    }
    
    // MARK: - Thermal Recovery
    
    func waitForThermalRecovery() async -> Bool {
        let startTime = Date()
        let timeout: TimeInterval = 60.0 // 1 minute timeout
        
        while _currentThermalState != .nominal && _currentThermalState != .fair {
            if Date().timeIntervalSince(startTime) > timeout {
                logger.warning("Thermal recovery timeout")
                return false
            }
            
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        logger.info("Thermal recovery completed")
        return true
    }
    
    func forceThermalRecovery() async {
        logger.info("Forcing thermal recovery")
        
        // Reduce all performance settings to minimum
        let minimalSettings = ThermalSettings(
            inferenceThrottle: 0.1,
            previewFrameRate: 10.0,
            captureQuality: 0.5,
            processingDelay: 0.5
        )
        
        // Apply minimal settings
        applyThermalSettings(minimalSettings)
        
        // Wait for recovery
        _ = await waitForThermalRecovery()
    }
    
    private func applyThermalSettings(_ settings: ThermalSettings) {
        // TODO: Apply thermal settings to relevant components
        logger.info("Applied thermal settings: \(settings)")
    }
}

// MARK: - Supporting Types

enum ThrottleLevel: CustomStringConvertible {
    case none
    case moderate
    case aggressive
    
    var description: String {
        switch self {
        case .none:
            return "None"
        case .moderate:
            return "Moderate"
        case .aggressive:
            return "Aggressive"
        }
    }
}

struct ThermalSettings: CustomStringConvertible {
    let inferenceThrottle: Double
    let previewFrameRate: Double
    let captureQuality: Float
    let processingDelay: TimeInterval
    
    var description: String {
        return "ThermalSettings(inferenceThrottle: \(inferenceThrottle), previewFrameRate: \(previewFrameRate), captureQuality: \(captureQuality), processingDelay: \(processingDelay))"
    }
}

struct ThermalStatistics {
    let currentState: ProcessInfo.ThermalState
    let isThrottling: Bool
    let throttleLevel: ThrottleLevel
    let recommendedSettings: ThermalSettings
}

// MARK: - ThermalMonitor Extensions

extension ThermalMonitor {
    
    /// Gets the thermal state as a percentage (0.0 = nominal, 1.0 = critical)
    func getThermalStatePercentage() -> Float {
        switch _currentThermalState {
        case .nominal:
            return 0.0
        case .fair:
            return 0.33
        case .serious:
            return 0.66
        case .critical:
            return 1.0
        @unknown default:
            return 0.0
        }
    }
    
    /// Gets the thermal state as a temperature value
    func getThermalStateTemperature() -> Float {
        let percentage = getThermalStatePercentage()
        // Convert to temperature (0.0 = 0°C, 1.0 = 100°C)
        return percentage * 100.0
    }
    
    /// Gets the thermal state temperature as a string
    func getThermalStateTemperatureString() -> String {
        let temperature = getThermalStateTemperature()
        return String(format: "%.0f°C", temperature)
    }
    
    /// Checks if the device is overheating
    func isOverheating() -> Bool {
        return _currentThermalState == .critical
    }
    
    /// Checks if the device is getting warm
    func isGettingWarm() -> Bool {
        return _currentThermalState == .serious || _currentThermalState == .critical
    }
    
    /// Gets the recommended action based on thermal state
    func getRecommendedAction() -> String {
        switch _currentThermalState {
        case .nominal:
            return "Normal operation"
        case .fair:
            return "Monitor temperature"
        case .serious:
            return "Reduce usage intensity"
        case .critical:
            return "Stop intensive operations"
        @unknown default:
            return "Unknown state"
        }
    }
}
