import XCTest
import OSLog
@testable import Auto_Capture

@MainActor
final class ExporterTests: XCTestCase {
    private var baseDirectory: URL!
    private var sessionStore: MockSessionStore!
    private var exporter: Exporter!

    override func setUpWithError() throws {
        try super.setUpWithError()
        baseDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("ExporterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        sessionStore = MockSessionStore(baseURL: baseDirectory)
        exporter = Exporter(sessionStore: sessionStore)
    }

    override func tearDownWithError() throws {
        exporter = nil
        sessionStore = nil
        if let baseDirectory = baseDirectory, FileManager.default.fileExists(atPath: baseDirectory.path) {
            try? FileManager.default.removeItem(at: baseDirectory)
        }
        baseDirectory = nil
        try super.tearDownWithError()
    }

    func testExportCreatesVersionedZipContainingPhotos() async throws {
        let session = try await sessionStore.createSession(stockNumber: "TEST123")
        var updatedSession = session

        let viewpoints = [Viewpoint.frontDriver3rd, Viewpoint.front]
        for viewpoint in viewpoints {
            let photo = try await sessionStore.makePhoto(for: session, viewpoint: viewpoint, imageData: Data("image-\(viewpoint.order)".utf8))
            updatedSession.addPhoto(photo)
        }
        try await sessionStore.saveSession(updatedSession)

        let result = try await exporter.exportSession(updatedSession, to: .files)

        guard let zipURL = result.fileURL else {
            return XCTFail("Expected export result to contain file URL")
        }

        XCTAssertEqual(zipURL.pathExtension.lowercased(), "zip")
        XCTAssertTrue(zipURL.lastPathComponent.contains("v"), "Zip filename should include version information")
        XCTAssertTrue(FileManager.default.fileExists(atPath: zipURL.path))

        let attributes = try FileManager.default.attributesOfItem(atPath: zipURL.path)
        let fileSize = attributes[.size] as? NSNumber
        XCTAssertNotNil(fileSize)
        XCTAssertGreaterThan(fileSize?.intValue ?? 0, 0)

        let zipData = try Data(contentsOf: zipURL)
        for viewpoint in viewpoints {
            let expectedTerm = Data(viewpoint.rawValue.utf8)
            XCTAssertNotNil(zipData.range(of: expectedTerm), "Zip archive should contain filename for \(viewpoint.rawValue)")
        }
    }

    func testValidateExportDetectsIncompleteSession() async throws {
        let session = try await sessionStore.createSession(stockNumber: "PARTIAL")
        var updatedSession = session
        let photo = try await sessionStore.makePhoto(for: session, viewpoint: .frontDriver3rd, imageData: Data("mock".utf8))
        updatedSession.addPhoto(photo)
        try await sessionStore.saveSession(updatedSession)

        let validation = try await exporter.validateExport(updatedSession)
        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.issues.contains { $0.contains("not complete") })
    }
}

@MainActor
private final class MockSessionStore: SessionStoreProtocol {
    var onStorageFull: (() -> Void)?
    var onStorageError: ((StorageError) -> Void)?

    private let baseURL: URL
    private let fileManager = FileManager.default
    private var sessions: [UUID: CaptureSession] = [:]

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func createSession(stockNumber: String) async throws -> CaptureSession {
        let session = CaptureSession(stockNumber: stockNumber, settings: .default)
        sessions[session.id] = session
        try fileManager.createDirectory(at: getSessionDirectoryURL(for: session), withIntermediateDirectories: true)
        try await saveSession(session)
        return session
    }

    func loadSession(id: UUID) async throws -> CaptureSession? {
        return sessions[id]
    }

    func saveSession(_ session: CaptureSession) async throws {
        sessions[session.id] = session
        let metadataURL = getSessionDirectoryURL(for: session).appendingPathComponent("session.json")
        let data = try JSONEncoder().encode(session)
        try data.write(to: metadataURL, options: .atomic)
    }

    func deleteSession(id: UUID) async throws {
        sessions.removeValue(forKey: id)
        try fileManager.removeItem(at: getSessionDirectoryURL(for: id))
    }

    func savePhoto(_ photo: PhotoCapture, imageData: Data) async throws -> URL {
        let directory = getSessionDirectoryURL(for: photo.sessionId)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = generatePhotoFilename(for: photo)
        let fileURL = directory.appendingPathComponent(filename)
        try imageData.write(to: fileURL, options: .atomic)
        return fileURL
    }

    func loadPhotoData(for photo: PhotoCapture) async throws -> Data {
        return try Data(contentsOf: URL(fileURLWithPath: photo.filePath))
    }

    func deletePhoto(_ photo: PhotoCapture) async throws {
        try fileManager.removeItem(atPath: photo.filePath)
    }

    func createSessionDirectory(for session: CaptureSession) async throws -> URL {
        let directory = getSessionDirectoryURL(for: session)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    func generatePhotoFilename(for photo: PhotoCapture) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestampString = formatter.string(from: photo.capturedAt)
        let orderString = String(format: "%02d", photo.order)
        let confidenceString = String(format: "%.0f", photo.confidence * 100)
        return "\(orderString)_\(photo.viewpoint.rawValue)_\(timestampString)_\(confidenceString).jpg"
    }

    func getSessionDirectoryURL(for session: CaptureSession) -> URL {
        return getSessionDirectoryURL(for: session.id)
    }

    private func getSessionDirectoryURL(for sessionId: UUID) -> URL {
        baseURL.appendingPathComponent(sessionId.uuidString, isDirectory: true)
    }

    func getAllSessions() async throws -> [CaptureSession] {
        return Array(sessions.values)
    }

    func getSessionsCount() async throws -> Int {
        return sessions.count
    }

    func getStorageUsed() async throws -> Int64 {
        return 0
    }

    func getAvailableStorage() async throws -> Int64 {
        return Int64(1_000_000_000)
    }

    func makePhoto(for session: CaptureSession, viewpoint: Viewpoint, imageData: Data) async throws -> PhotoCapture {
        var photo = PhotoCapture(
            sessionId: session.id,
            viewpoint: viewpoint,
            order: viewpoint.order,
            filePath: "",
            confidence: 0.95,
            exifData: EXIFData(
                stockNumber: session.stockNumber,
                viewpoint: viewpoint.rawValue,
                sessionId: session.id.uuidString,
                appVersion: "1.0.0",
                captureTimestamp: Date(),
                deviceModel: "iPhone15,2",
                iosVersion: "17.0"
            )
        )

        let url = try await savePhoto(photo, imageData: imageData)
        photo.filePath = url.path
        return photo
    }
}
