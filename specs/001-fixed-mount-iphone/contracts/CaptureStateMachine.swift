// CaptureStateMachine.swift - API Contract
// Deterministic state machine for capture flow control

import Foundation

protocol CaptureStateMachineProtocol {
    // State management
    var currentState: CaptureState { get }
    var currentViewpoint: Viewpoint? { get }
    var sessionProgress: SessionProgress { get }
    
    // Session control
    func startSession(stockNumber: String, settings: SessionSettings) async throws
    func cancelSession() async throws
    func completeSession() async throws
    
    // Capture flow
    func processClassification(result: ClassificationResult) async throws -> CaptureAction
    func capturePhoto() async throws -> PhotoCapture
    func retakePhoto(for viewpoint: Viewpoint) async throws
    func skipViewpoint(_ viewpoint: Viewpoint) async throws
    
    // State queries
    func canCapture() -> Bool
    func canRetake() -> Bool
    func canSkip() -> Bool
    func isSessionComplete() -> Bool
    
    // Event handling
    var onStateChange: ((CaptureState) -> Void)? { get set }
    var onProgressUpdate: ((SessionProgress) -> Void)? { get set }
    var onError: ((StateMachineError) -> Void)? { get set }
}

enum CaptureState {
    case idle
    case sessionActive
    case detecting
    case stable
    case capturing
    case retaking
    case completed
    case cancelled
    case error(StateMachineError)
}

struct SessionProgress {
    let completedViewpoints: [Viewpoint]
    let remainingViewpoints: [Viewpoint]
    let currentViewpoint: Viewpoint?
    let progressPercentage: Float
    let estimatedTimeRemaining: TimeInterval?
}

enum CaptureAction {
    case continue
    case capture
    case wait
    case showAdjustmentPrompt
}

enum StateMachineError: Error {
    case invalidStateTransition
    case sessionNotActive
    case viewpointAlreadyCaptured
    case invalidViewpoint
    case classificationTimeout
    case captureFailed
}

// Implementation requirements:
// - Must be deterministic (same inputs = same outputs)
// - Must handle all 8 viewpoints in correct order
// - Must support retake and skip operations
// - Must maintain session integrity
// - Must provide clear state transitions
// - Must handle error recovery
// - Must be thread-safe
// - Must validate all state transitions
