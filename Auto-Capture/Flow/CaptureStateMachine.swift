import Foundation
import OSLog

/// Deterministic state machine for capture flow control
final class CaptureStateMachine: CaptureStateMachineProtocol {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "AutoCapture", category: "StateMachine")
    
    private var _currentState: CaptureState = .idle
    private var _currentViewpoint: Viewpoint?
    private var _sessionProgress: SessionProgress?
    private var _currentSession: CaptureSession?
    
    private let stabilityGate: StabilityGate
    private let viewpointClassifier: ViewpointClassifierProtocol
    private let photoCaptureManager: PhotoCaptureManager
    private let sessionStore: SessionStoreProtocol
    
    // Event handlers
    var onStateChange: ((CaptureState) -> Void)?
    var onProgressUpdate: ((SessionProgress) -> Void)?
    var onError: ((StateMachineError) -> Void)?
    
    // MARK: - Computed Properties
    
    var currentState: CaptureState {
        return _currentState
    }
    
    var currentViewpoint: Viewpoint? {
        return _currentViewpoint
    }
    
    var sessionProgress: SessionProgress {
        return _sessionProgress ?? SessionProgress(
            completedViewpoints: [],
            remainingViewpoints: Viewpoint.allCases,
            currentViewpoint: nil,
            progressPercentage: 0.0,
            estimatedTimeRemaining: nil
        )
    }
    
    // MARK: - Initialization
    
    init(
        stabilityGate: StabilityGate,
        viewpointClassifier: ViewpointClassifierProtocol,
        photoCaptureManager: PhotoCaptureManager,
        sessionStore: SessionStoreProtocol
    ) {
        self.stabilityGate = stabilityGate
        self.viewpointClassifier = viewpointClassifier
        self.photoCaptureManager = photoCaptureManager
        self.sessionStore = sessionStore
    }
    
    // MARK: - Session Control
    
    func startSession(stockNumber: String, settings: SessionSettings) async throws {
        guard _currentState == .idle else {
            throw StateMachineError.invalidStateTransition
        }
        
        logger.info("Starting session for stock number: \(stockNumber)")
        
        // Create new session
        let session = try await sessionStore.createSession(stockNumber: stockNumber)
        _currentSession = session
        
        // Set initial viewpoint
        _currentViewpoint = Viewpoint.first
        
        // Update state
        _currentState = .sessionActive
        _sessionProgress = createSessionProgress(for: session)
        
        // Reset stability gate
        stabilityGate.reset(for: Viewpoint.first)
        
        // Notify state change
        onStateChange?(_currentState)
        onProgressUpdate?(_sessionProgress!)
        
        logger.info("Session started successfully")
    }
    
    func cancelSession() async throws {
        guard _currentState != .idle else {
            throw StateMachineError.invalidStateTransition
        }
        
        logger.info("Cancelling session")
        
        // Update session status
        if var session = _currentSession {
            session.cancel()
            try await sessionStore.saveSession(session)
        }
        
        // Reset state
        _currentState = .cancelled
        _currentViewpoint = nil
        _currentSession = nil
        _sessionProgress = nil
        
        // Reset stability gate
        stabilityGate.reset()
        
        // Notify state change
        onStateChange?(_currentState)
        
        logger.info("Session cancelled")
    }
    
    func completeSession() async throws {
        guard _currentState == .sessionActive else {
            throw StateMachineError.invalidStateTransition
        }
        
        guard let session = _currentSession, session.isComplete else {
            throw StateMachineError.invalidStateTransition
        }
        
        logger.info("Completing session")
        
        // Update session status
        var updatedSession = session
        updatedSession.status = .completed
        updatedSession.completedAt = Date()
        
        try await sessionStore.saveSession(updatedSession)
        _currentSession = updatedSession
        
        // Update state
        _currentState = .completed
        _currentViewpoint = nil
        
        // Notify state change
        onStateChange?(_currentState)
        
        logger.info("Session completed successfully")
    }
    
    // MARK: - Capture Flow
    
    func processClassificationResult(_ result: ClassificationResult) async throws -> CaptureAction {
        guard _currentState == .sessionActive else {
            throw StateMachineError.sessionNotActive
        }
        
        guard let currentViewpoint = _currentViewpoint else {
            throw StateMachineError.invalidViewpoint
        }
        
        // Check if this is the expected viewpoint
        if result.viewpoint != currentViewpoint {
            logger.debug("Unexpected viewpoint: \(result.viewpoint.rawValue), expected: \(currentViewpoint.rawValue)")
            return .wait
        }
        
        // Process with stability gate
        let stabilityState = stabilityGate.processClassificationResult(result)
        
        switch stabilityState {
        case .detecting:
            _currentState = .detecting
            onStateChange?(_currentState)
            return .continue
            
        case .lowConfidence:
            _currentState = .detecting
            onStateChange?(_currentState)
            return .showAdjustmentPrompt
            
        case .stable:
            _currentState = .stable
            onStateChange?(_currentState)
            return .capture
        }
    }
    
    func capturePhoto() async throws -> PhotoCapture {
        guard _currentState == .stable else {
            throw StateMachineError.invalidStateTransition
        }
        
        guard let session = _currentSession,
              let viewpoint = _currentViewpoint else {
            throw StateMachineError.sessionNotActive
        }
        
        logger.info("Capturing photo for viewpoint: \(viewpoint.rawValue)")
        
        // Update state
        _currentState = .capturing
        onStateChange?(_currentState)
        
        do {
            // Capture photo
            let photo = try await photoCaptureManager.capturePhoto(
                for: session,
                viewpoint: viewpoint,
                order: viewpoint.order,
                confidence: 0.85, // Default confidence
                settings: session.settings
            )
            
            // Add photo to session
            var updatedSession = session
            updatedSession.addPhoto(photo)
            try await sessionStore.saveSession(updatedSession)
            _currentSession = updatedSession
            
            // Update progress
            _sessionProgress = createSessionProgress(for: updatedSession)
            onProgressUpdate?(_sessionProgress!)
            
            // Move to next viewpoint or complete
            if let nextViewpoint = viewpoint.next {
                _currentViewpoint = nextViewpoint
                stabilityGate.reset(for: nextViewpoint)
                _currentState = .detecting
            } else {
                _currentState = .completed
                try await completeSession()
            }
            
            onStateChange?(_currentState)
            
            logger.info("Photo captured successfully")
            return photo
            
        } catch {
            _currentState = .error(.captureFailed)
            onStateChange?(_currentState)
            onError?(.captureFailed)
            throw error
        }
    }
    
    func retakePhoto(for viewpoint: Viewpoint) async throws {
        guard _currentState == .sessionActive else {
            throw StateMachineError.invalidStateTransition
        }
        
        guard let session = _currentSession else {
            throw StateMachineError.sessionNotActive
        }
        
        logger.info("Retaking photo for viewpoint: \(viewpoint.rawValue)")
        
        // Update state
        _currentState = .retaking
        onStateChange?(_currentState)
        
        // Find the photo to retake
        guard let photoToRetake = session.photo(for: viewpoint) else {
            throw StateMachineError.viewpointAlreadyCaptured
        }
        
        // Retake photo
        let retakePhoto = try await photoCaptureManager.retakePhoto(
            originalPhoto: photoToRetake,
            newConfidence: 0.85,
            settings: session.settings
        )
        
        // Update session
        var updatedSession = session
        updatedSession.removePhoto(withId: photoToRetake.id)
        updatedSession.addPhoto(retakePhoto)
        try await sessionStore.saveSession(updatedSession)
        _currentSession = updatedSession
        
        // Update progress
        _sessionProgress = createSessionProgress(for: updatedSession)
        onProgressUpdate?(_sessionProgress!)
        
        // Reset stability gate
        stabilityGate.reset(for: viewpoint)
        
        // Return to detecting state
        _currentState = .detecting
        onStateChange?(_currentState)
        
        logger.info("Photo retaken successfully")
    }
    
    func skipViewpoint(_ viewpoint: Viewpoint) async throws {
        guard _currentState == .sessionActive else {
            throw StateMachineError.invalidStateTransition
        }
        
        guard let session = _currentSession else {
            throw StateMachineError.sessionNotActive
        }
        
        logger.info("Skipping viewpoint: \(viewpoint.rawValue)")
        
        // Move to next viewpoint
        if let nextViewpoint = viewpoint.next {
            _currentViewpoint = nextViewpoint
            stabilityGate.reset(for: nextViewpoint)
            _currentState = .detecting
        } else {
            _currentState = .completed
            try await completeSession()
        }
        
        onStateChange?(_currentState)
        
        logger.info("Viewpoint skipped")
    }
    
    // MARK: - State Queries
    
    func canCapture() -> Bool {
        return _currentState == .stable
    }
    
    func canRetake() -> Bool {
        return _currentState == .sessionActive && _currentViewpoint != nil
    }
    
    func canSkip() -> Bool {
        return _currentState == .sessionActive && _currentViewpoint != nil
    }
    
    func isSessionComplete() -> Bool {
        return _currentState == .completed
    }
    
    // MARK: - Helper Methods
    
    private func createSessionProgress(for session: CaptureSession) -> SessionProgress {
        let completedViewpoints = session.photos.map { $0.viewpoint }
        let remainingViewpoints = Viewpoint.allCases.filter { !completedViewpoints.contains($0) }
        let currentViewpoint = _currentViewpoint
        
        let progressPercentage = Float(completedViewpoints.count) / 8.0
        
        // Estimate time remaining (assuming 30 seconds per photo)
        let estimatedTimeRemaining = TimeInterval(remainingViewpoints.count * 30)
        
        return SessionProgress(
            completedViewpoints: completedViewpoints,
            remainingViewpoints: remainingViewpoints,
            currentViewpoint: currentViewpoint,
            progressPercentage: progressPercentage,
            estimatedTimeRemaining: estimatedTimeRemaining
        )
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: StateMachineError) {
        _currentState = .error(error)
        onStateChange?(_currentState)
        onError?(error)
        logger.error("State machine error: \(error.localizedDescription)")
    }
    
    // MARK: - Classification Processing
    
    func processClassification(result: ClassificationResult) async throws -> CaptureAction {
        guard _currentState == .detecting else {
            throw StateMachineError.invalidStateTransition
        }
        
        guard let currentViewpoint = _currentViewpoint else {
            throw StateMachineError.sessionNotActive
        }
        
        logger.debug("Processing classification: \(result.viewpoint.rawValue) (confidence: \(result.confidence))")
        
        // Check if the classification matches the current viewpoint
        if result.viewpoint == currentViewpoint && result.confidence >= 0.8 {
            // Update stability gate
            let stabilityState = stabilityGate.processClassificationResult(result)
            let isStable = stabilityGate.isStable(for: currentViewpoint)
            
            if isStable {
                logger.info("Viewpoint \(currentViewpoint.rawValue) is stable, triggering capture")
                _currentState = .capturing
                onStateChange?(_currentState)
                return .capture
            } else {
                logger.debug("Viewpoint \(currentViewpoint.rawValue) not yet stable")
                return .continue
            }
        } else {
            // Reset stability gate for different viewpoint
            stabilityGate.reset(for: currentViewpoint)
            logger.debug("Classification doesn't match current viewpoint, resetting stability")
            return .continue
        }
    }
}

// MARK: - StateMachineError Extension

extension StateMachineError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidStateTransition:
            return "Invalid state transition"
        case .sessionNotActive:
            return "Session not active"
        case .viewpointAlreadyCaptured:
            return "Viewpoint already captured"
        case .invalidViewpoint:
            return "Invalid viewpoint"
        case .classificationTimeout:
            return "Classification timeout"
        case .captureFailed:
            return "Capture failed"
        }
    }
}
