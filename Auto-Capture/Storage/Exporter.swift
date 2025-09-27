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
        let zipURL = sessionDirectory.appendingPathComponent(zipFileName(for: session))

        // Create ZIP file
        try await createZipFile(from: sessionDirectory, to: zipURL)

        logger.info("Created ZIP file: \(zipURL.lastPathComponent)")
        return zipURL
    }
    
    private func createZipFile(from sourceDirectory: URL, to destinationURL: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    if self.fileManager.fileExists(atPath: destinationURL.path) {
                        try self.fileManager.removeItem(at: destinationURL)
                    }

                    guard let enumerator = self.fileManager.enumerator(
                        at: sourceDirectory,
                        includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                        options: [.skipsHiddenFiles]
                    ) else {
                        continuation.resume(throwing: ExportError.fileSystemError)
                        return
                    }

                    var entries: [ZipEntry] = []
                    for case let fileURL as URL in enumerator {
                        let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey])
                        guard values.isRegularFile == true else { continue }
                        let relativePath = fileURL.path.replacingOccurrences(of: sourceDirectory.path + "/", with: "")
                        let data = try Data(contentsOf: fileURL)
                        let modificationDate = values.contentModificationDate ?? Date()
                        entries.append(ZipEntry(name: relativePath, data: data, modificationDate: modificationDate))
                    }

                    let zipData = try self.buildZipData(from: entries)
                    try zipData.write(to: destinationURL, options: .atomic)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: ExportError.zipCreationFailed)
                }
            }
        }
    }

    private func zipFileName(for session: CaptureSession) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: session.createdAt)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return "\(session.stockNumber)-\(timestamp)-v\(version).zip"
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

// MARK: - ZIP Utilities

private extension Exporter {
    struct ZipEntry {
        let name: String
        let data: Data
        let modificationDate: Date
    }

    func buildZipData(from entries: [ZipEntry]) throws -> Data {
        var localFileSection = Data()
        var centralDirectory = Data()
        for entry in entries {
            let nameData = Data(entry.name.utf8)
            let crc = entry.data.crc32()
            let (dosTime, dosDate) = dosDateTime(from: entry.modificationDate)
            let localHeaderOffset = UInt32(localFileSection.count)

            // Local file header
            localFileSection.append(UInt32(0x04034B50))
            localFileSection.append(UInt16(20))
            localFileSection.append(UInt16(0))
            localFileSection.append(UInt16(0))
            localFileSection.append(dosTime)
            localFileSection.append(dosDate)
            localFileSection.append(crc)
            localFileSection.append(UInt32(entry.data.count))
            localFileSection.append(UInt32(entry.data.count))
            localFileSection.append(UInt16(nameData.count))
            localFileSection.append(UInt16(0))
            localFileSection.append(nameData)
            localFileSection.append(entry.data)

            // Central directory header
            centralDirectory.append(UInt32(0x02014B50))
            centralDirectory.append(UInt16(0x0314))
            centralDirectory.append(UInt16(20))
            centralDirectory.append(UInt16(0))
            centralDirectory.append(UInt16(0))
            centralDirectory.append(dosTime)
            centralDirectory.append(dosDate)
            centralDirectory.append(crc)
            centralDirectory.append(UInt32(entry.data.count))
            centralDirectory.append(UInt32(entry.data.count))
            centralDirectory.append(UInt16(nameData.count))
            centralDirectory.append(UInt16(0))
            centralDirectory.append(UInt16(0))
            centralDirectory.append(UInt16(0))
            centralDirectory.append(UInt16(0))
            centralDirectory.append(UInt32(0))
            centralDirectory.append(localHeaderOffset)
            centralDirectory.append(nameData)
        }

        let centralDirectoryOffset = UInt32(localFileSection.count)
        let centralDirectorySize = UInt32(centralDirectory.count)

        var endRecord = Data()
        endRecord.append(UInt32(0x06054B50))
        endRecord.append(UInt16(0))
        endRecord.append(UInt16(0))
        endRecord.append(UInt16(entries.count))
        endRecord.append(UInt16(entries.count))
        endRecord.append(centralDirectorySize)
        endRecord.append(centralDirectoryOffset)
        endRecord.append(UInt16(0))

        var zipData = Data(capacity: localFileSection.count + centralDirectory.count + endRecord.count)
        zipData.append(localFileSection)
        zipData.append(centralDirectory)
        zipData.append(endRecord)
        return zipData
    }

    func dosDateTime(from date: Date) -> (UInt16, UInt16) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)

        let year = UInt16(max(1980, min(2107, components.year ?? 1980)))
        let month = UInt16(components.month ?? 1)
        let day = UInt16(components.day ?? 1)
        let hour = UInt16(components.hour ?? 0)
        let minute = UInt16(components.minute ?? 0)
        let second = UInt16((components.second ?? 0) / 2)

        let dosDate = ((year - 1980) << 9) | (month << 5) | day
        let dosTime = (hour << 11) | (minute << 5) | second
        return (UInt16(dosTime), UInt16(dosDate))
    }
}

private extension Data {
    mutating func append<T: FixedWidthInteger>(_ value: T) {
        var littleEndianValue = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { buffer in
            append(contentsOf: buffer)
        }
    }
}

private extension Data {
    func crc32() -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in self {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ CRC32Table[index]
        }
        return crc ^ 0xFFFF_FFFF
    }
}

private let CRC32Table: [UInt32] = {
    (0..<256).map { index -> UInt32 in
        var crc = UInt32(index)
        for _ in 0..<8 {
            if crc & 1 == 1 {
                crc = (crc >> 1) ^ 0xEDB88320
            } else {
                crc >>= 1
            }
        }
        return crc
    }
}()

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
