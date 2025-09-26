import Foundation
import ImageIO
import OSLog

/// Background queue service for JPEG encoding and image processing
final class EncodingService {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "AutoCapture", category: "EncodingService")
    private let encodingQueue = DispatchQueue(label: "com.autocapture.encoding", qos: .userInitiated)
    private let compressionQueue = DispatchQueue(label: "com.autocapture.compression", qos: .utility)
    
    private var _isEncoding = false
    private var _encodingProgress: Float = 0.0
    private var _currentEncodingTask: EncodingTask?
    
    // Event handlers
    var onEncodingStart: (() -> Void)?
    var onEncodingProgress: ((Float) -> Void)?
    var onEncodingComplete: ((EncodingResult) -> Void)?
    var onEncodingError: ((EncodingError) -> Void)?
    
    // MARK: - Computed Properties
    
    var isEncoding: Bool {
        return _isEncoding
    }
    
    var encodingProgress: Float {
        return _encodingProgress
    }
    
    var currentEncodingTask: EncodingTask? {
        return _currentEncodingTask
    }
    
    // MARK: - JPEG Encoding
    
    func encodeJPEG(
        from imageData: Data,
        quality: Float = 0.9,
        maxSize: CGSize? = nil
    ) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            encodingQueue.async { [weak self] in
                do {
                    let result = try self?.encodeJPEGInternal(
                        from: imageData,
                        quality: quality,
                        maxSize: maxSize
                    )
                    continuation.resume(returning: result ?? imageData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func encodeJPEGInternal(
        from imageData: Data,
        quality: Float,
        maxSize: CGSize?
    ) throws -> Data {
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            throw EncodingError.invalidImageData
        }
        
        guard let imageType = CGImageSourceGetType(imageSource) else {
            throw EncodingError.unsupportedImageType
        }
        
        // Create image destination
        guard let imageDestination = CGImageDestinationCreateWithData(NSMutableData(), imageType, 1, nil) else {
            throw EncodingError.destinationCreationFailed
        }
        
        // Get original image properties
        guard let originalProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            throw EncodingError.propertiesNotFound
        }
        
        // Create updated properties
        var updatedProperties = originalProperties
        
        // Set JPEG quality
        updatedProperties[kCGImageDestinationLossyCompressionQuality] = quality
        
        // Resize image if needed
        if let maxSize = maxSize {
            updatedProperties[kCGImageDestinationImageMaxPixelSize] = max(maxSize.width, maxSize.height)
        }
        
        // Add image to destination
        CGImageDestinationAddImageFromSource(imageDestination, imageSource, 0, updatedProperties as CFDictionary)
        
        // Finalize destination
        guard CGImageDestinationFinalize(imageDestination) else {
            throw EncodingError.finalizationFailed
        }
        
        // Get final data
        guard let finalData = CGImageDestinationCreateData(imageDestination) as Data? else {
            throw EncodingError.dataCreationFailed
        }
        
        logger.debug("JPEG encoded successfully with quality: \(quality)")
        return finalData
    }
    
    // MARK: - Batch Encoding
    
    func encodeBatch(
        images: [ImageEncodingTask],
        quality: Float = 0.9,
        maxSize: CGSize? = nil
    ) async throws -> [EncodingResult] {
        _isEncoding = true
        _encodingProgress = 0.0
        _currentEncodingTask = EncodingTask(
            id: UUID(),
            totalImages: images.count,
            completedImages: 0,
            startTime: Date()
        )
        
        onEncodingStart?()
        
        var results: [EncodingResult] = []
        
        for (index, imageTask) in images.enumerated() {
            do {
                let encodedData = try await encodeJPEG(
                    from: imageTask.imageData,
                    quality: quality,
                    maxSize: maxSize
                )
                
                let result = EncodingResult(
                    success: true,
                    originalSize: imageTask.imageData.count,
                    encodedSize: encodedData.count,
                    compressionRatio: Float(encodedData.count) / Float(imageTask.imageData.count),
                    processingTime: 0.0, // TODO: Track processing time
                    error: nil
                )
                
                results.append(result)
                
                // Update progress
                _encodingProgress = Float(index + 1) / Float(images.count)
                _currentEncodingTask?.completedImages = index + 1
                onEncodingProgress?(_encodingProgress)
                
            } catch {
                let result = EncodingResult(
                    success: false,
                    originalSize: imageTask.imageData.count,
                    encodedSize: 0,
                    compressionRatio: 0.0,
                    processingTime: 0.0,
                    error: error
                )
                
                results.append(result)
                onEncodingError?(.encodingFailed(error))
            }
        }
        
        _isEncoding = false
        _encodingProgress = 1.0
        _currentEncodingTask = nil
        
        onEncodingComplete?(EncodingResult(
            success: true,
            originalSize: 0,
            encodedSize: 0,
            compressionRatio: 0.0,
            processingTime: 0.0,
            error: nil
        ))
        
        return results
    }
    
    // MARK: - Image Compression
    
    func compressImage(
        _ imageData: Data,
        targetSize: CGSize,
        quality: Float = 0.8
    ) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            compressionQueue.async { [weak self] in
                do {
                    let result = try self?.compressImageInternal(
                        imageData,
                        targetSize: targetSize,
                        quality: quality
                    )
                    continuation.resume(returning: result ?? imageData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func compressImageInternal(
        _ imageData: Data,
        targetSize: CGSize,
        quality: Float
    ) throws -> Data {
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            throw EncodingError.invalidImageData
        }
        
        guard let imageType = CGImageSourceGetType(imageSource) else {
            throw EncodingError.unsupportedImageType
        }
        
        // Create image destination
        guard let imageDestination = CGImageDestinationCreateWithData(NSMutableData(), imageType, 1, nil) else {
            throw EncodingError.destinationCreationFailed
        }
        
        // Get original image properties
        guard let originalProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            throw EncodingError.propertiesNotFound
        }
        
        // Create updated properties
        var updatedProperties = originalProperties
        
        // Set target size
        updatedProperties[kCGImageDestinationImageMaxPixelSize] = max(targetSize.width, targetSize.height)
        
        // Set quality
        updatedProperties[kCGImageDestinationLossyCompressionQuality] = quality
        
        // Add image to destination
        CGImageDestinationAddImageFromSource(imageDestination, imageSource, 0, updatedProperties as CFDictionary)
        
        // Finalize destination
        guard CGImageDestinationFinalize(imageDestination) else {
            throw EncodingError.finalizationFailed
        }
        
        // Get final data
        guard let finalData = CGImageDestinationCreateData(imageDestination) as Data? else {
            throw EncodingError.dataCreationFailed
        }
        
        logger.debug("Image compressed successfully to size: \(targetSize.width)x\(targetSize.height)")
        return finalData
    }
    
    // MARK: - Image Resizing
    
    func resizeImage(
        _ imageData: Data,
        to size: CGSize,
        maintainAspectRatio: Bool = true
    ) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            encodingQueue.async { [weak self] in
                do {
                    let result = try self?.resizeImageInternal(
                        imageData,
                        to: size,
                        maintainAspectRatio: maintainAspectRatio
                    )
                    continuation.resume(returning: result ?? imageData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func resizeImageInternal(
        _ imageData: Data,
        to size: CGSize,
        maintainAspectRatio: Bool
    ) throws -> Data {
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            throw EncodingError.invalidImageData
        }
        
        guard let imageType = CGImageSourceGetType(imageSource) else {
            throw EncodingError.unsupportedImageType
        }
        
        // Create image destination
        guard let imageDestination = CGImageDestinationCreateWithData(NSMutableData(), imageType, 1, nil) else {
            throw EncodingError.destinationCreationFailed
        }
        
        // Get original image properties
        guard let originalProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            throw EncodingError.propertiesNotFound
        }
        
        // Create updated properties
        var updatedProperties = originalProperties
        
        // Set target size
        if maintainAspectRatio {
            updatedProperties[kCGImageDestinationImageMaxPixelSize] = max(size.width, size.height)
        } else {
            updatedProperties[kCGImageDestinationImageMaxPixelSize] = max(size.width, size.height)
        }
        
        // Add image to destination
        CGImageDestinationAddImageFromSource(imageDestination, imageSource, 0, updatedProperties as CFDictionary)
        
        // Finalize destination
        guard CGImageDestinationFinalize(imageDestination) else {
            throw EncodingError.finalizationFailed
        }
        
        // Get final data
        guard let finalData = CGImageDestinationCreateData(imageDestination) as Data? else {
            throw EncodingError.dataCreationFailed
        }
        
        logger.debug("Image resized successfully to size: \(size.width)x\(size.height)")
        return finalData
    }
    
    // MARK: - Encoding Statistics
    
    func getEncodingStatistics() -> EncodingStatistics {
        return EncodingStatistics(
            isEncoding: _isEncoding,
            progress: _encodingProgress,
            currentTask: _currentEncodingTask,
            totalEncoded: 0, // TODO: Track total encoded
            averageCompressionRatio: 0.0, // TODO: Track average compression
            averageProcessingTime: 0.0 // TODO: Track average processing time
        )
    }
    
    // MARK: - Queue Management
    
    func cancelCurrentEncoding() {
        guard _isEncoding else { return }
        
        _isEncoding = false
        _encodingProgress = 0.0
        _currentEncodingTask = nil
        
        logger.info("Current encoding cancelled")
    }
    
    func pauseEncoding() {
        guard _isEncoding else { return }
        
        // TODO: Implement encoding pause
        logger.info("Encoding paused")
    }
    
    func resumeEncoding() {
        guard !_isEncoding else { return }
        
        // TODO: Implement encoding resume
        logger.info("Encoding resumed")
    }
}

// MARK: - Supporting Types

struct ImageEncodingTask {
    let id: UUID
    let imageData: Data
    let originalSize: CGSize
    let targetQuality: Float
    let targetSize: CGSize?
}

struct EncodingTask {
    let id: UUID
    let totalImages: Int
    var completedImages: Int
    let startTime: Date
}

struct EncodingResult {
    let success: Bool
    let originalSize: Int
    let encodedSize: Int
    let compressionRatio: Float
    let processingTime: TimeInterval
    let error: Error?
}

struct EncodingStatistics {
    let isEncoding: Bool
    let progress: Float
    let currentTask: EncodingTask?
    let totalEncoded: Int
    let averageCompressionRatio: Float
    let averageProcessingTime: TimeInterval
}

// MARK: - EncodingError

enum EncodingError: Error, LocalizedError {
    case invalidImageData
    case unsupportedImageType
    case destinationCreationFailed
    case propertiesNotFound
    case finalizationFailed
    case dataCreationFailed
    case encodingFailed(Error)
    case compressionFailed
    case resizingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Invalid image data"
        case .unsupportedImageType:
            return "Unsupported image type"
        case .destinationCreationFailed:
            return "Failed to create image destination"
        case .propertiesNotFound:
            return "Image properties not found"
        case .finalizationFailed:
            return "Failed to finalize image destination"
        case .dataCreationFailed:
            return "Failed to create final image data"
        case .encodingFailed(let error):
            return "Encoding failed: \(error.localizedDescription)"
        case .compressionFailed:
            return "Image compression failed"
        case .resizingFailed:
            return "Image resizing failed"
        }
    }
}

// MARK: - EncodingService Extensions

extension EncodingService {
    
    /// Gets the compression ratio as a percentage string
    func getCompressionRatioString(_ result: EncodingResult) -> String {
        let percentage = Int(result.compressionRatio * 100)
        return "\(percentage)%"
    }
    
    /// Gets the size reduction as a string
    func getSizeReductionString(_ result: EncodingResult) -> String {
        let reduction = result.originalSize - result.encodedSize
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(reduction))
    }
    
    /// Checks if encoding is efficient
    func isEncodingEfficient(_ result: EncodingResult) -> Bool {
        return result.compressionRatio < 0.8 // Less than 80% of original size
    }
    
    /// Gets the encoding efficiency description
    func getEncodingEfficiencyDescription(_ result: EncodingResult) -> String {
        if isEncodingEfficient(result) {
            return "Efficient compression"
        } else {
            return "Inefficient compression"
        }
    }
}
