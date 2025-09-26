import XCTest
import Foundation
import OSLog

/// Data integrity tests for zero corrupted files across 1,000 captures
@MainActor
final class DataIntegrityTests: XCTestCase {
    
    // MARK: - Properties
    
    private var sessionStore: SessionStore!
    private var exifHandler: EXIFHandler!
    private var encodingService: EncodingService!
    
    private let logger = Logger(subsystem: "AutoCapture", category: "DataIntegrityTests")
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize components
        sessionStore = SessionStore()
        exifHandler = EXIFHandler()
        encodingService = EncodingService()
    }
    
    override func tearDown() async throws {
        // Cleanup
        sessionStore = nil
        exifHandler = nil
        encodingService = nil
        
        try await super.tearDown()
    }
    
    // MARK: - File Integrity Tests
    
    func testPhotoFileIntegrity() async throws {
        // Test that photo files are not corrupted during capture and storage
        let testIterations = 100
        var corruptedFiles = 0
        
        for i in 0..<testIterations {
            let testImageData = createTestImageData()
            let photo = createTestPhoto()
            
            do {
                // Save photo
                let photoURL = try await sessionStore.savePhoto(photo, imageData: testImageData)
                
                // Verify file exists
                XCTAssertTrue(FileManager.default.fileExists(atPath: photoURL.path),
                             "Photo file should exist at path: \(photoURL.path)")
                
                // Verify file is not corrupted
                let loadedData = try await sessionStore.loadPhotoData(for: photo)
                XCTAssertEqual(loadedData.count, testImageData.count,
                              "Loaded data size should match original data size")
                
                // Verify file integrity
                let isCorrupted = try await verifyFileIntegrity(photoURL)
                if isCorrupted {
                    corruptedFiles += 1
                    logger.error("Corrupted file detected at iteration \(i)")
                }
                
            } catch {
                logger.error("Failed to save/load photo at iteration \(i): \(error.localizedDescription)")
                corruptedFiles += 1
            }
        }
        
        XCTAssertEqual(corruptedFiles, 0, "No files should be corrupted")
        logger.info("Photo file integrity test: \(corruptedFiles) corrupted files out of \(testIterations)")
    }
    
    func testSessionDataIntegrity() async throws {
        // Test that session data is not corrupted
        let testIterations = 50
        var corruptedSessions = 0
        
        for i in 0..<testIterations {
            let session = createTestSession()
            
            do {
                // Save session
                try await sessionStore.saveSession(session)
                
                // Load session
                let loadedSession = try await sessionStore.loadSession(id: session.id)
                XCTAssertNotNil(loadedSession, "Session should be loaded successfully")
                
                // Verify session integrity
                if let loadedSession = loadedSession {
                    let isCorrupted = try await verifySessionIntegrity(original: session, loaded: loadedSession)
                    if isCorrupted {
                        corruptedSessions += 1
                        logger.error("Corrupted session detected at iteration \(i)")
                    }
                }
                
            } catch {
                logger.error("Failed to save/load session at iteration \(i): \(error.localizedDescription)")
                corruptedSessions += 1
            }
        }
        
        XCTAssertEqual(corruptedSessions, 0, "No sessions should be corrupted")
        logger.info("Session data integrity test: \(corruptedSessions) corrupted sessions out of \(testIterations)")
    }
    
    func testEXIFDataIntegrity() async throws {
        // Test that EXIF data is not corrupted
        let testIterations = 100
        var corruptedEXIF = 0
        
        for i in 0..<testIterations {
            let originalEXIF = createTestEXIFData()
            let testImageData = createTestImageData()
            
            do {
                // Write EXIF data
                let encodedData = try await exifHandler.writeEXIFData(originalEXIF, to: testImageData)
                
                // Read EXIF data
                let readEXIF = try await exifHandler.readEXIFData(from: encodedData)
                XCTAssertNotNil(readEXIF, "EXIF data should be read successfully")
                
                // Verify EXIF integrity
                if let readEXIF = readEXIF {
                    let isCorrupted = try await verifyEXIFIntegrity(original: originalEXIF, read: readEXIF)
                    if isCorrupted {
                        corruptedEXIF += 1
                        logger.error("Corrupted EXIF data detected at iteration \(i)")
                    }
                }
                
            } catch {
                logger.error("Failed to write/read EXIF data at iteration \(i): \(error.localizedDescription)")
                corruptedEXIF += 1
            }
        }
        
        XCTAssertEqual(corruptedEXIF, 0, "No EXIF data should be corrupted")
        logger.info("EXIF data integrity test: \(corruptedEXIF) corrupted EXIF out of \(testIterations)")
    }
    
    // MARK: - Encoding Integrity Tests
    
    func testJPEGEncodingIntegrity() async throws {
        // Test that JPEG encoding does not corrupt data
        let testIterations = 100
        var corruptedEncodings = 0
        
        for i in 0..<testIterations {
            let originalData = createTestImageData()
            
            do {
                // Encode JPEG
                let encodedData = try await encodingService.encodeJPEG(
                    from: originalData,
                    quality: 0.9
                )
                
                // Verify encoding integrity
                let isCorrupted = try await verifyEncodingIntegrity(original: originalData, encoded: encodedData)
                if isCorrupted {
                    corruptedEncodings += 1
                    logger.error("Corrupted encoding detected at iteration \(i)")
                }
                
            } catch {
                logger.error("Failed to encode JPEG at iteration \(i): \(error.localizedDescription)")
                corruptedEncodings += 1
            }
        }
        
        XCTAssertEqual(corruptedEncodings, 0, "No encodings should be corrupted")
        logger.info("JPEG encoding integrity test: \(corruptedEncodings) corrupted encodings out of \(testIterations)")
    }
    
    func testBatchEncodingIntegrity() async throws {
        // Test that batch encoding does not corrupt data
        let batchSize = 10
        let testIterations = 10
        var corruptedBatches = 0
        
        for i in 0..<testIterations {
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
            
            do {
                // Encode batch
                let results = try await encodingService.encodeBatch(
                    images: encodingTasks,
                    quality: 0.9
                )
                
                // Verify batch integrity
                let isCorrupted = try await verifyBatchIntegrity(original: testImages, results: results)
                if isCorrupted {
                    corruptedBatches += 1
                    logger.error("Corrupted batch detected at iteration \(i)")
                }
                
            } catch {
                logger.error("Failed to encode batch at iteration \(i): \(error.localizedDescription)")
                corruptedBatches += 1
            }
        }
        
        XCTAssertEqual(corruptedBatches, 0, "No batches should be corrupted")
        logger.info("Batch encoding integrity test: \(corruptedBatches) corrupted batches out of \(testIterations)")
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentFileAccess() async throws {
        // Test that concurrent file access does not corrupt data
        let concurrentOperations = 10
        let operationsPerGroup = 20
        var corruptedFiles = 0
        
        for _ in 0..<concurrentOperations {
            Task {
                for _ in 0..<operationsPerGroup {
                    let testImageData = createTestImageData()
                    let photo = createTestPhoto()
                    
                    do {
                        // Save photo
                        let photoURL = try await sessionStore.savePhoto(photo, imageData: testImageData)
                        
                        // Verify file integrity
                        let isCorrupted = try await verifyFileIntegrity(photoURL)
                        if isCorrupted {
                            corruptedFiles += 1
                        }
                        
                    } catch {
                        logger.error("Concurrent file access error: \(error.localizedDescription)")
                        corruptedFiles += 1
                    }
                }
            }
        }
        
        // Wait for all operations to complete
        try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        
        XCTAssertEqual(corruptedFiles, 0, "No files should be corrupted under concurrent access")
        logger.info("Concurrent file access test: \(corruptedFiles) corrupted files")
    }
    
    func testConcurrentSessionAccess() async throws {
        // Test that concurrent session access does not corrupt data
        let concurrentOperations = 5
        let operationsPerGroup = 10
        var corruptedSessions = 0
        
        for _ in 0..<concurrentOperations {
            Task {
                for _ in 0..<operationsPerGroup {
                    let session = createTestSession()
                    
                    do {
                        // Save session
                        try await sessionStore.saveSession(session)
                        
                        // Load session
                        let loadedSession = try await sessionStore.loadSession(id: session.id)
                        
                        // Verify session integrity
                        if let loadedSession = loadedSession {
                            let isCorrupted = try await verifySessionIntegrity(original: session, loaded: loadedSession)
                            if isCorrupted {
                                corruptedSessions += 1
                            }
                        }
                        
                    } catch {
                        logger.error("Concurrent session access error: \(error.localizedDescription)")
                        corruptedSessions += 1
                    }
                }
            }
        }
        
        // Wait for all operations to complete
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        XCTAssertEqual(corruptedSessions, 0, "No sessions should be corrupted under concurrent access")
        logger.info("Concurrent session access test: \(corruptedSessions) corrupted sessions")
    }
    
    // MARK: - Stress Tests
    
    func testHighVolumeDataIntegrity() async throws {
        // Test data integrity under high volume (1,000 captures)
        let highVolumeIterations = 1000
        var corruptedFiles = 0
        
        logger.info("Starting high volume data integrity test with \(highVolumeIterations) iterations")
        
        for i in 0..<highVolumeIterations {
            let testImageData = createTestImageData()
            let photo = createTestPhoto()
            
            do {
                // Save photo
                let photoURL = try await sessionStore.savePhoto(photo, imageData: testImageData)
                
                // Verify file integrity
                let isCorrupted = try await verifyFileIntegrity(photoURL)
                if isCorrupted {
                    corruptedFiles += 1
                    logger.error("Corrupted file detected at iteration \(i)")
                }
                
                // Progress logging
                if i % 100 == 0 {
                    logger.info("High volume test progress: \(i)/\(highVolumeIterations)")
                }
                
            } catch {
                logger.error("Failed to save photo at iteration \(i): \(error.localizedDescription)")
                corruptedFiles += 1
            }
        }
        
        XCTAssertEqual(corruptedFiles, 0, "No files should be corrupted in high volume test")
        logger.info("High volume data integrity test: \(corruptedFiles) corrupted files out of \(highVolumeIterations)")
    }
    
    // MARK: - Helper Methods
    
    private func createTestImageData() -> Data {
        // Create test image data
        let width = 1024
        let height = 768
        let bytesPerPixel = 4
        
        let dataSize = width * height * bytesPerPixel
        var imageData = Data(count: dataSize)
        
        // Fill with test pattern
        for i in 0..<dataSize {
            imageData[i] = UInt8(i % 256)
        }
        
        return imageData
    }
    
    private func createTestPhoto() -> PhotoCapture {
        return PhotoCapture(
            sessionId: UUID(),
            viewpoint: .front,
            order: 1,
            filePath: "",
            confidence: 0.85,
            exifData: createTestEXIFData()
        )
    }
    
    private func createTestSession() -> CaptureSession {
        return CaptureSession(
            stockNumber: "TEST123",
            settings: SessionSettings.default
        )
    }
    
    private func createTestEXIFData() -> EXIFData {
        return EXIFData(
            stockNumber: "TEST123",
            viewpoint: "FRONT",
            sessionId: UUID().uuidString,
            appVersion: "1.0.0",
            captureTimestamp: Date(),
            deviceModel: "iPhone14,2",
            iosVersion: "17.0"
        )
    }
    
    private func verifyFileIntegrity(_ fileURL: URL) async throws -> Bool {
        // Check if file exists and is readable
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return true // Corrupted
        }
        
        // Check file size
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        if fileSize == 0 {
            return true // Corrupted
        }
        
        // Try to read file
        do {
            let data = try Data(contentsOf: fileURL)
            return data.isEmpty // Corrupted if empty
        } catch {
            return true // Corrupted
        }
    }
    
    private func verifySessionIntegrity(original: CaptureSession, loaded: CaptureSession) async throws -> Bool {
        // Check basic properties
        if original.id != loaded.id {
            return true // Corrupted
        }
        
        if original.stockNumber != loaded.stockNumber {
            return true // Corrupted
        }
        
        if original.status != loaded.status {
            return true // Corrupted
        }
        
        if original.photos.count != loaded.photos.count {
            return true // Corrupted
        }
        
        // Check photos integrity
        for (originalPhoto, loadedPhoto) in zip(original.photos, loaded.photos) {
            if originalPhoto.id != loadedPhoto.id {
                return true // Corrupted
            }
            
            if originalPhoto.viewpoint != loadedPhoto.viewpoint {
                return true // Corrupted
            }
        }
        
        return false // Not corrupted
    }
    
    private func verifyEXIFIntegrity(original: EXIFData, read: EXIFData) async throws -> Bool {
        // Check basic properties
        if original.stockNumber != read.stockNumber {
            return true // Corrupted
        }
        
        if original.viewpoint != read.viewpoint {
            return true // Corrupted
        }
        
        if original.sessionId != read.sessionId {
            return true // Corrupted
        }
        
        if original.appVersion != read.appVersion {
            return true // Corrupted
        }
        
        return false // Not corrupted
    }
    
    private func verifyEncodingIntegrity(original: Data, encoded: Data) async throws -> Bool {
        // Check that encoded data is not empty
        if encoded.isEmpty {
            return true // Corrupted
        }
        
        // Check that encoded data is smaller than original (compression)
        if encoded.count >= original.count {
            return true // Corrupted (no compression)
        }
        
        // Check that encoded data is not too small (over-compression)
        if encoded.count < original.count / 10 {
            return true // Corrupted (over-compression)
        }
        
        return false // Not corrupted
    }
    
    private func verifyBatchIntegrity(original: [Data], results: [EncodingResult]) async throws -> Bool {
        // Check that all results are present
        if results.count != original.count {
            return true // Corrupted
        }
        
        // Check that all results are successful
        for result in results {
            if !result.success {
                return true // Corrupted
            }
        }
        
        return false // Not corrupted
    }
}

// MARK: - Data Integrity Test Extensions

extension DataIntegrityTests {
    
    /// Runs a comprehensive data integrity test suite
    func testComprehensiveDataIntegrity() async throws {
        logger.info("Starting comprehensive data integrity test suite")
        
        // Test all data integrity aspects
        try await testPhotoFileIntegrity()
        try await testSessionDataIntegrity()
        try await testEXIFDataIntegrity()
        try await testJPEGEncodingIntegrity()
        try await testBatchEncodingIntegrity()
        try await testConcurrentFileAccess()
        try await testConcurrentSessionAccess()
        try await testHighVolumeDataIntegrity()
        
        logger.info("Comprehensive data integrity test suite completed")
    }
    
    /// Tests data integrity under various stress conditions
    func testStressDataIntegrity() async throws {
        logger.info("Starting stress data integrity test")
        
        // Run multiple integrity tests concurrently
        let concurrentTests = 5
        let testIterations = 50
        
        for _ in 0..<concurrentTests {
            Task {
                for _ in 0..<testIterations {
                    let testImageData = createTestImageData()
                    let photo = createTestPhoto()
                    
                    do {
                        let photoURL = try await sessionStore.savePhoto(photo, imageData: testImageData)
                        let isCorrupted = try await verifyFileIntegrity(photoURL)
                        
                        if isCorrupted {
                            logger.error("Stress test detected corrupted file")
                        }
                    } catch {
                        logger.error("Stress test error: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // Wait for all tests to complete
        try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
        
        logger.info("Stress data integrity test completed")
    }
}
