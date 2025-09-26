import AVFoundation
import Foundation
import OSLog
import UIKit

/// Manages photo capture operations and JPEG encoding
final class PhotoCaptureManager: NSObject {
    
    // MARK: - Properties
    
    private let captureSessionController: CaptureSessionControllerProtocol
    private let sessionStore: SessionStoreProtocol
    private let logger = Logger(subsystem: "AutoCapture", category: "PhotoCapture")
    
    private var photoOutput: AVCapturePhotoOutput?
    private var captureCompletion: ((Result<PhotoCapture, PhotoCaptureError>) -> Void)?
    
    // MARK: - Initialization
    
    init(
        captureSessionController: CaptureSessionControllerProtocol,
        sessionStore: SessionStoreProtocol
    ) {
        self.captureSessionController = captureSessionController
        self.sessionStore = sessionStore
        super.init()
        setupPhotoOutput()
    }
    
    // MARK: - Setup
    
    private func setupPhotoOutput() {
        // Get photo output from capture session controller
        if let controller = captureSessionController as? CaptureSessionController {
            photoOutput = controller.getPhotoOutput()
        }
    }
    
    // MARK: - Photo Capture
    
    func capturePhoto(
        for session: CaptureSession,
        viewpoint: Viewpoint,
        order: Int,
        confidence: Float,
        settings: SessionSettings
    ) async throws -> PhotoCapture {
        guard let photoOutput = photoOutput else {
            throw PhotoCaptureError.photoOutputNotAvailable
        }
        
        // Create photo capture request
        let photoSettings = createPhotoSettings(settings: settings)
        
        // Create photo capture
        let photoCapture = PhotoCapture(
            sessionId: session.id,
            viewpoint: viewpoint,
            order: order,
            filePath: "", // Will be set after capture
            confidence: confidence,
            exifData: createEXIFData(
                stockNumber: session.stockNumber,
                viewpoint: viewpoint,
                sessionId: session.id,
                settings: settings
            )
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            self.captureCompletion = { result in
                continuation.resume(with: result)
            }
            
            // Capture photo
            photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    
    private func createPhotoSettings(settings: SessionSettings) -> AVCapturePhotoSettings {
        let photoSettings = AVCapturePhotoSettings()
        
        // Configure photo settings
        photoSettings.maxPhotoDimensions = CMVideoDimensions(width: 4032, height: 3024)
        photoSettings.flashMode = .off // Disable flash for consistency
        
        // Set JPEG quality - format is read-only, so we configure other settings
        
        // Configure photo quality
        photoSettings.photoQualityPrioritization = .quality
        
        return photoSettings
    }
    
    private func createEXIFData(
        stockNumber: String,
        viewpoint: Viewpoint,
        sessionId: UUID,
        settings: SessionSettings
    ) -> EXIFData {
        return EXIFData(
            stockNumber: stockNumber,
            viewpoint: viewpoint.rawValue,
            sessionId: sessionId.uuidString,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            captureTimestamp: Date(),
            deviceModel: UIDevice.current.model,
            iosVersion: UIDevice.current.systemVersion,
            cameraSettings: getCurrentCameraSettings()
        )
    }
    
    private func getCurrentCameraSettings() -> CameraSettings? {
        guard let controller = captureSessionController as? CaptureSessionController,
              let device = controller.getCurrentDevice() else {
            return nil
        }
        
        return CameraSettings(
            iso: Float(device.iso),
            shutterSpeed: Float(device.exposureDuration.seconds),
            aperture: device.lensAperture,
            focalLength: device.lensPosition,
            flashMode: .off,
            whiteBalance: .auto,
            exposureMode: .auto
        )
    }
    
    // MARK: - Photo Processing
    
    private func processCapturedPhoto(
        _ photo: AVCapturePhoto,
        photoCapture: PhotoCapture
    ) async throws -> PhotoCapture {
        guard let imageData = photo.fileDataRepresentation() else {
            throw PhotoCaptureError.imageDataNotAvailable
        }
        
        // Generate filename
        let filename = sessionStore.generatePhotoFilename(for: photoCapture)
        
        // Save photo to session directory
        let photoURL = try await sessionStore.savePhoto(photoCapture, imageData: imageData)
        
        // Create updated photo capture with file path
        var updatedPhoto = photoCapture
        updatedPhoto.filePath = photoURL.path
        
        logger.info("Photo captured successfully: \(filename)")
        
        return updatedPhoto
    }
    
    // MARK: - Retake Photo
    
    func retakePhoto(
        originalPhoto: PhotoCapture,
        newConfidence: Float,
        settings: SessionSettings
    ) async throws -> PhotoCapture {
        // Create retake photo
        let retakePhoto = PhotoCapture.createRetake(
            from: originalPhoto,
            newConfidence: newConfidence,
            newFilePath: ""
        )
        
        // Capture new photo
        return try await capturePhoto(
            for: CaptureSession(
                id: originalPhoto.sessionId,
                stockNumber: originalPhoto.exifData.stockNumber,
                settings: settings
            ),
            viewpoint: originalPhoto.viewpoint,
            order: originalPhoto.order,
            confidence: newConfidence,
            settings: settings
        )
    }
    
    // MARK: - Photo Validation
    
    func validatePhoto(_ photo: PhotoCapture) -> Bool {
        return photo.isValid && photo.fileExists
    }
    
    func getPhotoFileSize(_ photo: PhotoCapture) -> Int64? {
        return photo.fileSize
    }
    
    func getPhotoMetadata(_ photo: PhotoCapture) -> [String: Any] {
        return photo.exifData.metadataDictionary
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension PhotoCaptureManager: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            logger.error("Photo capture failed: \(error.localizedDescription)")
            captureCompletion?(.failure(.captureFailed(error)))
            return
        }
        
        // Process the captured photo
        Task {
            do {
                // Create a temporary photo capture for processing
                let tempPhoto = PhotoCapture(
                    sessionId: UUID(), // Will be updated
                    viewpoint: .front, // Will be updated
                    order: 1, // Will be updated
                    filePath: "",
                    confidence: 0.0, // Will be updated
                    exifData: EXIFData(
                        stockNumber: "",
                        viewpoint: "",
                        sessionId: "",
                        appVersion: "",
                        captureTimestamp: Date(),
                        deviceModel: "",
                        iosVersion: ""
                    )
                )
                
                let processedPhoto = try await processCapturedPhoto(photo, photoCapture: tempPhoto)
                captureCompletion?(.success(processedPhoto))
            } catch {
                logger.error("Photo processing failed: \(error.localizedDescription)")
                captureCompletion?(.failure(.processingFailed(error)))
            }
        }
    }
    
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings
    ) {
        logger.info("Photo capture will begin")
    }
    
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        if let error = error {
            logger.error("Photo capture finished with error: \(error.localizedDescription)")
            captureCompletion?(.failure(.captureFailed(error)))
        } else {
            logger.info("Photo capture finished successfully")
        }
    }
}

// MARK: - PhotoCaptureError

enum PhotoCaptureError: Error, LocalizedError {
    case photoOutputNotAvailable
    case imageDataNotAvailable
    case captureFailed(Error)
    case processingFailed(Error)
    case invalidPhoto
    case fileSystemError
    
    var errorDescription: String? {
        switch self {
        case .photoOutputNotAvailable:
            return "Photo output not available"
        case .imageDataNotAvailable:
            return "Image data not available"
        case .captureFailed(let error):
            return "Photo capture failed: \(error.localizedDescription)"
        case .processingFailed(let error):
            return "Photo processing failed: \(error.localizedDescription)"
        case .invalidPhoto:
            return "Invalid photo data"
        case .fileSystemError:
            return "File system error"
        }
    }
}
