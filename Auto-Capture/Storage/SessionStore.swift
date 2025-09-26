import Foundation
import OSLog

/// File system storage and session management
final class SessionStore: SessionStoreProtocol {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "AutoCapture", category: "SessionStore")
    private let fileManager = FileManager.default
    
    private let documentsDirectory: URL
    private let sessionsDirectory: URL
    
    // Event handlers
    var onStorageFull: (() -> Void)?
    var onStorageError: ((StorageError) -> Void)?
    
    // MARK: - Initialization
    
    init() {
        // Get documents directory
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        sessionsDirectory = documentsDirectory.appendingPathComponent("Sessions")
        
        // Create sessions directory if it doesn't exist
        createSessionsDirectoryIfNeeded()
    }
    
    // MARK: - Session Management
    
    func createSession(stockNumber: String) async throws -> CaptureSession {
        let sessionId = UUID()
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestampString = formatter.string(from: timestamp)
        
        // Create session
        let session = CaptureSession(
            id: sessionId,
            stockNumber: stockNumber,
            createdAt: timestamp,
            settings: SessionSettings.default
        )
        
        // Create session directory
        let sessionDirectory = try await createSessionDirectory(for: session)
        
        // Save session metadata
        try await saveSession(session)
        
        logger.info("Created session: \(sessionId.uuidString) for stock: \(stockNumber)")
        
        return session
    }
    
    func loadSession(id: UUID) async throws -> CaptureSession? {
        let sessionURL = getSessionMetadataURL(for: id)
        
        guard fileManager.fileExists(atPath: sessionURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: sessionURL)
            let session = try JSONDecoder().decode(CaptureSession.self, from: data)
            logger.debug("Loaded session: \(id.uuidString)")
            return session
        } catch {
            logger.error("Failed to load session: \(error.localizedDescription)")
            throw StorageError.fileSystemError
        }
    }
    
    func saveSession(_ session: CaptureSession) async throws {
        let sessionURL = getSessionMetadataURL(for: session.id)
        
        do {
            let data = try JSONEncoder().encode(session)
            try data.write(to: sessionURL)
            
            // Ensure data is written to disk
            try sessionURL.resourceValues(forKeys: [.contentModificationDateKey])
            
            logger.debug("Saved session: \(session.id.uuidString)")
        } catch {
            logger.error("Failed to save session: \(error.localizedDescription)")
            throw StorageError.fileSystemError
        }
    }
    
    func deleteSession(id: UUID) async throws {
        let sessionDirectory = getSessionDirectoryURL(for: id)
        
        guard fileManager.fileExists(atPath: sessionDirectory.path) else {
            throw StorageError.sessionNotFound
        }
        
        do {
            try fileManager.removeItem(at: sessionDirectory)
            logger.info("Deleted session: \(id.uuidString)")
        } catch {
            logger.error("Failed to delete session: \(error.localizedDescription)")
            throw StorageError.fileSystemError
        }
    }
    
    // MARK: - Photo Storage
    
    func savePhoto(_ photo: PhotoCapture, imageData: Data) async throws -> URL {
        guard let session = try await loadSession(id: photo.sessionId) else {
            throw StorageError.sessionNotFound
        }
        
        let sessionDirectory = getSessionDirectoryURL(for: session)
        let filename = generatePhotoFilename(for: photo)
        let photoURL = sessionDirectory.appendingPathComponent(filename)
        
        do {
            try imageData.write(to: photoURL)
            
            // Ensure data is written to disk
            try photoURL.resourceValues(forKeys: [.contentModificationDateKey])
            
            logger.debug("Saved photo: \(filename)")
            return photoURL
        } catch {
            logger.error("Failed to save photo: \(error.localizedDescription)")
            throw StorageError.fileSystemError
        }
    }
    
    func loadPhotoData(for photo: PhotoCapture) async throws -> Data {
        let photoURL = URL(fileURLWithPath: photo.filePath)
        
        guard fileManager.fileExists(atPath: photoURL.path) else {
            throw StorageError.photoNotFound
        }
        
        do {
            let data = try Data(contentsOf: photoURL)
            logger.debug("Loaded photo data: \(photoURL.lastPathComponent)")
            return data
        } catch {
            logger.error("Failed to load photo data: \(error.localizedDescription)")
            throw StorageError.fileSystemError
        }
    }
    
    func deletePhoto(_ photo: PhotoCapture) async throws {
        let photoURL = URL(fileURLWithPath: photo.filePath)
        
        guard fileManager.fileExists(atPath: photoURL.path) else {
            throw StorageError.photoNotFound
        }
        
        do {
            try fileManager.removeItem(at: photoURL)
            logger.debug("Deleted photo: \(photoURL.lastPathComponent)")
        } catch {
            logger.error("Failed to delete photo: \(error.localizedDescription)")
            throw StorageError.fileSystemError
        }
    }
    
    // MARK: - File Management
    
    func createSessionDirectory(for session: CaptureSession) async throws -> URL {
        let sessionDirectory = getSessionDirectoryURL(for: session)
        
        guard !fileManager.fileExists(atPath: sessionDirectory.path) else {
            return sessionDirectory
        }
        
        do {
            try fileManager.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)
            logger.debug("Created session directory: \(sessionDirectory.path)")
            return sessionDirectory
        } catch {
            logger.error("Failed to create session directory: \(error.localizedDescription)")
            throw StorageError.fileSystemError
        }
    }
    
    func generatePhotoFilename(for photo: PhotoCapture) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestampString = formatter.string(from: photo.capturedAt)
        
        let orderString = String(format: "%02d", photo.order)
        let viewpointString = photo.viewpoint.rawValue
        let confidenceString = String(format: "%.0f", photo.confidence * 100)
        
        return "\(orderString)_\(viewpointString)_\(timestampString)_\(confidenceString).jpg"
    }
    
    func getSessionDirectoryURL(for session: CaptureSession) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestampString = formatter.string(from: session.createdAt)
        
        let directoryName = "\(session.stockNumber)-\(timestampString)"
        return sessionsDirectory.appendingPathComponent(directoryName)
    }
    
    // MARK: - Storage Queries
    
    func getAllSessions() async throws -> [CaptureSession] {
        guard fileManager.fileExists(atPath: sessionsDirectory.path) else {
            return []
        }
        
        do {
            let sessionDirectories = try fileManager.contentsOfDirectory(at: sessionsDirectory, includingPropertiesForKeys: nil)
            var sessions: [CaptureSession] = []
            
            for directory in sessionDirectories {
                let sessionId = extractSessionId(from: directory)
                if let sessionId = sessionId,
                   let session = try await loadSession(id: sessionId) {
                    sessions.append(session)
                }
            }
            
            // Sort by creation date (newest first)
            sessions.sort { $0.createdAt > $1.createdAt }
            
            logger.debug("Loaded \(sessions.count) sessions")
            return sessions
        } catch {
            logger.error("Failed to get all sessions: \(error.localizedDescription)")
            throw StorageError.fileSystemError
        }
    }
    
    func getSessionsCount() async throws -> Int {
        let sessions = try await getAllSessions()
        return sessions.count
    }
    
    func getStorageUsed() async throws -> Int64 {
        guard fileManager.fileExists(atPath: sessionsDirectory.path) else {
            return 0
        }
        
        do {
            let sessionDirectories = try fileManager.contentsOfDirectory(at: sessionsDirectory, includingPropertiesForKeys: [.fileSizeKey])
            var totalSize: Int64 = 0
            
            for directory in sessionDirectories {
                let size = try directory.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                totalSize += Int64(size)
            }
            
            return totalSize
        } catch {
            logger.error("Failed to calculate storage used: \(error.localizedDescription)")
            throw StorageError.fileSystemError
        }
    }
    
    func getAvailableStorage() async throws -> Int64 {
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: documentsDirectory.path)
            let freeSize = attributes[.systemFreeSize] as? NSNumber
            return freeSize?.int64Value ?? 0
        } catch {
            logger.error("Failed to get available storage: \(error.localizedDescription)")
            throw StorageError.fileSystemError
        }
    }
    
    // MARK: - Helper Methods
    
    private func createSessionsDirectoryIfNeeded() {
        guard !fileManager.fileExists(atPath: sessionsDirectory.path) else {
            return
        }
        
        do {
            try fileManager.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
            logger.info("Created sessions directory: \(self.sessionsDirectory.path)")
        } catch {
            logger.error("Failed to create sessions directory: \(error.localizedDescription)")
        }
    }
    
    private func getSessionMetadataURL(for sessionId: UUID) -> URL {
        let sessionDirectory = getSessionDirectoryURL(for: sessionId)
        return sessionDirectory.appendingPathComponent("session.json")
    }
    
    private func getSessionDirectoryURL(for sessionId: UUID) -> URL {
        return sessionsDirectory.appendingPathComponent(sessionId.uuidString)
    }
    
    
    private func extractSessionId(from directory: URL) -> UUID? {
        let directoryName = directory.lastPathComponent
        
        // Try to extract UUID from directory name
        if let sessionId = UUID(uuidString: directoryName) {
            return sessionId
        }
        
        // Try to extract from session.json file
        let sessionURL = directory.appendingPathComponent("session.json")
        guard fileManager.fileExists(atPath: sessionURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: sessionURL)
            let session = try JSONDecoder().decode(CaptureSession.self, from: data)
            return session.id
        } catch {
            return nil
        }
    }
    
    // MARK: - Storage Monitoring
    
    func checkStorageStatus() async -> StorageStatus {
        do {
            let used = try await getStorageUsed()
            let available = try await getAvailableStorage()
            let total = used + available
            
            let usagePercentage = Double(used) / Double(total)
            
            if usagePercentage > 0.9 {
                onStorageFull?()
                return .full
            } else if usagePercentage > 0.8 {
                return .warning
            } else {
                return .normal
            }
        } catch {
            onStorageError?(.fileSystemError)
            return .error
        }
    }
    
    func getStorageStatusDescription() async -> String {
        let status = await checkStorageStatus()
        
        switch status {
        case .normal:
            return "Storage normal"
        case .warning:
            return "Storage warning - consider cleanup"
        case .full:
            return "Storage full - cleanup required"
        case .error:
            return "Storage error"
        }
    }
}

// MARK: - Supporting Types

enum StorageStatus {
    case normal
    case warning
    case full
    case error
}

// MARK: - StorageError Extension

extension StorageError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .sessionNotFound:
            return "Session not found"
        case .photoNotFound:
            return "Photo not found"
        case .storageFull:
            return "Storage full"
        case .fileSystemError:
            return "File system error"
        case .permissionDenied:
            return "Permission denied"
        case .invalidPath:
            return "Invalid path"
        case .dataCorruption:
            return "Data corruption"
        }
    }
}
