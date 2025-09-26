import XCTest
@testable import Auto_Capture

final class SessionStoreTests: XCTestCase {
    
    var sessionStore: SessionStoreProtocol!
    var testSession: CaptureSession!
    
    override func setUpWithError() throws {
        // This will fail initially since SessionStore doesn't exist yet
        // sessionStore = SessionStore()
        
        // Create test session
        testSession = CaptureSession(
            id: UUID(),
            stockNumber: "TEST123",
            createdAt: Date(),
            completedAt: nil,
            status: .created,
            photos: [],
            settings: SessionSettings()
        )
    }
    
    override func tearDownWithError() throws {
        sessionStore = nil
        testSession = nil
    }
    
    // MARK: - Session Management Tests
    
    func testCreateSession() async throws {
        // Given
        guard let sessionStore = sessionStore else {
            XCTFail("SessionStore not initialized - test will fail until implementation")
            return
        }
        
        let stockNumber = "ABC123"
        
        // When
        let session = try await sessionStore.createSession(stockNumber: stockNumber)
        
        // Then
        XCTAssertEqual(session.stockNumber, stockNumber)
        XCTAssertEqual(session.status, .created)
        XCTAssertTrue(session.photos.isEmpty)
        XCTAssertNotNil(session.createdAt)
    }
    
    func testSaveAndLoadSession() async throws {
        // Given
        guard let sessionStore = sessionStore else {
            XCTFail("SessionStore not initialized - test will fail until implementation")
            return
        }
        
        // When
        try await sessionStore.saveSession(testSession)
        let loadedSession = try await sessionStore.loadSession(id: testSession.id)
        
        // Then
        XCTAssertNotNil(loadedSession)
        XCTAssertEqual(loadedSession?.id, testSession.id)
        XCTAssertEqual(loadedSession?.stockNumber, testSession.stockNumber)
    }
    
    func testLoadNonExistentSession() async throws {
        // Given
        guard let sessionStore = sessionStore else {
            XCTFail("SessionStore not initialized - test will fail until implementation")
            return
        }
        
        let nonExistentId = UUID()
        
        // When
        let session = try await sessionStore.loadSession(id: nonExistentId)
        
        // Then
        XCTAssertNil(session)
    }
    
    func testDeleteSession() async throws {
        // Given
        guard let sessionStore = sessionStore else {
            XCTFail("SessionStore not initialized - test will fail until implementation")
            return
        }
        
        try await sessionStore.saveSession(testSession)
        
        // When
        try await sessionStore.deleteSession(id: testSession.id)
        
        // Then
        let loadedSession = try await sessionStore.loadSession(id: testSession.id)
        XCTAssertNil(loadedSession)
    }
    
    // MARK: - Photo Storage Tests
    
    func testSavePhoto() async throws {
        // Given
        guard let sessionStore = sessionStore else {
            XCTFail("SessionStore not initialized - test will fail until implementation")
            return
        }
        
        let photo = PhotoCapture(
            id: UUID(),
            sessionId: testSession.id,
            viewpoint: .frontDriver3rd,
            order: 1,
            capturedAt: Date(),
            filePath: "",
            confidence: 0.95,
            isRetake: false,
            originalPhotoId: nil,
            exifData: EXIFData(
                stockNumber: testSession.stockNumber,
                viewpoint: "FRONT_DRIVER_3RD",
                sessionId: testSession.id.uuidString,
                appVersion: "1.0.0",
                captureTimestamp: Date(),
                deviceModel: "iPhone 15 Pro",
                iosVersion: "17.0",
                cameraSettings: nil
            )
        )
        
        let imageData = Data("mock image data".utf8)
        
        // When
        let url = try await sessionStore.savePhoto(photo, imageData: imageData)
        
        // Then
        XCTAssertFalse(url.path.isEmpty)
        XCTAssertTrue(url.path.contains(testSession.stockNumber))
        XCTAssertTrue(url.path.contains("01_FRONT_DRIVER_3RD"))
        XCTAssertTrue(url.pathExtension == "jpg")
    }
    
    func testLoadPhotoData() async throws {
        // Given
        guard let sessionStore = sessionStore else {
            XCTFail("SessionStore not initialized - test will fail until implementation")
            return
        }
        
        let photo = PhotoCapture(
            id: UUID(),
            sessionId: testSession.id,
            viewpoint: .frontDriver3rd,
            order: 1,
            capturedAt: Date(),
            filePath: "",
            confidence: 0.95,
            isRetake: false,
            originalPhotoId: nil,
            exifData: EXIFData(
                stockNumber: testSession.stockNumber,
                viewpoint: "FRONT_DRIVER_3RD",
                sessionId: testSession.id.uuidString,
                appVersion: "1.0.0",
                captureTimestamp: Date(),
                deviceModel: "iPhone 15 Pro",
                iosVersion: "17.0",
                cameraSettings: nil
            )
        )
        
        let imageData = Data("mock image data".utf8)
        let url = try await sessionStore.savePhoto(photo, imageData: imageData)
        
        // When
        let loadedData = try await sessionStore.loadPhotoData(for: photo)
        
        // Then
        XCTAssertEqual(loadedData, imageData)
    }
    
    func testDeletePhoto() async throws {
        // Given
        guard let sessionStore = sessionStore else {
            XCTFail("SessionStore not initialized - test will fail until implementation")
            return
        }
        
        let photo = PhotoCapture(
            id: UUID(),
            sessionId: testSession.id,
            viewpoint: .frontDriver3rd,
            order: 1,
            capturedAt: Date(),
            filePath: "",
            confidence: 0.95,
            isRetake: false,
            originalPhotoId: nil,
            exifData: EXIFData(
                stockNumber: testSession.stockNumber,
                viewpoint: "FRONT_DRIVER_3RD",
                sessionId: testSession.id.uuidString,
                appVersion: "1.0.0",
                captureTimestamp: Date(),
                deviceModel: "iPhone 15 Pro",
                iosVersion: "17.0",
                cameraSettings: nil
            )
        )
        
        let imageData = Data("mock image data".utf8)
        _ = try await sessionStore.savePhoto(photo, imageData: imageData)
        
        // When
        try await sessionStore.deletePhoto(photo)
        
        // Then
        do {
            _ = try await sessionStore.loadPhotoData(for: photo)
            XCTFail("Should throw error when photo is deleted")
        } catch {
            XCTAssertTrue(error is StorageError)
        }
    }
    
    // MARK: - File Management Tests
    
    func testCreateSessionDirectory() async throws {
        // Given
        guard let sessionStore = sessionStore else {
            XCTFail("SessionStore not initialized - test will fail until implementation")
            return
        }
        
        // When
        let url = try await sessionStore.createSessionDirectory(for: testSession)
        
        // Then
        XCTAssertTrue(url.path.contains("Sessions"))
        XCTAssertTrue(url.path.contains(testSession.stockNumber))
        XCTAssertTrue(url.path.contains(testSession.id.uuidString))
    }
    
    func testGeneratePhotoFilename() {
        // Given
        guard let sessionStore = sessionStore else {
            XCTFail("SessionStore not initialized - test will fail until implementation")
            return
        }
        
        let photo = PhotoCapture(
            id: UUID(),
            sessionId: testSession.id,
            viewpoint: .frontDriver3rd,
            order: 1,
            capturedAt: Date(),
            filePath: "",
            confidence: 0.95,
            isRetake: false,
            originalPhotoId: nil,
            exifData: EXIFData(
                stockNumber: testSession.stockNumber,
                viewpoint: "FRONT_DRIVER_3RD",
                sessionId: testSession.id.uuidString,
                appVersion: "1.0.0",
                captureTimestamp: Date(),
                deviceModel: "iPhone 15 Pro",
                iosVersion: "17.0",
                cameraSettings: nil
            )
        )
        
        // When
        let filename = sessionStore.generatePhotoFilename(for: photo)
        
        // Then
        XCTAssertTrue(filename.hasPrefix("01_"))
        XCTAssertTrue(filename.contains("FRONT_DRIVER_3RD"))
        XCTAssertTrue(filename.hasSuffix(".jpg"))
    }
    
    func testGetSessionDirectoryURL() {
        // Given
        guard let sessionStore = sessionStore else {
            XCTFail("SessionStore not initialized - test will fail until implementation")
            return
        }
        
        // When
        let url = sessionStore.getSessionDirectoryURL(for: testSession)
        
        // Then
        XCTAssertTrue(url.path.contains("Sessions"))
        XCTAssertTrue(url.path.contains(testSession.stockNumber))
    }
    
    // MARK: - Storage Queries Tests
    
    func testGetAllSessions() async throws {
        // Given
        guard let sessionStore = sessionStore else {
            XCTFail("SessionStore not initialized - test will fail until implementation")
            return
        }
        
        // Create multiple sessions
        let session1 = try await sessionStore.createSession(stockNumber: "ABC123")
        let session2 = try await sessionStore.createSession(stockNumber: "DEF456")
        
        // When
        let allSessions = try await sessionStore.getAllSessions()
        
        // Then
        XCTAssertGreaterThanOrEqual(allSessions.count, 2)
        XCTAssertTrue(allSessions.contains { $0.id == session1.id })
        XCTAssertTrue(allSessions.contains { $0.id == session2.id })
    }
    
    func testGetSessionsCount() async throws {
        // Given
        guard let sessionStore = sessionStore else {
            XCTFail("SessionStore not initialized - test will fail until implementation")
            return
        }
        
        let initialCount = try await sessionStore.getSessionsCount()
        
        // Create a session
        _ = try await sessionStore.createSession(stockNumber: "ABC123")
        
        // When
        let newCount = try await sessionStore.getSessionsCount()
        
        // Then
        XCTAssertEqual(newCount, initialCount + 1)
    }
    
    func testGetStorageUsed() async throws {
        // Given
        guard let sessionStore = sessionStore else {
            XCTFail("SessionStore not initialized - test will fail until implementation")
            return
        }
        
        // When
        let storageUsed = try await sessionStore.getStorageUsed()
        
        // Then
        XCTAssertGreaterThanOrEqual(storageUsed, 0)
    }
    
    func testGetAvailableStorage() async throws {
        // Given
        guard let sessionStore = sessionStore else {
            XCTFail("SessionStore not initialized - test will fail until implementation")
            return
        }
        
        // When
        let availableStorage = try await sessionStore.getAvailableStorage()
        
        // Then
        XCTAssertGreaterThan(availableStorage, 0)
    }
    
    // MARK: - Error Handling Tests
    
    func testStorageFullError() async throws {
        guard let sessionStore = sessionStore else {
            XCTFail("SessionStore not initialized - test will fail until implementation")
            return
        }
        
        let expectation = XCTestExpectation(description: "Storage full callback")
        
        sessionStore.onStorageFull = {
            expectation.fulfill()
        }
        
        // This test will be expanded when storage full scenarios are implemented
        XCTFail("Test will fail until SessionStore implementation exists")
    }
    
    func testStorageErrorCallback() async throws {
        guard let sessionStore = sessionStore else {
            XCTFail("SessionStore not initialized - test will fail until implementation")
            return
        }
        
        let expectation = XCTestExpectation(description: "Storage error callback")
        
        sessionStore.onStorageError = { error in
            XCTAssertTrue(error is StorageError)
            expectation.fulfill()
        }
        
        // This test will be expanded when error scenarios are implemented
        XCTFail("Test will fail until SessionStore implementation exists")
    }
}
