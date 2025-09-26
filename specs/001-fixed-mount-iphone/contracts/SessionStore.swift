// SessionStore.swift - API Contract
// File system storage and session management

import Foundation

protocol SessionStoreProtocol {
    // Session management
    func createSession(stockNumber: String) async throws -> CaptureSession
    func loadSession(id: UUID) async throws -> CaptureSession?
    func saveSession(_ session: CaptureSession) async throws
    func deleteSession(id: UUID) async throws
    
    // Photo storage
    func savePhoto(_ photo: PhotoCapture, imageData: Data) async throws -> URL
    func loadPhotoData(for photo: PhotoCapture) async throws -> Data
    func deletePhoto(_ photo: PhotoCapture) async throws
    
    // File management
    func createSessionDirectory(for session: CaptureSession) async throws -> URL
    func generatePhotoFilename(for photo: PhotoCapture) -> String
    func getSessionDirectoryURL(for session: CaptureSession) -> URL
    
    // Storage queries
    func getAllSessions() async throws -> [CaptureSession]
    func getSessionsCount() async throws -> Int
    func getStorageUsed() async throws -> Int64
    func getAvailableStorage() async throws -> Int64
    
    // Error handling
    var onStorageFull: (() -> Void)? { get set }
    var onStorageError: ((StorageError) -> Void)? { get set }
}

enum StorageError: Error {
    case sessionNotFound
    case photoNotFound
    case storageFull
    case fileSystemError
    case permissionDenied
    case invalidPath
    case dataCorruption
}

// Implementation requirements:
// - Must create session folders: Sessions/{stock}-{YYYYMMDD-HHmmss}/
// - Must name photos: {01..08}_{Viewpoint}_{YYYYMMDD-HHmmss}.jpg
// - Must handle storage full scenarios gracefully
// - Must provide atomic file operations (fsync after writes)
// - Must support concurrent access safely
// - Must validate all file paths and permissions
// - Must handle device storage monitoring
// - Must provide storage usage statistics
// - Must support session cleanup and deletion
