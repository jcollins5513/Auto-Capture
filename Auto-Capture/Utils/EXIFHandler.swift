import Foundation
import ImageIO
import CoreLocation
import CoreGraphics
import OSLog

/// Handles EXIF metadata operations for captured photos
final class EXIFHandler {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "AutoCapture", category: "EXIFHandler")
    
    // MARK: - EXIF Writing
    
    func writeEXIFData(_ exifData: EXIFData, to imageData: Data) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                do {
                    let result = try self?.writeEXIFDataInternal(exifData, to: imageData)
                    continuation.resume(returning: result ?? imageData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func writeEXIFDataInternal(_ exifData: EXIFData, to imageData: Data) throws -> Data {
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let imageType = CGImageSourceGetType(imageSource) else {
            throw EXIFError.invalidImageData
        }
        
        // Create mutable copy of image data
        guard let imageDestination = CGImageDestinationCreateWithData(NSMutableData(), imageType, 1, nil) else {
            throw EXIFError.destinationCreationFailed
        }
        
        // Get original image properties
        guard let originalProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            throw EXIFError.propertiesNotFound
        }
        
        // Create updated properties with EXIF data
        var updatedProperties = originalProperties
        var exifProperties: [CFString: Any] = [:]
        
        // Add custom EXIF data
        exifProperties[kCGImagePropertyExifUserComment] = createUserComment(exifData)
        exifProperties[kCGImagePropertyExifUserComment] = "Auto-Capture \(exifData.appVersion)"
        exifProperties[kCGImagePropertyExifDateTimeOriginal] = createDateTimeString(exifData.captureTimestamp)
        exifProperties[kCGImagePropertyExifDateTimeDigitized] = createDateTimeString(exifData.captureTimestamp)
        
        // Add camera settings if available
        if let cameraSettings = exifData.cameraSettings {
            exifProperties[kCGImagePropertyExifISOSpeedRatings] = [Int(cameraSettings.iso)]
            exifProperties[kCGImagePropertyExifFNumber] = cameraSettings.aperture
            exifProperties[kCGImagePropertyExifFocalLength] = cameraSettings.focalLength
            exifProperties[kCGImagePropertyExifExposureTime] = cameraSettings.shutterSpeed
        }
        
        // Update EXIF properties
        updatedProperties[kCGImagePropertyExifDictionary] = exifProperties
        
        // Add custom metadata
        var tiffProperties: [CFString: Any] = [:]
        tiffProperties[kCGImagePropertyTIFFSoftware] = "Auto-Capture \(exifData.appVersion)"
        tiffProperties[kCGImagePropertyTIFFDateTime] = createDateTimeString(exifData.captureTimestamp)
        updatedProperties[kCGImagePropertyTIFFDictionary] = tiffProperties
        
        // Add custom metadata dictionary
        var customMetadata: [CFString: Any] = [:]
        customMetadata["AutoCapture.StockNumber" as CFString] = exifData.stockNumber as CFString
        customMetadata["AutoCapture.Viewpoint" as CFString] = exifData.viewpoint as CFString
        customMetadata["AutoCapture.SessionId" as CFString] = exifData.sessionId as CFString
        customMetadata["AutoCapture.AppVersion" as CFString] = exifData.appVersion as CFString
        customMetadata["AutoCapture.DeviceModel" as CFString] = exifData.deviceModel as CFString
        customMetadata["AutoCapture.IOSVersion" as CFString] = exifData.iosVersion as CFString
        
        updatedProperties["AutoCapture" as CFString] = customMetadata
        
        // Add image to destination with updated properties
        CGImageDestinationAddImageFromSource(imageDestination, imageSource, 0, updatedProperties as CFDictionary)
        
        // Finalize the destination
        guard CGImageDestinationFinalize(imageDestination) else {
            throw EXIFError.finalizationFailed
        }
        
        // Get the final data
        guard let finalData = CGImageDestinationCreateData(imageDestination) as Data? else {
            throw EXIFError.dataCreationFailed
        }
        
        logger.debug("EXIF data written successfully")
        return finalData
    }
    
    // MARK: - EXIF Reading
    
    func readEXIFData(from imageData: Data) async throws -> EXIFData? {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                do {
                    let result = try self?.readEXIFDataInternal(from: imageData)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func readEXIFDataInternal(from imageData: Data) throws -> EXIFData? {
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            throw EXIFError.invalidImageData
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            return nil
        }
        
        // Extract custom metadata
        guard let customMetadata = properties["AutoCapture" as CFString] as? [CFString: Any] else {
            return nil
        }
        
        let stockNumber = customMetadata["AutoCapture.StockNumber" as CFString] as? String ?? ""
        let viewpoint = customMetadata["AutoCapture.Viewpoint" as CFString] as? String ?? ""
        let sessionId = customMetadata["AutoCapture.SessionId" as CFString] as? String ?? ""
        let appVersion = customMetadata["AutoCapture.AppVersion" as CFString] as? String ?? ""
        let deviceModel = customMetadata["AutoCapture.DeviceModel" as CFString] as? String ?? ""
        let iosVersion = customMetadata["AutoCapture.IOSVersion" as CFString] as? String ?? ""
        
        // Parse timestamp from EXIF
        let captureTimestamp = parseTimestamp(from: properties)
        
        // Extract camera settings
        let cameraSettings = extractCameraSettings(from: properties)
        
        return EXIFData(
            stockNumber: stockNumber,
            viewpoint: viewpoint,
            sessionId: sessionId,
            appVersion: appVersion,
            captureTimestamp: captureTimestamp,
            deviceModel: deviceModel,
            iosVersion: iosVersion,
            cameraSettings: cameraSettings
        )
    }
    
    // MARK: - Helper Methods
    
    private func createUserComment(_ exifData: EXIFData) -> String {
        var comment = "Auto-Capture Session\n"
        comment += "Stock: \(exifData.stockNumber)\n"
        comment += "Viewpoint: \(exifData.viewpoint)\n"
        comment += "Session: \(exifData.sessionId)\n"
        comment += "App: \(exifData.appVersion)\n"
        comment += "Device: \(exifData.deviceModel)\n"
        comment += "iOS: \(exifData.iosVersion)"
        
        return comment
    }
    
    private func createDateTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func parseTimestamp(from properties: [CFString: Any]) -> Date {
        // Try to get timestamp from EXIF
        if let exifProperties = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let dateTimeString = exifProperties[kCGImagePropertyExifDateTimeOriginal] as? String {
            return parseDateTimeString(dateTimeString) ?? Date()
        }
        
        // Try to get timestamp from TIFF
        if let tiffProperties = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           let dateTimeString = tiffProperties[kCGImagePropertyTIFFDateTime] as? String {
            return parseDateTimeString(dateTimeString) ?? Date()
        }
        
        return Date()
    }
    
    private func parseDateTimeString(_ dateTimeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: dateTimeString)
    }
    
    private func extractCameraSettings(from properties: [CFString: Any]) -> CameraSettings? {
        guard let exifProperties = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] else {
            return nil
        }
        
        let iso = exifProperties[kCGImagePropertyExifISOSpeedRatings] as? [Int] ?? [100]
        let aperture = exifProperties[kCGImagePropertyExifFNumber] as? Float ?? 2.8
        let focalLength = exifProperties[kCGImagePropertyExifFocalLength] as? Float ?? 26.0
        let shutterSpeed = exifProperties[kCGImagePropertyExifExposureTime] as? Float ?? 1.0/60.0
        
        return CameraSettings(
            iso: Float(iso.first ?? 100),
            shutterSpeed: shutterSpeed,
            aperture: aperture,
            focalLength: focalLength,
            flashMode: .off,
            whiteBalance: .auto,
            exposureMode: .auto
        )
    }
    
    // MARK: - Validation
    
    func validateEXIFData(_ exifData: EXIFData) -> Bool {
        return exifData.isValid
    }
    
    func getEXIFSummary(_ exifData: EXIFData) -> String {
        return exifData.captureSummary
    }
    
    // MARK: - Utility Methods
    
    func stripEXIFData(from imageData: Data) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                do {
                    let result = try self?.stripEXIFDataInternal(from: imageData)
                    continuation.resume(returning: result ?? imageData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func stripEXIFDataInternal(from imageData: Data) throws -> Data {
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let imageType = CGImageSourceGetType(imageSource) else {
            throw EXIFError.invalidImageData
        }
        
        guard let imageDestination = CGImageDestinationCreateWithData(NSMutableData(), imageType, 1, nil) else {
            throw EXIFError.destinationCreationFailed
        }
        
        // Add image without properties (strips EXIF)
        CGImageDestinationAddImageFromSource(imageDestination, imageSource, 0, nil)
        
        guard CGImageDestinationFinalize(imageDestination) else {
            throw EXIFError.finalizationFailed
        }
        
        guard let finalData = CGImageDestinationCreateData(imageDestination) as Data? else {
            throw EXIFError.dataCreationFailed
        }
        
        logger.debug("EXIF data stripped successfully")
        return finalData
    }
}

// MARK: - EXIFError

enum EXIFError: Error, LocalizedError {
    case invalidImageData
    case destinationCreationFailed
    case propertiesNotFound
    case finalizationFailed
    case dataCreationFailed
    case unsupportedImageType
    
    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Invalid image data"
        case .destinationCreationFailed:
            return "Failed to create image destination"
        case .propertiesNotFound:
            return "Image properties not found"
        case .finalizationFailed:
            return "Failed to finalize image destination"
        case .dataCreationFailed:
            return "Failed to create final image data"
        case .unsupportedImageType:
            return "Unsupported image type"
        }
    }
}

// MARK: - EXIFHandler Extensions

extension EXIFHandler {
    
    /// Gets the file size of an image with EXIF data
    func getImageFileSize(_ imageData: Data) -> Int64 {
        return Int64(imageData.count)
    }
    
    /// Gets the file size as a human-readable string
    func getImageFileSizeString(_ imageData: Data) -> String {
        let size = getImageFileSize(imageData)
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    /// Checks if an image has EXIF data
    func hasEXIFData(_ imageData: Data) -> Bool {
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return false
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            return false
        }
        
        return properties[kCGImagePropertyExifDictionary] != nil
    }
    
    /// Gets the creation date from EXIF data
    func getCreationDate(_ imageData: Data) -> Date? {
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return nil
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            return nil
        }
        
        return parseTimestamp(from: properties)
    }
}
