import Foundation
import OSLog

/// Manages stability detection for viewpoint classification
final class StabilityGate {
    
    // MARK: - Properties
    
    private var requiredStabilityFrames: Int
    private var confidenceThreshold: Float
    private let logger = Logger(subsystem: "AutoCapture", category: "StabilityGate")
    
    private var stabilityHistory: [StabilityFrame] = []
    private var currentViewpoint: Viewpoint?
    private var stabilityStartTime: Date?
    
    // MARK: - Initialization
    
    init(
        requiredStabilityFrames: Int = 5,
        confidenceThreshold: Float = 0.85
    ) {
        self.requiredStabilityFrames = requiredStabilityFrames
        self.confidenceThreshold = confidenceThreshold
    }
    
    // MARK: - Stability Detection
    
    func processClassificationResult(_ result: ClassificationResult) -> StabilityState {
        let currentTime = Date()
        
        // Create stability frame
        let frame = StabilityFrame(
            viewpoint: result.viewpoint,
            confidence: result.confidence,
            timestamp: currentTime,
            inferenceTime: result.inferenceTime
        )
        
        // Add to history
        stabilityHistory.append(frame)
        
        // Keep only recent frames (last 10 seconds)
        let cutoffTime = currentTime.addingTimeInterval(-10.0)
        stabilityHistory = stabilityHistory.filter { $0.timestamp > cutoffTime }
        
        // Check if viewpoint changed
        if currentViewpoint != result.viewpoint {
            currentViewpoint = result.viewpoint
            stabilityStartTime = currentTime
            logger.debug("Viewpoint changed to: \(result.viewpoint.rawValue)")
            return .detecting
        }
        
        // Check if confidence meets threshold
        if result.confidence < confidenceThreshold {
            logger.debug("Confidence below threshold: \(result.confidence)")
            return .lowConfidence
        }
        
        // Check stability
        let stableFrames = getStableFrames(for: result.viewpoint)
        
        if stableFrames.count >= requiredStabilityFrames {
            let stabilityDuration = currentTime.timeIntervalSince(stabilityStartTime ?? currentTime)
            logger.info("Stability achieved for \(result.viewpoint.rawValue) after \(stableFrames.count) frames")
            return .stable(duration: stabilityDuration)
        }
        
        return .detecting
    }
    
    private func getStableFrames(for viewpoint: Viewpoint) -> [StabilityFrame] {
        return stabilityHistory.filter { frame in
            frame.viewpoint == viewpoint && frame.confidence >= confidenceThreshold
        }
    }
    
    // MARK: - Stability Queries
    
    func isStable(for viewpoint: Viewpoint) -> Bool {
        let stableFrames = getStableFrames(for: viewpoint)
        return stableFrames.count >= requiredStabilityFrames
    }
    
    func getStabilityProgress(for viewpoint: Viewpoint) -> Float {
        let stableFrames = getStableFrames(for: viewpoint)
        return Float(stableFrames.count) / Float(requiredStabilityFrames)
    }
    
    func getStabilityDuration(for viewpoint: Viewpoint) -> TimeInterval? {
        guard let startTime = stabilityStartTime else { return nil }
        return Date().timeIntervalSince(startTime)
    }
    
    func getCurrentStabilityState() -> StabilityState {
        guard let currentViewpoint = currentViewpoint else { return .detecting }
        return processClassificationResult(
            ClassificationResult(
                viewpoint: currentViewpoint,
                confidence: 0.0,
                inferenceTime: 0.0,
                allConfidences: [:]
            )
        )
    }
    
    // MARK: - Reset
    
    func reset() {
        stabilityHistory.removeAll()
        currentViewpoint = nil
        stabilityStartTime = nil
        logger.debug("Stability gate reset")
    }
    
    func reset(for newViewpoint: Viewpoint) {
        stabilityHistory.removeAll()
        currentViewpoint = newViewpoint
        stabilityStartTime = Date()
        logger.debug("Stability gate reset for viewpoint: \(newViewpoint.rawValue)")
    }
    
    // MARK: - Statistics
    
    func getStabilityStatistics() -> StabilityStatistics {
        let totalFrames = stabilityHistory.count
        let stableFrames = stabilityHistory.filter { $0.confidence >= confidenceThreshold }.count
        let averageConfidence = stabilityHistory.map { $0.confidence }.reduce(0, +) / Float(stabilityHistory.count)
        let averageInferenceTime = stabilityHistory.map { $0.inferenceTime }.reduce(0, +) / Double(stabilityHistory.count)
        
        return StabilityStatistics(
            totalFrames: totalFrames,
            stableFrames: stableFrames,
            averageConfidence: averageConfidence,
            averageInferenceTime: averageInferenceTime,
            stabilityRate: Float(stableFrames) / Float(totalFrames)
        )
    }
    
    // MARK: - Configuration
    
    func updateConfiguration(
        requiredStabilityFrames: Int? = nil,
        confidenceThreshold: Float? = nil
    ) {
        if let frames = requiredStabilityFrames {
            self.requiredStabilityFrames = frames
        }
        if let threshold = confidenceThreshold {
            self.confidenceThreshold = threshold
        }
        
        logger.info("Stability gate configuration updated")
    }
    
    func getConfiguration() -> StabilityConfiguration {
        return StabilityConfiguration(
            requiredStabilityFrames: requiredStabilityFrames,
            confidenceThreshold: confidenceThreshold
        )
    }
}

// MARK: - Supporting Types

struct StabilityFrame {
    let viewpoint: Viewpoint
    let confidence: Float
    let timestamp: Date
    let inferenceTime: TimeInterval
}

enum StabilityState {
    case detecting
    case lowConfidence
    case stable(duration: TimeInterval)
    
    var isStable: Bool {
        switch self {
        case .stable:
            return true
        case .detecting, .lowConfidence:
            return false
        }
    }
    
    var description: String {
        switch self {
        case .detecting:
            return "Detecting viewpoint"
        case .lowConfidence:
            return "Low confidence - adjust position"
        case .stable(let duration):
            return "Stable for \(String(format: "%.1f", duration))s"
        }
    }
}

struct StabilityStatistics {
    let totalFrames: Int
    let stableFrames: Int
    let averageConfidence: Float
    let averageInferenceTime: TimeInterval
    let stabilityRate: Float
}

struct StabilityConfiguration {
    let requiredStabilityFrames: Int
    let confidenceThreshold: Float
}

// MARK: - StabilityGate Extensions

extension StabilityGate {
    
    /// Gets the stability progress as a percentage string
    func getStabilityProgressString(for viewpoint: Viewpoint) -> String {
        let progress = getStabilityProgress(for: viewpoint)
        return String(format: "%.0f%%", progress * 100)
    }
    
    /// Gets the stability duration as a formatted string
    func getStabilityDurationString(for viewpoint: Viewpoint) -> String? {
        guard let duration = getStabilityDuration(for: viewpoint) else { return nil }
        
        if duration < 1.0 {
            return String(format: "%.0f ms", duration * 1000)
        } else {
            return String(format: "%.1f s", duration)
        }
    }
    
    /// Checks if the current viewpoint is ready for capture
    func isReadyForCapture() -> Bool {
        guard let currentViewpoint = currentViewpoint else { return false }
        return isStable(for: currentViewpoint)
    }
    
    /// Gets the time remaining until stability
    func getTimeUntilStability(for viewpoint: Viewpoint) -> TimeInterval? {
        let stableFrames = getStableFrames(for: viewpoint)
        let remainingFrames = requiredStabilityFrames - stableFrames.count
        
        if remainingFrames <= 0 {
            return 0.0
        }
        
        // Estimate based on average frame rate (assuming 30fps)
        let estimatedFrameRate = 30.0
        return Double(remainingFrames) / estimatedFrameRate
    }
    
    /// Gets the stability status description
    func getStabilityStatusDescription(for viewpoint: Viewpoint) -> String {
        let state = processClassificationResult(
            ClassificationResult(
                viewpoint: viewpoint,
                confidence: 0.0,
                inferenceTime: 0.0,
                allConfidences: [:]
            )
        )
        
        switch state {
        case .detecting:
            return "Detecting \(viewpoint.description)..."
        case .lowConfidence:
            return "Adjust position for \(viewpoint.description)"
        case .stable(let duration):
            return "\(viewpoint.description) stable for \(String(format: "%.1f", duration))s"
        }
    }
}
