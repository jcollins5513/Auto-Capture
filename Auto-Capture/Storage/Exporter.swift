import Foundation
import OSLog
import UniformTypeIdentifiers

/// Handles session export functionality
final class Exporter {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "AutoCapture", category: "Exporter")
    private let fileManager = FileManager.default
    private let sessionStore: SessionStoreProtocol
    
    // MARK: - Initialization
    
    init(sessionStore: SessionStoreProtocol) {
        self.sessionStore = sessionStore
    }
    
    // MARK: - Export Methods
    
    func exportSession(_ session: CaptureSession, to target: ExportTarget) async throws -> ExportResult {
        logger.info("Exporting session: \(session.id.uuidString) to \(target.rawValue)")
        
        switch target {
        case .shareSheet:
            return try await exportToShareSheet(session)
        case .files:
            return try await exportToFiles(session)
        case .s3:
            return try await exportToS3(session)
        case .webdav:
            return try await exportToWebDAV(session)
        }
    }
    
    private func exportToShareSheet(_ session: CaptureSession) async throws -> ExportResult {
        // Create ZIP file
        let zipURL = try await createZipFile(for: session)
        
        return ExportResult(
            success: true,
            fileURL: zipURL,
            target: .shareSheet,
            message: "Session exported to Share Sheet"
        )
    }
    
    private func exportToFiles(_ session: CaptureSession) async throws -> ExportResult {
        // Create ZIP file
        let zipURL = try await createZipFile(for: session)
        
        // Copy to Files app
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filesURL = documentsURL.appendingPathComponent("Auto-Capture Exports")
        
        // Create exports directory if needed
        if !fileManager.fileExists(atPath: filesURL.path) {
            try fileManager.createDirectory(at: filesURL, withIntermediateDirectories: true)
        }
        
        let destinationURL = filesURL.appendingPathComponent(zipURL.lastPathComponent)
        
        // Copy file
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: zipURL, to: destinationURL)
        
        return ExportResult(
            success: true,
            fileURL: destinationURL,
            target: .files,
            message: "Session exported to Files app"
        )
    }
    
    private func exportToS3(_ session: CaptureSession) async throws -> ExportResult {
        // TODO: Implement S3 export
        throw ExportError.notImplemented
    }
    
    private func exportToWebDAV(_ session: CaptureSession) async throws -> ExportResult {
        // TODO: Implement WebDAV export
        throw ExportError.notImplemented
    }
    
    // MARK: - ZIP Creation
    
    private func createZipFile(for session: CaptureSession) async throws -> URL {
        let sessionDirectory = sessionStore.getSessionDirectoryURL(for: session)
        let zipURL = sessionDirectory.appendingPathComponent("\(session.stockNumber)-\(session.id.uuidString).zip")
        
        // Create ZIP file
        try await createZipFile(from: sessionDirectory, to: zipURL)
        
        logger.info("Created ZIP file: \(zipURL.lastPathComponent)")
        return zipURL
    }
    
    private func createZipFile(from sourceDirectory: URL, to destinationURL: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // Use system zip command for better performance
                    // For now, use a simple file copy approach
                    // TODO: Implement proper zip functionality
                    try FileManager.default.copyItem(at: sourceDirectory, to: destinationURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: ExportError.zipCreationFailed)
                }
            }
        }
    }
    
    // MARK: - Export Validation
    
    func validateExport(_ session: CaptureSession) async throws -> ExportValidation {
        // Check if session is complete
        guard session.isComplete else {
            return ExportValidation(
                isValid: false,
                issues: ["Session is not complete"],
                recommendations: ["Complete all 8 viewpoints before exporting"]
            )
        }
        
        // Check if all photos exist
        var issues: [String] = []
        var recommendations: [String] = []
        
        for photo in session.photos {
            if !photo.fileExists {
                issues.append("Photo file missing: \(photo.filename)")
                recommendations.append("Check file system integrity")
            }
        }
        
        // Check storage space
        let availableStorage = try await sessionStore.getAvailableStorage()
        if availableStorage < 100 * 1024 * 1024 { // 100MB
            issues.append("Low storage space")
            recommendations.append("Free up device storage")
        }
        
        return ExportValidation(
            isValid: issues.isEmpty,
            issues: issues,
            recommendations: recommendations
        )
    }
    
    // MARK: - Export History
    
    func getExportHistory() async throws -> [ExportRecord] {
        // TODO: Implement export history tracking
        return []
    }
    
    func addExportRecord(_ record: ExportRecord) async throws {
        // TODO: Implement export record storage
    }
    
    // MARK: - Cleanup
    
    func cleanupTempFiles() async throws {
        let tempDirectory = fileManager.temporaryDirectory
        let tempFiles = try fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
        
        for file in tempFiles {
            if file.pathExtension == "zip" && file.lastPathComponent.contains("Auto-Capture") {
                try fileManager.removeItem(at: file)
                logger.debug("Cleaned up temp file: \(file.lastPathComponent)")
            }
        }
    }
}

// MARK: - Supporting Types

struct ExportResult {
    let success: Bool
    let fileURL: URL?
    let target: ExportTarget
    let message: String
    let error: Error?
    
    init(success: Bool, fileURL: URL?, target: ExportTarget, message: String, error: Error? = nil) {
        self.success = success
        self.fileURL = fileURL
        self.target = target
        self.message = message
        self.error = error
    }
}

struct ExportValidation {
    let isValid: Bool
    let issues: [String]
    let recommendations: [String]
}

struct ExportRecord {
    let id: UUID
    let sessionId: UUID
    let exportDate: Date
    let target: ExportTarget
    let fileSize: Int64
    let success: Bool
    let error: String?
}

enum ExportError: Error, LocalizedError {
    case notImplemented
    case zipCreationFailed
    case fileSystemError
    case networkError
    case authenticationFailed
    case invalidSession
    case storageFull
    
    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "Export method not implemented"
        case .zipCreationFailed:
            return "Failed to create ZIP file"
        case .fileSystemError:
            return "File system error"
        case .networkError:
            return "Network error"
        case .authenticationFailed:
            return "Authentication failed"
        case .invalidSession:
            return "Invalid session"
        case .storageFull:
            return "Storage full"
        }
    }
}

// MARK: - Exporter Extensions

extension Exporter {
    
    /// Gets the export file size
    func getExportFileSize(for session: CaptureSession) async throws -> Int64 {
        let zipURL = try await createZipFile(for: session)
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: zipURL.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            throw ExportError.fileSystemError
        }
    }
    
    /// Gets the export file size as a human-readable string
    func getExportFileSizeString(for session: CaptureSession) async throws -> String {
        let size = try await getExportFileSize(for: session)
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    /// Checks if export is ready
    func isExportReady(for session: CaptureSession) async -> Bool {
        do {
            let validation = try await validateExport(session)
            return validation.isValid
        } catch {
            return false
        }
    }
    
    /// Gets export status description
    func getExportStatusDescription(for session: CaptureSession) async -> String {
        let isReady = await isExportReady(for: session)
        
        if isReady {
            return "Ready for export"
        } else {
            return "Export not ready - check session completion"
        }
    }
}
