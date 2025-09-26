import XCTest
@testable import Auto_Capture

final class CaptureStateMachineTests: XCTestCase {
    
    var stateMachine: CaptureStateMachineProtocol!
    
    override func setUpWithError() throws {
        // This will fail initially since CaptureStateMachine doesn't exist yet
        // stateMachine = CaptureStateMachine()
    }
    
    override func tearDownWithError() throws {
        stateMachine = nil
    }
    
    // MARK: - Session Management Tests
    
    func testStartSession() async throws {
        // Given
        guard let stateMachine = stateMachine else {
            XCTFail("StateMachine not initialized - test will fail until implementation")
            return
        }
        
        let stockNumber = "ABC123"
        let settings = SessionSettings()
        
        // When
        try await stateMachine.startSession(stockNumber: stockNumber, settings: settings)
        
        // Then
        XCTAssertEqual(stateMachine.currentState, .sessionActive)
        XCTAssertEqual(stateMachine.currentViewpoint, .frontDriver3rd) // First viewpoint
        XCTAssertFalse(stateMachine.isSessionComplete())
    }
    
    func testCancelSession() async throws {
        // Given
        guard let stateMachine = stateMachine else {
            XCTFail("StateMachine not initialized - test will fail until implementation")
            return
        }
        
        let stockNumber = "ABC123"
        let settings = SessionSettings()
        
        try await stateMachine.startSession(stockNumber: stockNumber, settings: settings)
        
        // When
        try await stateMachine.cancelSession()
        
        // Then
        XCTAssertEqual(stateMachine.currentState, .cancelled)
    }
    
    func testCompleteSession() async throws {
        // Given
        guard let stateMachine = stateMachine else {
            XCTFail("StateMachine not initialized - test will fail until implementation")
            return
        }
        
        let stockNumber = "ABC123"
        let settings = SessionSettings()
        
        try await stateMachine.startSession(stockNumber: stockNumber, settings: settings)
        
        // Simulate capturing all 8 viewpoints
        for _ in 0..<8 {
            _ = try await stateMachine.capturePhoto()
        }
        
        // When
        try await stateMachine.completeSession()
        
        // Then
        XCTAssertEqual(stateMachine.currentState, .completed)
        XCTAssertTrue(stateMachine.isSessionComplete())
    }
    
    // MARK: - State Transition Tests
    
    func testStateTransitions() async throws {
        guard let stateMachine = stateMachine else {
            XCTFail("StateMachine not initialized - test will fail until implementation")
            return
        }
        
        // Initial state
        XCTAssertEqual(stateMachine.currentState, .idle)
        
        // Start session
        let settings = SessionSettings()
        try await stateMachine.startSession(stockNumber: "ABC123", settings: settings)
        XCTAssertEqual(stateMachine.currentState, .sessionActive)
    }
    
    func testInvalidStateTransition() async throws {
        guard let stateMachine = stateMachine else {
            XCTFail("StateMachine not initialized - test will fail until implementation")
            return
        }
        
        // Try to capture photo without starting session
        do {
            _ = try await stateMachine.capturePhoto()
            XCTFail("Should throw error for invalid state transition")
        } catch {
            XCTAssertTrue(error is StateMachineError)
        }
    }
    
    // MARK: - Classification Processing Tests
    
    func testProcessClassification() async throws {
        guard let stateMachine = stateMachine else {
            XCTFail("StateMachine not initialized - test will fail until implementation")
            return
        }
        
        let settings = SessionSettings()
        try await stateMachine.startSession(stockNumber: "ABC123", settings: settings)
        
        // Create mock classification result
        let classificationResult = ClassificationResult(
            viewpoint: .frontDriver3rd,
            confidence: 0.95,
            inferenceTime: 0.1,
            allConfidences: [:]
        )
        
        // When
        let action = try await stateMachine.processClassification(result: classificationResult)
        
        // Then
        XCTAssertTrue([.continue, .capture, .wait, .showAdjustmentPrompt].contains(action))
    }
    
    func testLowConfidenceClassification() async throws {
        guard let stateMachine = stateMachine else {
            XCTFail("StateMachine not initialized - test will fail until implementation")
            return
        }
        
        let settings = SessionSettings()
        try await stateMachine.startSession(stockNumber: "ABC123", settings: settings)
        
        // Create low confidence classification result
        let classificationResult = ClassificationResult(
            viewpoint: .frontDriver3rd,
            confidence: 0.5, // Below threshold
            inferenceTime: 0.1,
            allConfidences: [:]
        )
        
        // When
        let action = try await stateMachine.processClassification(result: classificationResult)
        
        // Then
        XCTAssertEqual(action, .showAdjustmentPrompt)
    }
    
    // MARK: - Progress Tracking Tests
    
    func testSessionProgress() async throws {
        guard let stateMachine = stateMachine else {
            XCTFail("StateMachine not initialized - test will fail until implementation")
            return
        }
        
        let settings = SessionSettings()
        try await stateMachine.startSession(stockNumber: "ABC123", settings: settings)
        
        let progress = stateMachine.sessionProgress
        
        XCTAssertEqual(progress.completedViewpoints.count, 0)
        XCTAssertEqual(progress.remainingViewpoints.count, 8)
        XCTAssertEqual(progress.currentViewpoint, .frontDriver3rd)
        XCTAssertEqual(progress.progressPercentage, 0.0)
    }
    
    func testProgressAfterCapture() async throws {
        guard let stateMachine = stateMachine else {
            XCTFail("StateMachine not initialized - test will fail until implementation")
            return
        }
        
        let settings = SessionSettings()
        try await stateMachine.startSession(stockNumber: "ABC123", settings: settings)
        
        // Capture first photo
        _ = try await stateMachine.capturePhoto()
        
        let progress = stateMachine.sessionProgress
        
        XCTAssertEqual(progress.completedViewpoints.count, 1)
        XCTAssertEqual(progress.remainingViewpoints.count, 7)
        XCTAssertEqual(progress.currentViewpoint, .front)
        XCTAssertEqual(progress.progressPercentage, 0.125) // 1/8
    }
    
    // MARK: - Retake and Skip Tests
    
    func testRetakePhoto() async throws {
        guard let stateMachine = stateMachine else {
            XCTFail("StateMachine not initialized - test will fail until implementation")
            return
        }
        
        let settings = SessionSettings()
        try await stateMachine.startSession(stockNumber: "ABC123", settings: settings)
        
        // Capture first photo
        _ = try await stateMachine.capturePhoto()
        
        // Retake first viewpoint
        try await stateMachine.retakePhoto(for: .frontDriver3rd)
        
        XCTAssertEqual(stateMachine.currentViewpoint, .frontDriver3rd)
        XCTAssertEqual(stateMachine.currentState, .retaking)
    }
    
    func testSkipViewpoint() async throws {
        guard let stateMachine = stateMachine else {
            XCTFail("StateMachine not initialized - test will fail until implementation")
            return
        }
        
        let settings = SessionSettings()
        try await stateMachine.startSession(stockNumber: "ABC123", settings: settings)
        
        // Skip first viewpoint
        try await stateMachine.skipViewpoint(.frontDriver3rd)
        
        XCTAssertEqual(stateMachine.currentViewpoint, .front)
    }
    
    // MARK: - Capability Tests
    
    func testCanCapture() async throws {
        guard let stateMachine = stateMachine else {
            XCTFail("StateMachine not initialized - test will fail until implementation")
            return
        }
        
        // Initially cannot capture
        XCTAssertFalse(stateMachine.canCapture())
        
        let settings = SessionSettings()
        try await stateMachine.startSession(stockNumber: "ABC123", settings: settings)
        
        // After starting session, can capture
        XCTAssertTrue(stateMachine.canCapture())
    }
    
    func testCanRetake() async throws {
        guard let stateMachine = stateMachine else {
            XCTFail("StateMachine not initialized - test will fail until implementation")
            return
        }
        
        let settings = SessionSettings()
        try await stateMachine.startSession(stockNumber: "ABC123", settings: settings)
        
        // Cannot retake before capturing
        XCTAssertFalse(stateMachine.canRetake())
        
        // Capture a photo
        _ = try await stateMachine.capturePhoto()
        
        // Now can retake
        XCTAssertTrue(stateMachine.canRetake())
    }
    
    // MARK: - Event Handling Tests
    
    func testStateChangeCallback() async throws {
        guard let stateMachine = stateMachine else {
            XCTFail("StateMachine not initialized - test will fail until implementation")
            return
        }
        
        let expectation = XCTestExpectation(description: "State change callback")
        
        // Mock implementation - will be replaced with real implementation
        // stateMachine.onStateChange = { state in
        //     XCTAssertEqual(state, .sessionActive)
        //     expectation.fulfill()
        // }
        
        let settings = SessionSettings()
        try await stateMachine.startSession(stockNumber: "ABC123", settings: settings)
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testProgressUpdateCallback() async throws {
        guard let stateMachine = stateMachine else {
            XCTFail("StateMachine not initialized - test will fail until implementation")
            return
        }
        
        let expectation = XCTestExpectation(description: "Progress update callback")
        
        // Mock implementation - will be replaced with real implementation
        // stateMachine.onProgressUpdate = { progress in
        //     XCTAssertGreaterThan(progress.progressPercentage, 0)
        //     expectation.fulfill()
        // }
        
        let settings = SessionSettings()
        try await stateMachine.startSession(stockNumber: "ABC123", settings: settings)
        
        _ = try await stateMachine.capturePhoto()
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
}
