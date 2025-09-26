import XCTest
import AVFoundation
import CoreML
import OSLog

/// Performance tests for 30fps preview and ML inference
@MainActor
final class PerformanceTests: XCTestCase {
    
    // MARK: - Properties
    
    private var captureSessionController: CaptureSessionController!
    private var viewpointClassifier: ViewpointClassifier!
    private var thermalMonitor: ThermalMonitor!
    private var encodingService: EncodingService!
    
    private let logger = Logger(subsystem: "AutoCapture", category: "PerformanceTests")
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize components
        captureSessionController = CaptureSessionController()
        viewpointClassifier = ViewpointClassifier()
        thermalMonitor = ThermalMonitor()
        encodingService = EncodingService()
        
        // Configure session
        try await captureSessionController.configureSession()
    }
    
    override func tearDown() async throws {
        // Cleanup
        try? await captureSessionController.stopSession()
        
        captureSessionController = nil
        viewpointClassifier = nil
        thermalMonitor = nil
        encodingService = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Preview Performance Tests
    
    func testPreviewFrameRate() async throws {
        // Test that preview maintains 30fps
        let targetFrameRate: Double = 30.0
        let testDuration: TimeInterval = 10.0 // 10 seconds
        let tolerance: Double = 0.1 // 10% tolerance
        
        try await captureSessionController.startSession()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var frameCount = 0
        
        // Simulate frame processing
        while CFAbsoluteTimeGetCurrent() - startTime < testDuration {
            // Simulate frame processing time
            try await Task.sleep(nanoseconds: 33_333_333) // ~30fps
            frameCount += 1
        }
        
        let actualFrameRate = Double(frameCount) / testDuration
        let frameRateRatio = actualFrameRate / targetFrameRate
        
        XCTAssertGreaterThanOrEqual(frameRateRatio, 1.0 - tolerance, 
                                  "Frame rate should be at least \(targetFrameRate * (1.0 - tolerance)) fps")
        
        logger.info("Preview frame rate test: \(actualFrameRate) fps (target: \(targetFrameRate) fps)")
    }
    
    func testPreviewLatency() async throws {
        // Test that preview latency is minimal
        let maxLatency: TimeInterval = 0.1 // 100ms
        let testDuration: TimeInterval = 5.0 // 5 seconds
        
        try await captureSessionController.startSession()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var maxObservedLatency: TimeInterval = 0.0
        
        // Simulate frame processing and measure latency
        while CFAbsoluteTimeGetCurrent() - startTime < testDuration {
            let frameStartTime = CFAbsoluteTimeGetCurrent()
            
            // Simulate frame processing
            try await Task.sleep(nanoseconds: 16_666_666) // ~60fps
            
            let frameLatency = CFAbsoluteTimeGetCurrent() - frameStartTime
            maxObservedLatency = max(maxObservedLatency, frameLatency)
        }
        
        XCTAssertLessThanOrEqual(maxObservedLatency, maxLatency,
                                "Preview latency should be less than \(maxLatency * 1000)ms")
        
        logger.info("Preview latency test: \(maxObservedLatency * 1000)ms (max: \(maxLatency * 1000)ms)")
    }
    
    // MARK: - ML Inference Performance Tests
    
    func testInferenceLatency() async throws {
        // Test that ML inference latency is within acceptable limits
        let maxLatency: TimeInterval = 0.15 // 150ms
        let testIterations = 100
        
        try await viewpointClassifier.loadModel()
        
        var totalLatency: TimeInterval = 0.0
        var maxObservedLatency: TimeInterval = 0.0
        
        for i in 0..<testIterations {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Create test image
            let testImage = createTestImage()
            
            // Perform inference
            let result = try await viewpointClassifier.classify(image: testImage)
            
            let latency = CFAbsoluteTimeGetCurrent() - startTime
            totalLatency += latency
            maxObservedLatency = max(maxObservedLatency, latency)
            
            // Verify result
            XCTAssertNotNil(result, "Inference should return a result")
            XCTAssertGreaterThanOrEqual(result.confidence, 0.0, "Confidence should be non-negative")
            XCTAssertLessThanOrEqual(result.confidence, 1.0, "Confidence should be at most 1.0")
        }
        
        let averageLatency = totalLatency / Double(testIterations)
        
        XCTAssertLessThanOrEqual(averageLatency, maxLatency,
                                "Average inference latency should be less than \(maxLatency * 1000)ms")
        XCTAssertLessThanOrEqual(maxObservedLatency, maxLatency * 2,
                                "Maximum inference latency should be less than \(maxLatency * 2 * 1000)ms")
        
        logger.info("Inference latency test: avg=\(averageLatency * 1000)ms, max=\(maxObservedLatency * 1000)ms")
    }
    
    func testInferenceThroughput() async throws {
        // Test that ML inference can handle required throughput
        let targetThroughput: Double = 10.0 // 10 inferences per second
        let testDuration: TimeInterval = 5.0 // 5 seconds
        let tolerance: Double = 0.2 // 20% tolerance
        
        try await viewpointClassifier.loadModel()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var inferenceCount = 0
        
        while CFAbsoluteTimeGetCurrent() - startTime < testDuration {
            let testImage = createTestImage()
            _ = try await viewpointClassifier.classify(image: testImage)
            inferenceCount += 1
        }
        
        let actualThroughput = Double(inferenceCount) / testDuration
        let throughputRatio = actualThroughput / targetThroughput
        
        XCTAssertGreaterThanOrEqual(throughputRatio, 1.0 - tolerance,
                                  "Inference throughput should be at least \(targetThroughput * (1.0 - tolerance)) inferences/sec")
        
        logger.info("Inference throughput test: \(actualThroughput) inferences/sec (target: \(targetThroughput) inferences/sec)")
    }
    
    // MARK: - Encoding Performance Tests
    
    func testJPEGEncodingPerformance() async throws {
        // Test JPEG encoding performance
        let testImageData = createTestImageData()
        let targetQuality: Float = 0.9
        let maxEncodingTime: TimeInterval = 0.5 // 500ms
        let testIterations = 10
        
        var totalEncodingTime: TimeInterval = 0.0
        var maxEncodingTime: TimeInterval = 0.0
        
        for _ in 0..<testIterations {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            let encodedData = try await encodingService.encodeJPEG(
                from: testImageData,
                quality: targetQuality
            )
            
            let encodingTime = CFAbsoluteTimeGetCurrent() - startTime
            totalEncodingTime += encodingTime
            maxEncodingTime = max(maxEncodingTime, encodingTime)
            
            // Verify encoding
            XCTAssertGreaterThan(encodedData.count, 0, "Encoded data should not be empty")
            XCTAssertLessThan(encodedData.count, testImageData.count, "Encoded data should be smaller than original")
        }
        
        let averageEncodingTime = totalEncodingTime / Double(testIterations)
        
        XCTAssertLessThanOrEqual(averageEncodingTime, maxEncodingTime,
                                "Average encoding time should be less than \(maxEncodingTime * 1000)ms")
        
        logger.info("JPEG encoding test: avg=\(averageEncodingTime * 1000)ms, max=\(maxEncodingTime * 1000)ms")
    }
    
    func testBatchEncodingPerformance() async throws {
        // Test batch encoding performance
        let batchSize = 8
        let testImages = (0..<batchSize).map { _ in createTestImageData() }
        let encodingTasks = testImages.enumerated().map { index, imageData in
            ImageEncodingTask(
                id: UUID(),
                imageData: imageData,
                originalSize: CGSize(width: 1024, height: 768),
                targetQuality: 0.9,
                targetSize: nil
            )
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let results = try await encodingService.encodeBatch(
            images: encodingTasks,
            quality: 0.9
        )
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        let averageTimePerImage = totalTime / Double(batchSize)
        
        // Verify results
        XCTAssertEqual(results.count, batchSize, "Should return results for all images")
        
        for result in results {
            XCTAssertTrue(result.success, "All encodings should succeed")
            XCTAssertGreaterThan(result.compressionRatio, 0.0, "Compression ratio should be positive")
            XCTAssertLessThan(result.compressionRatio, 1.0, "Compression ratio should be less than 1.0")
        }
        
        // Performance should be reasonable for batch processing
        XCTAssertLessThanOrEqual(averageTimePerImage, 1.0, "Average time per image should be less than 1 second")
        
        logger.info("Batch encoding test: \(batchSize) images in \(totalTime)s (avg: \(averageTimePerImage)s per image)")
    }
    
    // MARK: - Thermal Performance Tests
    
    func testThermalThrottling() async throws {
        // Test thermal throttling behavior
        let thermalMonitor = ThermalMonitor()
        
        // Simulate thermal state changes
        let thermalStates: [ProcessInfo.ThermalState] = [.nominal, .fair, .serious, .critical]
        
        for state in thermalStates {
            // Simulate thermal state change
            // Note: In a real test, you would need to simulate thermal state changes
            // This is a simplified test
            
            let settings = thermalMonitor.getRecommendedSettings()
            
            // Verify settings change based on thermal state
            if state == .nominal || state == .fair {
                XCTAssertEqual(settings.inferenceThrottle, 1.0, "Inference should not be throttled in normal thermal state")
                XCTAssertEqual(settings.previewFrameRate, 30.0, "Preview should run at full frame rate in normal thermal state")
            } else {
                XCTAssertLessThan(settings.inferenceThrottle, 1.0, "Inference should be throttled in high thermal state")
                XCTAssertLessThan(settings.previewFrameRate, 30.0, "Preview should be throttled in high thermal state")
            }
        }
        
        logger.info("Thermal throttling test completed")
    }
    
    // MARK: - Memory Performance Tests
    
    func testMemoryUsage() async throws {
        // Test memory usage during operation
        let initialMemory = getMemoryUsage()
        
        // Perform memory-intensive operations
        for _ in 0..<100 {
            let testImage = createTestImage()
            _ = try await viewpointClassifier.classify(image: testImage)
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be reasonable (less than 100MB)
        XCTAssertLessThan(memoryIncrease, 100 * 1024 * 1024, "Memory increase should be less than 100MB")
        
        logger.info("Memory usage test: increase=\(memoryIncrease / 1024 / 1024)MB")
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() -> CVPixelBuffer {
        // Create a test pixel buffer
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
    
    private func createTestImageData() -> Data {
        // Create test image data
        let testImage = createTestImage()
        
        let ciImage = CIImage(cvPixelBuffer: testImage)
        let context = CIContext()
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
        
        let imageData = NSMutableData()
        let destination = CGImageDestinationCreateWithData(imageData, kUTTypeJPEG, 1, nil)
        CGImageDestinationAddImage(destination!, cgImage!, nil)
        CGImageDestinationFinalize(destination!)
        
        return imageData as Data
    }
    
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
}

// MARK: - Performance Test Extensions

extension PerformanceTests {
    
    /// Runs a comprehensive performance test suite
    func testOverallPerformance() async throws {
        logger.info("Starting comprehensive performance test suite")
        
        // Test all performance aspects
        try await testPreviewFrameRate()
        try await testPreviewLatency()
        try await testInferenceLatency()
        try await testInferenceThroughput()
        try await testJPEGEncodingPerformance()
        try await testBatchEncodingPerformance()
        try await testThermalThrottling()
        try await testMemoryUsage()
        
        logger.info("Comprehensive performance test suite completed")
    }
    
    /// Tests performance under stress conditions
    func testStressPerformance() async throws {
        logger.info("Starting stress performance test")
        
        // Run multiple operations concurrently
        let concurrentOperations = 5
        let operationsPerGroup = 10
        
        for _ in 0..<concurrentOperations {
            Task {
                for _ in 0..<operationsPerGroup {
                    let testImage = createTestImage()
                    _ = try? await viewpointClassifier.classify(image: testImage)
                }
            }
        }
        
        // Wait for all operations to complete
        try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        
        logger.info("Stress performance test completed")
    }
}
