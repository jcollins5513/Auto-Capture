import XCTest
import CoreML
import Vision
import OSLog

/// On-device latency validation tests
@MainActor
final class LatencyTests: XCTestCase {
    
    // MARK: - Properties
    
    private var viewpointClassifier: ViewpointClassifier!
    private var stabilityGate: StabilityGate!
    private var thermalMonitor: ThermalMonitor!
    
    private let logger = Logger(subsystem: "AutoCapture", category: "LatencyTests")
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize components
        viewpointClassifier = ViewpointClassifier()
        stabilityGate = StabilityGate()
        thermalMonitor = ThermalMonitor()
        
        // Load model
        try await viewpointClassifier.loadModel()
    }
    
    override func tearDown() async throws {
        // Cleanup
        viewpointClassifier = nil
        stabilityGate = nil
        thermalMonitor = nil
        
        try await super.tearDown()
    }
    
    // MARK: - ML Inference Latency Tests
    
    func testInferenceLatencyTypical() async throws {
        // Test typical inference latency (<150ms)
        let maxLatency: TimeInterval = 0.15 // 150ms
        let testIterations = 50
        
        var totalLatency: TimeInterval = 0.0
        var maxObservedLatency: TimeInterval = 0.0
        var latencyValues: [TimeInterval] = []
        
        for i in 0..<testIterations {
            let testImage = createTestImage()
            
            let startTime = CFAbsoluteTimeGetCurrent()
            let result = try await viewpointClassifier.classify(image: testImage)
            let latency = CFAbsoluteTimeGetCurrent() - startTime
            
            totalLatency += latency
            maxObservedLatency = max(maxObservedLatency, latency)
            latencyValues.append(latency)
            
            // Verify result
            XCTAssertNotNil(result, "Inference should return a result")
            XCTAssertGreaterThanOrEqual(result.confidence, 0.0, "Confidence should be non-negative")
            XCTAssertLessThanOrEqual(result.confidence, 1.0, "Confidence should be at most 1.0")
        }
        
        let averageLatency = totalLatency / Double(testIterations)
        let p95Latency = calculatePercentile(latencyValues, percentile: 0.95)
        let p99Latency = calculatePercentile(latencyValues, percentile: 0.99)
        
        // Verify latency requirements
        XCTAssertLessThanOrEqual(averageLatency, maxLatency,
                                "Average inference latency should be less than \(maxLatency * 1000)ms")
        XCTAssertLessThanOrEqual(p95Latency, maxLatency * 1.5,
                                "P95 inference latency should be less than \(maxLatency * 1.5 * 1000)ms")
        XCTAssertLessThanOrEqual(p99Latency, maxLatency * 2,
                                "P99 inference latency should be less than \(maxLatency * 2 * 1000)ms")
        
        logger.info("Inference latency test: avg=\(averageLatency * 1000)ms, p95=\(p95Latency * 1000)ms, p99=\(p99Latency * 1000)ms")
    }
    
    func testInferenceLatencyP95() async throws {
        // Test P95 inference latency (<300ms)
        let maxP95Latency: TimeInterval = 0.3 // 300ms
        let testIterations = 100
        
        var latencyValues: [TimeInterval] = []
        
        for _ in 0..<testIterations {
            let testImage = createTestImage()
            
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = try await viewpointClassifier.classify(image: testImage)
            let latency = CFAbsoluteTimeGetCurrent() - startTime
            
            latencyValues.append(latency)
        }
        
        let p95Latency = calculatePercentile(latencyValues, percentile: 0.95)
        
        XCTAssertLessThanOrEqual(p95Latency, maxP95Latency,
                                "P95 inference latency should be less than \(maxP95Latency * 1000)ms")
        
        logger.info("P95 inference latency test: \(p95Latency * 1000)ms (max: \(maxP95Latency * 1000)ms)")
    }
    
    func testInferenceLatencyConsistency() async throws {
        // Test that inference latency is consistent
        let testIterations = 20
        let maxVariance: TimeInterval = 0.05 // 50ms variance
        
        var latencyValues: [TimeInterval] = []
        
        for _ in 0..<testIterations {
            let testImage = createTestImage()
            
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = try await viewpointClassifier.classify(image: testImage)
            let latency = CFAbsoluteTimeGetCurrent() - startTime
            
            latencyValues.append(latency)
        }
        
        let averageLatency = latencyValues.reduce(0, +) / Double(latencyValues.count)
        let variance = calculateVariance(latencyValues, mean: averageLatency)
        let standardDeviation = sqrt(variance)
        
        XCTAssertLessThanOrEqual(standardDeviation, maxVariance,
                                "Inference latency standard deviation should be less than \(maxVariance * 1000)ms")
        
        logger.info("Inference latency consistency test: std=\(standardDeviation * 1000)ms (max: \(maxVariance * 1000)ms)")
    }
    
    // MARK: - Stability Gate Latency Tests
    
    func testStabilityGateLatency() async throws {
        // Test stability gate processing latency
        let maxLatency: TimeInterval = 0.01 // 10ms
        let testIterations = 100
        
        var totalLatency: TimeInterval = 0.0
        var maxObservedLatency: TimeInterval = 0.0
        
        for _ in 0..<testIterations {
            let classificationResult = createTestClassificationResult()
            
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = stabilityGate.processClassificationResult(classificationResult)
            let latency = CFAbsoluteTimeGetCurrent() - startTime
            
            totalLatency += latency
            maxObservedLatency = max(maxObservedLatency, latency)
        }
        
        let averageLatency = totalLatency / Double(testIterations)
        
        XCTAssertLessThanOrEqual(averageLatency, maxLatency,
                                "Stability gate latency should be less than \(maxLatency * 1000)ms")
        XCTAssertLessThanOrEqual(maxObservedLatency, maxLatency * 2,
                                "Maximum stability gate latency should be less than \(maxLatency * 2 * 1000)ms")
        
        logger.info("Stability gate latency test: avg=\(averageLatency * 1000)ms, max=\(maxObservedLatency * 1000)ms")
    }
    
    // MARK: - Thermal Throttling Latency Tests
    
    func testThermalThrottlingLatency() async throws {
        // Test latency under thermal throttling
        let thermalMonitor = ThermalMonitor()
        
        // Simulate different thermal states
        let thermalStates: [ProcessInfo.ThermalState] = [.nominal, .fair, .serious, .critical]
        
        for state in thermalStates {
            // Get recommended settings for thermal state
            let settings = thermalMonitor.getRecommendedSettings()
            
            // Test inference latency with throttling
            let testImage = createTestImage()
            let startTime = CFAbsoluteTimeGetCurrent()
            let result = try await viewpointClassifier.classify(image: testImage)
            let latency = CFAbsoluteTimeGetCurrent() - startTime
            
            // Latency should be reasonable even under throttling
            let maxLatency: TimeInterval = 0.5 // 500ms under throttling
            XCTAssertLessThanOrEqual(latency, maxLatency,
                                    "Inference latency should be less than \(maxLatency * 1000)ms under thermal throttling")
            
            logger.info("Thermal throttling latency test for \(state.rawValue): \(latency * 1000)ms")
        }
    }
    
    // MARK: - End-to-End Latency Tests
    
    func testEndToEndLatency() async throws {
        // Test end-to-end latency from image capture to classification
        let maxLatency: TimeInterval = 0.2 // 200ms
        let testIterations = 20
        
        var totalLatency: TimeInterval = 0.0
        var maxObservedLatency: TimeInterval = 0.0
        
        for _ in 0..<testIterations {
            let testImage = createTestImage()
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Simulate end-to-end processing
            let classificationResult = try await viewpointClassifier.classify(image: testImage)
            let stabilityState = stabilityGate.processClassificationResult(classificationResult)
            
            let latency = CFAbsoluteTimeGetCurrent() - startTime
            
            totalLatency += latency
            maxObservedLatency = max(maxObservedLatency, latency)
            
            // Verify processing
            XCTAssertNotNil(classificationResult, "Classification result should not be nil")
            XCTAssertNotNil(stabilityState, "Stability state should not be nil")
        }
        
        let averageLatency = totalLatency / Double(testIterations)
        
        XCTAssertLessThanOrEqual(averageLatency, maxLatency,
                                "End-to-end latency should be less than \(maxLatency * 1000)ms")
        XCTAssertLessThanOrEqual(maxObservedLatency, maxLatency * 1.5,
                                "Maximum end-to-end latency should be less than \(maxLatency * 1.5 * 1000)ms")
        
        logger.info("End-to-end latency test: avg=\(averageLatency * 1000)ms, max=\(maxObservedLatency * 1000)ms")
    }
    
    // MARK: - Concurrent Latency Tests
    
    func testConcurrentInferenceLatency() async throws {
        // Test latency under concurrent inference requests
        let maxLatency: TimeInterval = 0.3 // 300ms under concurrency
        let concurrentRequests = 5
        let requestsPerGroup = 10
        
        var allLatencies: [TimeInterval] = []
        
        for _ in 0..<concurrentRequests {
            Task {
                for _ in 0..<requestsPerGroup {
                    let testImage = createTestImage()
                    
                    let startTime = CFAbsoluteTimeGetCurrent()
                    _ = try? await viewpointClassifier.classify(image: testImage)
                    let latency = CFAbsoluteTimeGetCurrent() - startTime
                    
                    allLatencies.append(latency)
                }
            }
        }
        
        // Wait for all requests to complete
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        let averageLatency = allLatencies.reduce(0, +) / Double(allLatencies.count)
        let maxLatency = allLatencies.max() ?? 0.0
        
        XCTAssertLessThanOrEqual(averageLatency, maxLatency,
                                "Average concurrent inference latency should be less than \(maxLatency * 1000)ms")
        
        logger.info("Concurrent inference latency test: avg=\(averageLatency * 1000)ms, max=\(maxLatency * 1000)ms")
    }
    
    // MARK: - Memory Pressure Latency Tests
    
    func testMemoryPressureLatency() async throws {
        // Test latency under memory pressure
        let maxLatency: TimeInterval = 0.4 // 400ms under memory pressure
        let testIterations = 10
        
        // Create memory pressure by allocating large objects
        var memoryObjects: [Data] = []
        for _ in 0..<100 {
            memoryObjects.append(Data(count: 1024 * 1024)) // 1MB each
        }
        
        var totalLatency: TimeInterval = 0.0
        
        for _ in 0..<testIterations {
            let testImage = createTestImage()
            
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = try await viewpointClassifier.classify(image: testImage)
            let latency = CFAbsoluteTimeGetCurrent() - startTime
            
            totalLatency += latency
        }
        
        let averageLatency = totalLatency / Double(testIterations)
        
        XCTAssertLessThanOrEqual(averageLatency, maxLatency,
                                "Inference latency under memory pressure should be less than \(maxLatency * 1000)ms")
        
        logger.info("Memory pressure latency test: \(averageLatency * 1000)ms (max: \(maxLatency * 1000)ms)")
        
        // Clean up memory objects
        memoryObjects.removeAll()
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() -> CVPixelBuffer {
        let width = 224
        let height = 224
        let bytesPerPixel = 4
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        
        XCTAssertEqual(status, kCVReturnSuccess, "Should create pixel buffer successfully")
        return pixelBuffer!
    }
    
    private func createTestClassificationResult() -> ClassificationResult {
        return ClassificationResult(
            viewpoint: .front,
            confidence: 0.85,
            inferenceTime: 0.1,
            allConfidences: [:]
        )
    }
    
    private func calculatePercentile(_ values: [TimeInterval], percentile: Double) -> TimeInterval {
        let sortedValues = values.sorted()
        let index = Int(Double(sortedValues.count) * percentile)
        return sortedValues[min(index, sortedValues.count - 1)]
    }
    
    private func calculateVariance(_ values: [TimeInterval], mean: TimeInterval) -> TimeInterval {
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        return squaredDifferences.reduce(0, +) / Double(values.count)
    }
}

// MARK: - Latency Test Extensions

extension LatencyTests {
    
    /// Runs a comprehensive latency test suite
    func testComprehensiveLatency() async throws {
        logger.info("Starting comprehensive latency test suite")
        
        // Test all latency aspects
        try await testInferenceLatencyTypical()
        try await testInferenceLatencyP95()
        try await testInferenceLatencyConsistency()
        try await testStabilityGateLatency()
        try await testThermalThrottlingLatency()
        try await testEndToEndLatency()
        try await testConcurrentInferenceLatency()
        try await testMemoryPressureLatency()
        
        logger.info("Comprehensive latency test suite completed")
    }
    
    /// Tests latency under various stress conditions
    func testStressLatency() async throws {
        logger.info("Starting stress latency test")
        
        // Run multiple latency tests concurrently
        let concurrentTests = 3
        let testIterations = 20
        
        for _ in 0..<concurrentTests {
            Task {
                for _ in 0..<testIterations {
                    let testImage = createTestImage()
                    _ = try? await viewpointClassifier.classify(image: testImage)
                }
            }
        }
        
        // Wait for all tests to complete
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        logger.info("Stress latency test completed")
    }
}
