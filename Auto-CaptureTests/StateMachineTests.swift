import XCTest
@testable import Auto_Capture

final class StateMachineTests: XCTestCase {
    
    // MARK: - State Transition Tests
    
    func testInitialState() {
        // Given
        let stateMachine = createTestStateMachine()
        
        // When & Then
        XCTAssertEqual(stateMachine.currentState, .idle)
        XCTAssertNil(stateMachine.currentViewpoint)
        XCTAssertEqual(stateMachine.sessionProgress.completedViewpoints.count, 0)
        XCTAssertEqual(stateMachine.sessionProgress.remainingViewpoints.count, 8)
    }
    
    func testSessionStartStateTransition() async throws {
        // Given
        let stateMachine = createTestStateMachine()
        let stockNumber = "ABC123"
        let settings = SessionSettings()
        
        // When
        try await stateMachine.startSession(stockNumber: stockNumber, settings: settings)
        
        // Then
        XCTAssertEqual(stateMachine.currentState, .sessionActive)
        XCTAssertEqual(stateMachine.currentViewpoint, .frontDriver3rd)
        XCTAssertTrue(stateMachine.canCapture())
        XCTAssertFalse(stateMachine.canRetake())
        XCTAssertTrue(stateMachine.canSkip())
    }
    
    func testDetectionStateTransition() async throws {
        // Given
        let stateMachine = createTestStateMachine()
        let settings = SessionSettings()
        try await stateMachine.startSession(stockNumber: "ABC123", settings: settings)
        
        // When
        let classificationResult = ClassificationResult(
            viewpoint: .frontDriver3rd,
            confidence: 0.85,
            inferenceTime: 0.1,
            allConfidences: [.frontDriver3rd: 0.85]
        )
        
        let action = try await stateMachine.processClassification(result: classificationResult)
        
        // Then
        XCTAssertEqual(action, .continue)
        XCTAssertEqual(stateMachine.currentState, .detecting)
    }
    
    func testStableStateTransition() async throws {
        // Given
        let stateMachine = createTestStateMachine()
        let settings = SessionSettings()
        try await stateMachine.startSession(stockNumber: "ABC123", settings: settings)
        
        // Send multiple high-confidence classifications for stability
        for _ in 0..<5 { // Stability frames = 5
            let classificationResult = ClassificationResult(
                viewpoint: .frontDriver3rd,
                confidence: 0.95,
                inferenceTime: 0.1,
                allConfidences: [.frontDriver3rd: 0.95]
            )
            
            _ = try await stateMachine.processClassification(result: classificationResult)
        }
        
        // Then
        XCTAssertEqual(stateMachine.currentState, .stable)
    }
    
    func testCaptureStateTransition() async throws {
        // Given
        let stateMachine = createTestStateMachine()
        let settings = SessionSettings()
        try await stateMachine.startSession(stockNumber: "ABC123", settings: settings)
        
        // Trigger stable state first
        for _ in 0..<5 {
            let classificationResult = ClassificationResult(
                viewpoint: .frontDriver3rd,
                confidence: 0.95,
                inferenceTime: 0.1,
                allConfidences: [.frontDriver3rd: 0.95]
            )
            
            _ = try await stateMachine.processClassification(result: classificationResult)
        }
        
        // When
        let photo = try await stateMachine.capturePhoto()
        
        // Then
        XCTAssertEqual(stateMachine.currentState, .capturing)
        XCTAssertEqual(photo.viewpoint, .frontDriver3rd)
        XCTAssertEqual(photo.order, 1)
        XCTAssertTrue(photo.confidence > 0.9)
    }
    
    func testViewpointProgression() async throws {
        // Given
        let stateMachine = createTestStateMachine()
        let settings = SessionSettings()
        try await stateMachine.startSession(stockNumber: "ABC123", settings: settings)
        
        let expectedProgression: [Viewpoint] = [
            .frontDriver3rd, .front, .frontPassenger3rd, .sidePassenger,
            .backPassenger3rd, .back, .backDriver3rd, .sideDriver
        ]
        
        // When & Then
        for (index, expectedViewpoint) in expectedProgression.enumerated() {
            XCTAssertEqual(stateMachine.currentViewpoint, expectedViewpoint)
            
            // Capture photo to advance to next viewpoint
            _ = try await stateMachine.capturePhoto()
            
            let progress = stateMachine.sessionProgress
            XCTAssertEqual(progress.completedViewpoints.count, index + 1)
            XCTAssertEqual(progress.remainingViewpoints.count, 8 - index - 1)
            
            if index < 7 {
                XCTAssertEqual(progress.currentViewpoint, expectedProgression[index + 1])
            }
        }
    }
    
    func testSessionCompletion() async throws {
        // Given
        let stateMachine = createTestStateMachine()
        let settings = SessionSettings()
        try await stateMachine.startSession(stockNumber: "ABC123", settings: settings)
        
        // Capture all 8 viewpoints
        for _ in 0..<8 {
            _ = try await stateMachine.capturePhoto()
        }
        
        // When
        try await stateMachine.completeSession()
        
        // Then
        XCTAssertEqual(stateMachine.currentState, .completed)
        XCTAssertTrue(stateMachine.isSessionComplete())
        XCTAssertNil(stateMachine.currentViewpoint)
        
        let progress = stateMachine.sessionProgress
        XCTAssertEqual(progress.completedViewpoints.count, 8)
        XCTAssertEqual(progress.remainingViewpoints.count, 0)
        XCTAssertEqual(progress.progressPercentage, 1.0)
    }
    
    // MARK: - Retake Functionality Tests
    
    func testRetakeFirstViewpoint() async throws {
        // Given
        let stateMachine = createTestStateMachine()
        let settings = SessionSettings()
        try await stateMachine.startSession(stockNumber: "ABC123", settings: settings)
        
        // Capture first photo
        _ = try await stateMachine.capturePhoto()
        XCTAssertEqual(stateMachine.currentViewpoint, .front)
        
        // When
        try await stateMachine.retakePhoto(for: .frontDriver3rd)
        
        // Then
        XCTAssertEqual(stateMachine.currentState, .retaking)
        XCTAssertEqual(stateMachine.currentViewpoint, .frontDriver3rd)
        XCTAssertTrue(stateMachine.canCapture())
    }
    
    func testRetakeLastViewpoint() async throws {
        // Given
        let stateMachine = createTestStateMachine()
        let settings = SessionSettings()
        try await stateMachine.startSession(stockNumber: "ABC123", settings: settings)
        
        // Capture all viewpoints
        for _ in 0..<8 {
            _ = try await stateMachine.capturePhoto()
        }
        
        // When
        try await stateMachine.retakePhoto(for: .sideDriver)
        
        // Then
        XCTAssertEqual(stateMachine.currentState, .retaking)
        XCTAssertEqual(stateMachine.currentViewpoint, .sideDriver)
        XCTAssertTrue(stateMachine.canCapture())
    }
    
    func testRetakeMiddleViewpoint() async throws {
        // Given
        let stateMachine = createTestStateMachine()
        let settings = SessionSettings()
        try await stateMachine.startSession(stockNumber: "ABC123", settings: settings)
        
        // Capture first 4 viewpoints
        for _ in 0..<4 {
            _ = try await stateMachine.capturePhoto()
        }
        XCTAssertEqual(stateMachine.currentViewpoint, .backPassenger3rd)
        
        // When
        try await stateMachine.retakePhoto(for: .sidePassenger)
        
        // Then
        XCTAssertEqual(stateMachine.currentState, .retaking)
        XCTAssertEqual(stateMachine.currentViewpoint, .sidePassenger)
    }
    
    // MARK: - Skip Functionality Tests
    
    func testSkipFirstViewpoint() async throws {
        // Given
        let stateMachine = createTestStateMachine()
        let settings = SessionSettings()
        try await stateMachine.startSession(stockNumber: "ABC123", settings: settings)
        XCTAssertEqual(stateMachine.currentViewpoint, .frontDriver3rd)
        
        // When
        try await stateMachine.skipViewpoint(.frontDriver3rd)
        
        // Then
        XCTAssertEqual(stateMachine.currentViewpoint, .front)
        let progress = stateMachine.sessionProgress
        XCTAssertEqual(progress.completedViewpoints.count, 0) // Skipped, not completed
        XCTAssertEqual(progress.remainingViewpoints.count, 7)
    }
    
    func testSkipMultipleViewpoints() async throws {
        // Given
        let stateMachine = createTestStateMachine()
        let settings = SessionSettings()
        try await stateMachine.startSession(stockNumber: "ABC123", settings: settings)
        
        // When
        try await stateMachine.skipViewpoint(.frontDriver3rd)
        try await stateMachine.skipViewpoint(.front)
        
        // Then
        XCTAssertEqual(stateMachine.currentViewpoint, .frontPassenger3rd)
        let progress = stateMachine.sessionProgress
        XCTAssertEqual(progress.completedViewpoints.count, 0)
        XCTAssertEqual(progress.remainingViewpoints.count, 6)
    }
    
    // MARK: - Low Confidence Tests
    
    func testLowConfidenceClassification() async throws {
        // Given
        let stateMachine = createTestStateMachine()
        let settings = SessionSettings()
        try await stateMachine.startSession(stockNumber: "ABC123", settings: settings)
        
        // When
        let classificationResult = ClassificationResult(
            viewpoint: .frontDriver3rd,
            confidence: 0.5, // Below threshold
            inferenceTime: 0.1,
            allConfidences: [.frontDriver3rd: 0.5]
        )
        
        let action = try await stateMachine.processClassification(result: classificationResult)
        
        // Then
        XCTAssertEqual(action, .showAdjustmentPrompt)
        XCTAssertNotEqual(stateMachine.currentState, .stable)
    }
    
    func testWrongViewpointClassification() async throws {
        // Given
        let stateMachine = createTestStateMachine()
        let settings = SessionSettings()
        try await stateMachine.startSession(stockNumber: "ABC123", settings: settings)
        XCTAssertEqual(stateMachine.currentViewpoint, .frontDriver3rd)
        
        // When
        let classificationResult = ClassificationResult(
            viewpoint: .front, // Wrong viewpoint
            confidence: 0.95,
            inferenceTime: 0.1,
            allConfidences: [.front: 0.95]
        )
        
        let action = try await stateMachine.processClassification(result: classificationResult)
        
        // Then
        XCTAssertEqual(action, .wait)
        XCTAssertNotEqual(stateMachine.currentState, .stable)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidStateTransition() async throws {
        // Given
        let stateMachine = createTestStateMachine()
        
        // When & Then
        do {
            _ = try await stateMachine.capturePhoto()
            XCTFail("Should throw error when trying to capture without active session")
        } catch {
            XCTAssertTrue(error is StateMachineError)
        }
    }
    
    func testSessionCancellation() async throws {
        // Given
        let stateMachine = createTestStateMachine()
        let settings = SessionSettings()
        try await stateMachine.startSession(stockNumber: "ABC123", settings: settings)
        
        // When
        try await stateMachine.cancelSession()
        
        // Then
        XCTAssertEqual(stateMachine.currentState, .cancelled)
        XCTAssertFalse(stateMachine.canCapture())
        XCTAssertFalse(stateMachine.canRetake())
        XCTAssertFalse(stateMachine.canSkip())
    }
    
    // MARK: - Progress Tracking Tests
    
    func testProgressPercentageCalculation() async throws {
        // Given
        let stateMachine = createTestStateMachine()
        let settings = SessionSettings()
        try await stateMachine.startSession(stockNumber: "ABC123", settings: settings)
        
        // When & Then
        for i in 0..<8 {
            let progress = stateMachine.sessionProgress
            let expectedPercentage = Float(i) / 8.0
            XCTAssertEqual(progress.progressPercentage, expectedPercentage, accuracy: 0.01)
            
            if i < 7 {
                _ = try await stateMachine.capturePhoto()
            }
        }
    }
    
    func testProgressCallback() async throws {
        // Given
        let stateMachine = createTestStateMachine()
        let settings = SessionSettings()
        try await stateMachine.startSession(stockNumber: "ABC123", settings: settings)
        
        let expectation = XCTestExpectation(description: "Progress update callback")
        
        stateMachine.onProgressUpdate = { progress in
            XCTAssertGreaterThan(progress.progressPercentage, 0)
            expectation.fulfill()
        }
        
        // When
        _ = try await stateMachine.capturePhoto()
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestStateMachine() -> CaptureStateMachineProtocol {
        // This will fail until implementation
        return MockStateMachine()
    }
}

// Mock implementation for testing (will be replaced with real implementation)
private class MockStateMachine: CaptureStateMachineProtocol {
    var currentState: CaptureState = .idle
    var currentViewpoint: Viewpoint? = nil
    var sessionProgress: SessionProgress = SessionProgress(
        completedViewpoints: [],
        remainingViewpoints: [],
        currentViewpoint: nil,
        progressPercentage: 0.0,
        estimatedTimeRemaining: nil
    )
    var currentSession: CaptureSession? = nil
    
    var onStateChange: ((CaptureState) -> Void)? = nil
    var onProgressUpdate: ((SessionProgress) -> Void)? = nil
    var onError: ((StateMachineError) -> Void)? = nil
    
    func startSession(stockNumber: String, settings: SessionSettings) async throws {
        // Mock implementation - will be replaced with real implementation
        throw StateMachineError.sessionNotActive
    }
    
    func cancelSession() async throws {
        // Mock implementation - will be replaced with real implementation
        throw StateMachineError.sessionNotActive
    }
    
    func completeSession() async throws {
        // Mock implementation - will be replaced with real implementation
        throw StateMachineError.sessionNotActive
    }
    
    func processClassification(result: ClassificationResult) async throws -> CaptureAction {
        // Mock implementation - will be replaced with real implementation
        throw StateMachineError.sessionNotActive
    }
    
    func capturePhoto() async throws -> PhotoCapture {
        // Mock implementation - will be replaced with real implementation
        throw StateMachineError.sessionNotActive
    }
    
    func retakePhoto(for viewpoint: Viewpoint) async throws {
        // Mock implementation - will be replaced with real implementation
        throw StateMachineError.sessionNotActive
    }
    
    func skipViewpoint(_ viewpoint: Viewpoint) async throws {
        // Mock implementation - will be replaced with real implementation
        throw StateMachineError.sessionNotActive
    }
    
    func canCapture() -> Bool {
        // Mock implementation - will be replaced with real implementation
        return false
    }
    
    func canRetake() -> Bool {
        // Mock implementation - will be replaced with real implementation
        return false
    }
    
    func canSkip() -> Bool {
        // Mock implementation - will be replaced with real implementation
        return false
    }
    
    func isSessionComplete() -> Bool {
        // Mock implementation - will be replaced with real implementation
        return false
    }
}
