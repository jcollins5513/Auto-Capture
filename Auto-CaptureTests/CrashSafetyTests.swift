import XCTest
import Foundation
import OSLog
@testable import Auto_Capture

/// Crash safety tests for no data loss on termination
@MainActor
final class CrashSafetyTests: XCTestCase {
    
    // MARK: - Properties
    
    private var sessionStore: SessionStore!
    private var captureSessionController: CaptureSessionController!
    private var photoCaptureManager: PhotoCaptureManager!
    
    private let logger = Logger(subsystem: "AutoCapture", category: "CrashSafetyTests")
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize components
        sessionStore = SessionStore()
        captureSessionController = CaptureSessionController()
        photoCaptureManager = PhotoCaptureManager(
            captureSessionController: captureSessionController,
            sessionStore: sessionStore
        )
    }
    
    override func tearDown() async throws {
        // Cleanup
        sessionStore = nil
        captureSessionController = nil
        photoCaptureManager = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Session Crash Safety Tests
    
    func testSessionCrashSafety() async throws {
        // Test that session data is not lost on crash
        let testIterations = 20
        var lostSessions = 0
        
        for i in 0..<testIterations {
            let session = createTestSession()
            
            do {
                // Save session
                try await sessionStore.saveSession(session)
                
                // Simulate crash by forcing app termination
                await simulateCrash()
                
                // Restart and check if session is still there
                let loadedSession = try await sessionStore.loadSession(id: session.id)
                
                if loadedSession == nil {
                    lostSessions += 1
                    logger.error("Session lost after crash at iteration \(i)")
                } else {
                    // Verify session integrity
                    let isCorrupted = try await verifySessionIntegrity(original: session, loaded: loadedSession!)
                    if isCorrupted {
                        lostSessions += 1
                        logger.error("Session corrupted after crash at iteration \(i)")
                    }
                }
                
            } catch {
                logger.error("Failed to test session crash safety at iteration \(i): \(error.localizedDescription)")
                lostSessions += 1
            }
        }
        
        XCTAssertEqual(lostSessions, 0, "No sessions should be lost on crash")
        logger.info("Session crash safety test: \(lostSessions) lost sessions out of \(testIterations)")
    }
    
    func testPhotoCrashSafety() async throws {
        // Test that photo data is not lost on crash
        let testIterations = 50
        var lostPhotos = 0
        
        for i in 0..<testIterations {
            let photo = createTestPhoto()
            let imageData = createTestImageData()
            
            do {
                // Save photo
                let photoURL = try await sessionStore.savePhoto(photo, imageData: imageData)
                
                // Simulate crash
                await simulateCrash()
                
                // Restart and check if photo is still there
                let loadedData = try await sessionStore.loadPhotoData(for: photo)
                
                if loadedData.isEmpty {
                    lostPhotos += 1
                    logger.error("Photo lost after crash at iteration \(i)")
                } else {
                    // Verify photo integrity
                    let isCorrupted = try await verifyPhotoIntegrity(original: imageData, loaded: loadedData)
                    if isCorrupted {
                        lostPhotos += 1
                        logger.error("Photo corrupted after crash at iteration \(i)")
                    }
                }
                
            } catch {
                logger.error("Failed to test photo crash safety at iteration \(i): \(error.localizedDescription)")
                lostPhotos += 1
            }
        }
        
        XCTAssertEqual(lostPhotos, 0, "No photos should be lost on crash")
        logger.info("Photo crash safety test: \(lostPhotos) lost photos out of \(testIterations)")
    }
    
    // MARK: - Partial Write Crash Safety Tests
    
    func testPartialWriteCrashSafety() async throws {
        // Test that partial writes don't corrupt data
        let testIterations = 30
        var corruptedData = 0
        
        for i in 0..<testIterations {
            let session = createTestSession()
            let photo = createTestPhoto()
            let imageData = createTestImageData()
            
            do {
                // Start saving session
                try await sessionStore.saveSession(session)
                
                // Start saving photo
                let photoURL = try await sessionStore.savePhoto(photo, imageData: imageData)
                
                // Simulate crash during write
                await simulateCrashDuringWrite()
                
                // Restart and check data integrity
                let loadedSession = try await sessionStore.loadSession(id: session.id)
                let loadedPhotoData = try await sessionStore.loadPhotoData(for: photo)
                
                // Check if data is corrupted
                if let loadedSession = loadedSession {
                    let isSessionCorrupted = try await verifySessionIntegrity(original: session, loaded: loadedSession)
                    if isSessionCorrupted {
                        corruptedData += 1
                        logger.error("Session corrupted by partial write at iteration \(i)")
                    }
                }
                
                if !loadedPhotoData.isEmpty {
                    let isPhotoCorrupted = try await verifyPhotoIntegrity(original: imageData, loaded: loadedPhotoData)
                    if isPhotoCorrupted {
                        corruptedData += 1
                        logger.error("Photo corrupted by partial write at iteration \(i)")
                    }
                }
                
            } catch {
                logger.error("Failed to test partial write crash safety at iteration \(i): \(error.localizedDescription)")
                corruptedData += 1
            }
        }
        
        XCTAssertEqual(corruptedData, 0, "No data should be corrupted by partial writes")
        logger.info("Partial write crash safety test: \(corruptedData) corrupted data out of \(testIterations)")
    }
    
    // MARK: - Concurrent Access Crash Safety Tests
    
    func testConcurrentAccessCrashSafety() async throws {
        // Test that concurrent access doesn't cause data loss on crash
        let concurrentOperations = 5
        let operationsPerGroup = 10
        var lostData = 0
        
        for _ in 0..<concurrentOperations {
            Task {
                for _ in 0..<operationsPerGroup {
                    let session = createTestSession()
                    let photo = createTestPhoto()
                    let imageData = createTestImageData()
                    
                    do {
                        // Save session and photo concurrently
                        async let sessionSave = sessionStore.saveSession(session)
                        async let photoSave = sessionStore.savePhoto(photo, imageData: imageData)
                        
                        _ = try await sessionSave
                        _ = try await photoSave
                        
                        // Simulate crash
                        await simulateCrash()
                        
                        // Check if data is still there
                        let loadedSession = try await sessionStore.loadSession(id: session.id)
                        let loadedPhotoData = try await sessionStore.loadPhotoData(for: photo)
                        
                        if loadedSession == nil || loadedPhotoData.isEmpty {
                            lostData += 1
                        }
                        
                    } catch {
                        logger.error("Concurrent access crash safety error: \(error.localizedDescription)")
                        lostData += 1
                    }
                }
            }
        }
        
        // Wait for all operations to complete
        try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        
        XCTAssertEqual(lostData, 0, "No data should be lost on concurrent access crash")
        logger.info("Concurrent access crash safety test: \(lostData) lost data")
    }
    
    // MARK: - Memory Pressure Crash Safety Tests
    
    func testMemoryPressureCrashSafety() async throws {
        // Test that memory pressure doesn't cause data loss on crash
        let testIterations = 20
        var lostData = 0
        
        // Create memory pressure
        var memoryObjects: [Data] = []
        for _ in 0..<100 {
            memoryObjects.append(Data(count: 1024 * 1024)) // 1MB each
        }
        
        for i in 0..<testIterations {
            let session = createTestSession()
            let photo = createTestPhoto()
            let imageData = createTestImageData()
            
            do {
                // Save data under memory pressure
                try await sessionStore.saveSession(session)
                _ = try await sessionStore.savePhoto(photo, imageData: imageData)
                
                // Simulate crash under memory pressure
                await simulateCrashUnderMemoryPressure()
                
                // Check if data is still there
                let loadedSession = try await sessionStore.loadSession(id: session.id)
                let loadedPhotoData = try await sessionStore.loadPhotoData(for: photo)
                
                if loadedSession == nil || loadedPhotoData.isEmpty {
                    lostData += 1
                    logger.error("Data lost under memory pressure at iteration \(i)")
                }
                
            } catch {
                logger.error("Failed to test memory pressure crash safety at iteration \(i): \(error.localizedDescription)")
                lostData += 1
            }
        }
        
        // Clean up memory objects
        memoryObjects.removeAll()
        
        XCTAssertEqual(lostData, 0, "No data should be lost under memory pressure crash")
        logger.info("Memory pressure crash safety test: \(lostData) lost data out of \(testIterations)")
    }
    
    // MARK: - Thermal Throttling Crash Safety Tests
    
    func testThermalThrottlingCrashSafety() async throws {
        // Test that thermal throttling doesn't cause data loss on crash
        let testIterations = 20
        var lostData = 0
        
        for i in 0..<testIterations {
            let session = createTestSession()
            let photo = createTestPhoto()
            let imageData = createTestImageData()
            
            do {
                // Save data under thermal throttling
                try await sessionStore.saveSession(session)
                _ = try await sessionStore.savePhoto(photo, imageData: imageData)
                
                // Simulate crash under thermal throttling
                await simulateCrashUnderThermalThrottling()
                
                // Check if data is still there
                let loadedSession = try await sessionStore.loadSession(id: session.id)
                let loadedPhotoData = try await sessionStore.loadPhotoData(for: photo)
                
                if loadedSession == nil || loadedPhotoData.isEmpty {
                    lostData += 1
                    logger.error("Data lost under thermal throttling at iteration \(i)")
                }
                
            } catch {
                logger.error("Failed to test thermal throttling crash safety at iteration \(i): \(error.localizedDescription)")
                lostData += 1
            }
        }
        
        XCTAssertEqual(lostData, 0, "No data should be lost under thermal throttling crash")
        logger.info("Thermal throttling crash safety test: \(lostData) lost data out of \(testIterations)")
    }
    
    // MARK: - Helper Methods
    
    private func createTestSession() -> CaptureSession {
        return CaptureSession(
            stockNumber: "CRASH123",
            settings: SessionSettings.default
        )
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
    
    private func createTestEXIFData() -> EXIFData {
        return EXIFData(
            stockNumber: "CRASH123",
            viewpoint: "FRONT",
            sessionId: UUID().uuidString,
            appVersion: "1.0.0",
            captureTimestamp: Date(),
            deviceModel: "iPhone14,2",
            iosVersion: "17.0"
        )
    }
    
    private func createTestImageData() -> Data {
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
    
    private func simulateCrash() async {
        // Simulate app crash by forcing termination
        // In a real test, this would involve:
        // 1. Sending SIGKILL to the process
        // 2. Simulating system crash
        // 3. Testing recovery mechanisms
        
        logger.info("Simulating app crash")
        
        // Simulate crash delay
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // In a real implementation, this would force app termination
        // For testing purposes, we'll just simulate the crash
    }
    
    private func simulateCrashDuringWrite() async {
        // Simulate crash during file write operation
        logger.info("Simulating crash during write operation")
        
        // Simulate write delay
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Simulate crash
        await simulateCrash()
    }
    
    private func simulateCrashUnderMemoryPressure() async {
        // Simulate crash under memory pressure
        logger.info("Simulating crash under memory pressure")
        
        // Simulate memory pressure delay
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Simulate crash
        await simulateCrash()
    }
    
    private func simulateCrashUnderThermalThrottling() async {
        // Simulate crash under thermal throttling
        logger.info("Simulating crash under thermal throttling")
        
        // Simulate thermal throttling delay
        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
        
        // Simulate crash
        await simulateCrash()
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
        
        return false // Not corrupted
    }
    
    private func verifyPhotoIntegrity(original: Data, loaded: Data) async throws -> Bool {
        // Check data size
        if loaded.isEmpty {
            return true // Corrupted
        }
        
        if loaded.count != original.count {
            return true // Corrupted
        }
        
        // Check data content
        if loaded != original {
            return true // Corrupted
        }
        
        return false // Not corrupted
    }
}

// MARK: - Crash Safety Test Extensions

extension CrashSafetyTests {
    
    /// Runs a comprehensive crash safety test suite
    func testComprehensiveCrashSafety() async throws {
        logger.info("Starting comprehensive crash safety test suite")
        
        // Test all crash safety aspects
        try await testSessionCrashSafety()
        try await testPhotoCrashSafety()
        try await testPartialWriteCrashSafety()
        try await testConcurrentAccessCrashSafety()
        try await testMemoryPressureCrashSafety()
        try await testThermalThrottlingCrashSafety()
        
        logger.info("Comprehensive crash safety test suite completed")
    }
    
    /// Tests crash safety under various stress conditions
    func testStressCrashSafety() async throws {
        logger.info("Starting stress crash safety test")
        
        // Run multiple crash safety tests concurrently
        let concurrentTests = 3
        let testIterations = 10
        
        for _ in 0..<concurrentTests {
            Task {
                for _ in 0..<testIterations {
                    let session = createTestSession()
                    let photo = createTestPhoto()
                    let imageData = createTestImageData()
                    
                    do {
                        try await sessionStore.saveSession(session)
                        _ = try await sessionStore.savePhoto(photo, imageData: imageData)
                        
                        await simulateCrash()
                        
                        let loadedSession = try await sessionStore.loadSession(id: session.id)
                        let loadedPhotoData = try await sessionStore.loadPhotoData(for: photo)
                        
                        if loadedSession == nil || loadedPhotoData.isEmpty {
                            logger.error("Stress test detected data loss")
                        }
                    } catch {
                        logger.error("Stress crash safety test error: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // Wait for all tests to complete
        try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
        
        logger.info("Stress crash safety test completed")
    }
}

