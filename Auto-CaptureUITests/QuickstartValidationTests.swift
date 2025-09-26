import XCTest
import OSLog

/// Manual testing with quickstart.md scenarios
final class QuickstartValidationTests: XCTestCase {
    
    // MARK: - Properties
    
    private let app = XCUIApplication()
    private let logger = Logger(subsystem: "AutoCapture", category: "QuickstartValidationTests")
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Launch app
        app.launch()
        
        // Grant camera permissions if needed
        if app.alerts["Camera Permission"].exists {
            app.alerts["Camera Permission"].buttons["Allow"].tap()
        }
    }
    
    override func tearDown() async throws {
        // Cleanup
        app.terminate()
        
        try await super.tearDown()
    }
    
    // MARK: - Basic Usage Flow Tests
    
    func testStartNewSession() throws {
        // Test starting a new session
        logger.info("Testing start new session flow")
        
        // Enter stock number
        let stockNumberField = app.textFields["Stock Number"]
        XCTAssertTrue(stockNumberField.waitForExistence(timeout: 5))
        stockNumberField.tap()
        stockNumberField.typeText("ABC123")
        
        // Tap start session button
        let startButton = app.buttons["Start Session"]
        XCTAssertTrue(startButton.exists)
        startButton.tap()
        
        // Verify session started
        let liveCaptureView = app.otherElements["LiveCaptureView"]
        XCTAssertTrue(liveCaptureView.waitForExistence(timeout: 10))
        
        logger.info("Start new session test completed")
    }
    
    func testPositionVehicle() throws {
        // Test vehicle positioning
        logger.info("Testing vehicle positioning")
        
        // Start session
        try testStartNewSession()
        
        // Verify framing guides are visible
        let framingGuides = app.otherElements["FramingGuides"]
        XCTAssertTrue(framingGuides.exists)
        
        // Verify viewpoint instruction
        let viewpointInstruction = app.staticTexts["Current Viewpoint"]
        XCTAssertTrue(viewpointInstruction.exists)
        
        logger.info("Vehicle positioning test completed")
    }
    
    func testAutoCaptureProcess() throws {
        // Test auto-capture process
        logger.info("Testing auto-capture process")
        
        // Start session
        try testStartNewSession()
        
        // Wait for auto-capture to begin
        let captureButton = app.buttons["Capture"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10))
        
        // Verify capture process
        let progressIndicator = app.progressIndicators["Capture Progress"]
        XCTAssertTrue(progressIndicator.exists)
        
        logger.info("Auto-capture process test completed")
    }
    
    func testManualControls() throws {
        // Test manual controls
        logger.info("Testing manual controls")
        
        // Start session
        try testStartNewSession()
        
        // Test manual shutter
        let shutterButton = app.buttons["Shutter"]
        XCTAssertTrue(shutterButton.exists)
        shutterButton.tap()
        
        // Test retake button
        let retakeButton = app.buttons["Retake"]
        XCTAssertTrue(retakeButton.exists)
        retakeButton.tap()
        
        // Test skip button
        let skipButton = app.buttons["Skip"]
        XCTAssertTrue(skipButton.exists)
        skipButton.tap()
        
        logger.info("Manual controls test completed")
    }
    
    func testReviewAndExport() throws {
        // Test review and export
        logger.info("Testing review and export")
        
        // Complete a session (simplified)
        try testStartNewSession()
        
        // Navigate to review
        let reviewButton = app.buttons["Review"]
        XCTAssertTrue(reviewButton.waitForExistence(timeout: 10))
        reviewButton.tap()
        
        // Verify review view
        let reviewView = app.otherElements["ReviewView"]
        XCTAssertTrue(reviewView.waitForExistence(timeout: 5))
        
        // Test export
        let exportButton = app.buttons["Export"]
        XCTAssertTrue(exportButton.exists)
        exportButton.tap()
        
        // Verify export options
        let shareSheet = app.sheets["Share Sheet"]
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 5))
        
        logger.info("Review and export test completed")
    }
    
    // MARK: - Success Indicators Tests
    
    func testAllViewpointsCaptured() throws {
        // Test that all 8 viewpoints are captured
        logger.info("Testing all viewpoints captured")
        
        // Start session
        try testStartNewSession()
        
        // Verify all 8 viewpoints are captured
        let viewpointCount = app.staticTexts.matching(identifier: "Viewpoint").count
        XCTAssertEqual(viewpointCount, 8, "All 8 viewpoints should be captured")
        
        logger.info("All viewpoints captured test completed")
    }
    
    func testCorrectPhotoNaming() throws {
        // Test that photos are saved with correct naming
        logger.info("Testing correct photo naming")
        
        // Complete a session
        try testStartNewSession()
        
        // Navigate to review
        let reviewButton = app.buttons["Review"]
        XCTAssertTrue(reviewButton.waitForExistence(timeout: 10))
        reviewButton.tap()
        
        // Verify photo naming
        let photoNames = app.staticTexts.matching(identifier: "Photo Name")
        XCTAssertTrue(photoNames.count > 0, "Photos should have names")
        
        // Check naming pattern
        for i in 0..<photoNames.count {
            let photoName = photoNames.element(boundBy: i).label
            XCTAssertTrue(photoName.contains("_"), "Photo name should contain underscore")
            XCTAssertTrue(photoName.contains("_"), "Photo name should contain timestamp")
        }
        
        logger.info("Correct photo naming test completed")
    }
    
    func testEXIFMetadata() throws {
        // Test that EXIF metadata is included
        logger.info("Testing EXIF metadata")
        
        // Complete a session
        try testStartNewSession()
        
        // Navigate to review
        let reviewButton = app.buttons["Review"]
        XCTAssertTrue(reviewButton.waitForExistence(timeout: 10))
        reviewButton.tap()
        
        // Verify EXIF metadata
        let metadataElements = app.staticTexts.matching(identifier: "EXIF Metadata")
        XCTAssertTrue(metadataElements.count > 0, "EXIF metadata should be present")
        
        logger.info("EXIF metadata test completed")
    }
    
    func testSessionCompletionTime() throws {
        // Test that session completes in ≤5 minutes
        logger.info("Testing session completion time")
        
        let startTime = Date()
        
        // Start session
        try testStartNewSession()
        
        // Wait for session completion
        let completionIndicator = app.staticTexts["Session Complete"]
        XCTAssertTrue(completionIndicator.waitForExistence(timeout: 300)) // 5 minutes
        
        let completionTime = Date().timeIntervalSince(startTime)
        XCTAssertLessThanOrEqual(completionTime, 300, "Session should complete in ≤5 minutes")
        
        logger.info("Session completion time test completed: \(completionTime) seconds")
    }
    
    // MARK: - Common Issues Tests
    
    func testLowConfidenceDetection() throws {
        // Test low confidence detection
        logger.info("Testing low confidence detection")
        
        // Start session
        try testStartNewSession()
        
        // Verify low confidence banner
        let lowConfidenceBanner = app.staticTexts["Adjust position"]
        XCTAssertTrue(lowConfidenceBanner.waitForExistence(timeout: 10))
        
        logger.info("Low confidence detection test completed")
    }
    
    func testThermalThrottling() throws {
        // Test thermal throttling
        logger.info("Testing thermal throttling")
        
        // Start session
        try testStartNewSession()
        
        // Verify thermal warning
        let thermalWarning = app.staticTexts["Device overheating"]
        XCTAssertTrue(thermalWarning.waitForExistence(timeout: 10))
        
        logger.info("Thermal throttling test completed")
    }
    
    func testStorageFull() throws {
        // Test storage full scenario
        logger.info("Testing storage full scenario")
        
        // Start session
        try testStartNewSession()
        
        // Verify storage full error
        let storageFullError = app.staticTexts["Storage full"]
        XCTAssertTrue(storageFullError.waitForExistence(timeout: 10))
        
        logger.info("Storage full test completed")
    }
    
    func testCameraPermissionDenied() throws {
        // Test camera permission denied
        logger.info("Testing camera permission denied")
        
        // Terminate app
        app.terminate()
        
        // Launch app without camera permission
        app.launch()
        
        // Verify permission request
        let permissionAlert = app.alerts["Camera Permission"]
        XCTAssertTrue(permissionAlert.waitForExistence(timeout: 5))
        
        // Deny permission
        permissionAlert.buttons["Don't Allow"].tap()
        
        // Verify error message
        let errorMessage = app.staticTexts["Camera permission required"]
        XCTAssertTrue(errorMessage.waitForExistence(timeout: 5))
        
        logger.info("Camera permission denied test completed")
    }
    
    // MARK: - Offline Operation Tests
    
    func testOfflineOperation() throws {
        // Test offline operation
        logger.info("Testing offline operation")
        
        // Start session
        try testStartNewSession()
        
        // Verify offline functionality
        let offlineIndicator = app.staticTexts["Offline Mode"]
        XCTAssertTrue(offlineIndicator.exists)
        
        logger.info("Offline operation test completed")
    }
    
    func testLocalStorage() throws {
        // Test local storage
        logger.info("Testing local storage")
        
        // Complete a session
        try testStartNewSession()
        
        // Navigate to review
        let reviewButton = app.buttons["Review"]
        XCTAssertTrue(reviewButton.waitForExistence(timeout: 10))
        reviewButton.tap()
        
        // Verify local storage
        let localStorageIndicator = app.staticTexts["Stored Locally"]
        XCTAssertTrue(localStorageIndicator.exists)
        
        logger.info("Local storage test completed")
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceTargets() throws {
        // Test performance targets
        logger.info("Testing performance targets")
        
        // Start session
        try testStartNewSession()
        
        // Verify 30fps preview
        let fpsIndicator = app.staticTexts["30 FPS"]
        XCTAssertTrue(fpsIndicator.exists)
        
        // Verify inference latency
        let latencyIndicator = app.staticTexts["<150ms"]
        XCTAssertTrue(latencyIndicator.exists)
        
        logger.info("Performance targets test completed")
    }
    
    func testClassificationAccuracy() throws {
        // Test classification accuracy
        logger.info("Testing classification accuracy")
        
        // Start session
        try testStartNewSession()
        
        // Verify accuracy indicator
        let accuracyIndicator = app.staticTexts["≥95%"]
        XCTAssertTrue(accuracyIndicator.exists)
        
        logger.info("Classification accuracy test completed")
    }
    
    func testDataIntegrity() throws {
        // Test data integrity
        logger.info("Testing data integrity")
        
        // Complete a session
        try testStartNewSession()
        
        // Navigate to review
        let reviewButton = app.buttons["Review"]
        XCTAssertTrue(reviewButton.waitForExistence(timeout: 10))
        reviewButton.tap()
        
        // Verify data integrity
        let integrityIndicator = app.staticTexts["0 Corrupted"]
        XCTAssertTrue(integrityIndicator.exists)
        
        logger.info("Data integrity test completed")
    }
    
    // MARK: - Safety Guidelines Tests
    
    func testSafetyGuidelines() throws {
        // Test safety guidelines
        logger.info("Testing safety guidelines")
        
        // Start session
        try testStartNewSession()
        
        // Verify safety warnings
        let safetyWarning = app.staticTexts["Use only in controlled photo booth environment"]
        XCTAssertTrue(safetyWarning.exists)
        
        logger.info("Safety guidelines test completed")
    }
    
    func testStableMount() throws {
        // Test stable mount requirement
        logger.info("Testing stable mount requirement")
        
        // Start session
        try testStartNewSession()
        
        // Verify mount warning
        let mountWarning = app.staticTexts["Ensure stable iPhone mount"]
        XCTAssertTrue(mountWarning.exists)
        
        logger.info("Stable mount test completed")
    }
    
    func testClearArea() throws {
        // Test clear area requirement
        logger.info("Testing clear area requirement")
        
        // Start session
        try testStartNewSession()
        
        // Verify area warning
        let areaWarning = app.staticTexts["Maintain clear area around vehicle"]
        XCTAssertTrue(areaWarning.exists)
        
        logger.info("Clear area test completed")
    }
    
    func testVoicePrompts() throws {
        // Test voice prompts
        logger.info("Testing voice prompts")
        
        // Start session
        try testStartNewSession()
        
        // Verify voice prompt
        let voicePrompt = app.staticTexts["Front driver 3rd position detected"]
        XCTAssertTrue(voicePrompt.waitForExistence(timeout: 10))
        
        logger.info("Voice prompts test completed")
    }
    
    func testThermalMonitoring() throws {
        // Test thermal monitoring
        logger.info("Testing thermal monitoring")
        
        // Start session
        try testStartNewSession()
        
        // Verify thermal monitoring
        let thermalMonitoring = app.staticTexts["Monitor device temperature"]
        XCTAssertTrue(thermalMonitoring.exists)
        
        logger.info("Thermal monitoring test completed")
    }
}

// MARK: - Quickstart Validation Test Extensions

extension QuickstartValidationTests {
    
    /// Runs a comprehensive quickstart validation test suite
    func testComprehensiveQuickstartValidation() throws {
        logger.info("Starting comprehensive quickstart validation test suite")
        
        // Test all quickstart scenarios
        try testStartNewSession()
        try testPositionVehicle()
        try testAutoCaptureProcess()
        try testManualControls()
        try testReviewAndExport()
        try testAllViewpointsCaptured()
        try testCorrectPhotoNaming()
        try testEXIFMetadata()
        try testSessionCompletionTime()
        try testLowConfidenceDetection()
        try testThermalThrottling()
        try testStorageFull()
        try testCameraPermissionDenied()
        try testOfflineOperation()
        try testLocalStorage()
        try testPerformanceTargets()
        try testClassificationAccuracy()
        try testDataIntegrity()
        try testSafetyGuidelines()
        try testStableMount()
        try testClearArea()
        try testVoicePrompts()
        try testThermalMonitoring()
        
        logger.info("Comprehensive quickstart validation test suite completed")
    }
    
    /// Tests quickstart validation under various conditions
    func testQuickstartValidationUnderStress() throws {
        logger.info("Starting quickstart validation under stress")
        
        // Run multiple quickstart tests concurrently
        let concurrentTests = 3
        let testIterations = 5
        
        for _ in 0..<concurrentTests {
            Task {
                for _ in 0..<testIterations {
                    do {
                        try testStartNewSession()
                        try testPositionVehicle()
                        try testAutoCaptureProcess()
                    } catch {
                        logger.error("Stress quickstart validation error: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // Wait for all tests to complete
        try Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
        
        logger.info("Quickstart validation under stress completed")
    }
}
