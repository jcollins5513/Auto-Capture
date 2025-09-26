import Foundation

/// Represents a single captured photo within a session
struct PhotoCapture: Codable, Identifiable {
    let id: UUID
    let sessionId: UUID
    let viewpoint: Viewpoint
    let order: Int
    let capturedAt: Date
    var filePath: String
    let confidence: Float
    var isRetake: Bool
    var originalPhotoId: UUID?
    let exifData: EXIFData
    
    init(
        id: UUID = UUID(),
        sessionId: UUID,
        viewpoint: Viewpoint,
        order: Int,
        capturedAt: Date = Date(),
        filePath: String,
        confidence: Float,
        isRetake: Bool = false,
        originalPhotoId: UUID? = nil,
        exifData: EXIFData
    ) {
        self.id = id
        self.sessionId = sessionId
        self.viewpoint = viewpoint
        self.order = order
        self.capturedAt = capturedAt
        self.filePath = filePath
        self.confidence = confidence
        self.isRetake = isRetake
        self.originalPhotoId = originalPhotoId
        self.exifData = exifData
    }
    
    /// Validates the photo capture data
    var isValid: Bool {
        return order >= 1 && order <= 8 &&
               confidence >= 0.0 && confidence <= 1.0 &&
               !filePath.isEmpty &&
               isValidRetakeLogic
    }
    
    /// Validates retake logic
    private var isValidRetakeLogic: Bool {
        if isRetake {
            return originalPhotoId != nil
        } else {
            return originalPhotoId == nil
        }
    }
    
    /// Creates a retake photo from an original photo
    static func createRetake(
        from originalPhoto: PhotoCapture,
        newConfidence: Float,
        newFilePath: String
    ) -> PhotoCapture {
        return PhotoCapture(
            sessionId: originalPhoto.sessionId,
            viewpoint: originalPhoto.viewpoint,
            order: originalPhoto.order,
            capturedAt: Date(),
            filePath: newFilePath,
            confidence: newConfidence,
            isRetake: true,
            originalPhotoId: originalPhoto.id,
            exifData: EXIFData(
                stockNumber: originalPhoto.exifData.stockNumber,
                viewpoint: originalPhoto.exifData.viewpoint,
                sessionId: originalPhoto.exifData.sessionId,
                appVersion: originalPhoto.exifData.appVersion,
                captureTimestamp: Date(),
                deviceModel: originalPhoto.exifData.deviceModel,
                iosVersion: originalPhoto.exifData.iosVersion,
                cameraSettings: originalPhoto.exifData.cameraSettings
            )
        )
    }
    
    /// Checks if this photo meets the confidence threshold
    func meetsConfidenceThreshold(_ threshold: Float) -> Bool {
        return confidence >= threshold
    }
    
    /// Gets the confidence as a percentage string
    var confidencePercentage: String {
        return String(format: "%.1f%%", confidence * 100)
    }
    
    /// Gets the capture time as a formatted string
    var captureTimeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: capturedAt)
    }
    
    /// Gets the capture date as a formatted string
    var captureDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: capturedAt)
    }
    
    /// Gets the full capture timestamp as a formatted string
    var captureTimestampString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: capturedAt)
    }
    
    /// Checks if the photo file exists
    var fileExists: Bool {
        return FileManager.default.fileExists(atPath: filePath)
    }
    
    /// Gets the file size in bytes
    var fileSize: Int64? {
        guard fileExists else { return nil }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }
    
    /// Gets the file size as a human-readable string
    var fileSizeString: String {
        guard let size = fileSize else { return "Unknown" }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    /// Gets the file URL
    var fileURL: URL {
        return URL(fileURLWithPath: filePath)
    }
    
    /// Gets the filename from the file path
    var filename: String {
        return fileURL.lastPathComponent
    }
    
    /// Gets the directory containing the file
    var directory: String {
        return fileURL.deletingLastPathComponent().path
    }
    
    /// Checks if this is a high-confidence capture
    var isHighConfidence: Bool {
        return confidence >= 0.9
    }
    
    /// Checks if this is a low-confidence capture
    var isLowConfidence: Bool {
        return confidence < 0.7
    }
    
    /// Gets the confidence level description
    var confidenceLevel: String {
        if isHighConfidence {
            return "High"
        } else if isLowConfidence {
            return "Low"
        } else {
            return "Medium"
        }
    }
    
    /// Gets the confidence level color (for UI)
    var confidenceColor: String {
        if isHighConfidence {
            return "green"
        } else if isLowConfidence {
            return "red"
        } else {
            return "yellow"
        }
    }
    
    /// Checks if this photo was captured automatically
    var wasAutoCaptured: Bool {
        return confidence >= 0.85 // Auto-capture threshold
    }
    
    /// Checks if this photo was captured manually
    var wasManuallyCaptured: Bool {
        return !wasAutoCaptured
    }
    
    /// Gets the capture method description
    var captureMethod: String {
        return wasAutoCaptured ? "Auto" : "Manual"
    }
    
    /// Calculates the time since capture
    var timeSinceCapture: TimeInterval {
        return Date().timeIntervalSince(capturedAt)
    }
    
    /// Gets a human-readable string for time since capture
    var timeSinceCaptureString: String {
        let interval = timeSinceCapture
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
}

// MARK: - Equatable
extension PhotoCapture: Equatable {
    static func == (lhs: PhotoCapture, rhs: PhotoCapture) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Hashable
extension PhotoCapture: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Comparable
extension PhotoCapture: Comparable {
    static func < (lhs: PhotoCapture, rhs: PhotoCapture) -> Bool {
        return lhs.order < rhs.order
    }
}

// MARK: - CustomStringConvertible
extension PhotoCapture: CustomStringConvertible {
    var description: String {
        return "PhotoCapture(id: \(id.uuidString.prefix(8))..., viewpoint: \(viewpoint.rawValue), order: \(order), confidence: \(confidencePercentage))"
    }
}
