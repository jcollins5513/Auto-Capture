import Foundation
import OSLog
import UIKit

/// Centralized error handling and logging
final class ErrorHandler {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "AutoCapture", category: "ErrorHandler")
    private static let shared = ErrorHandler()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Interface
    
    static func handle(_ error: Error, context: String = "", userInfo: [String: Any] = [:]) {
        shared.handleError(error, context: context, userInfo: userInfo)
    }
    
    static func log(_ message: String, level: LogLevel = .info, category: String = "General") {
        shared.logMessage(message, level: level, category: category)
    }
    
    static func reportCrash(_ error: Error, context: String = "") {
        shared.reportCrash(error, context: context)
    }
    
    // MARK: - Private Methods
    
    private func handleError(_ error: Error, context: String, userInfo: [String: Any]) {
        let errorInfo = createErrorInfo(error, context: context, userInfo: userInfo)
        
        // Log the error
        logError(errorInfo)
        
        // Report to crash analytics if needed
        if shouldReportCrash(error) {
            reportCrash(error, context: context)
        }
        
        // Handle specific error types
        handleSpecificError(error, context: context)
    }
    
    private func logMessage(_ message: String, level: LogLevel, category: String) {
        let logger = Logger(subsystem: "AutoCapture", category: category)
        
        switch level {
        case .debug:
            logger.debug("\(message)")
        case .info:
            logger.info("\(message)")
        case .warning:
            logger.warning("\(message)")
        case .error:
            logger.error("\(message)")
        case .critical:
            logger.critical("\(message)")
        }
    }
    
    private func reportCrash(_ error: Error, context: String) {
        // TODO: Implement crash reporting
        // This would typically involve:
        // 1. Collecting crash context
        // 2. Sending to crash reporting service
        // 3. Storing locally for later transmission
        
        logger.critical("Crash reported: \(error.localizedDescription) in context: \(context)")
    }
    
    // MARK: - Error Information
    
    private func createErrorInfo(_ error: Error, context: String, userInfo: [String: Any]) -> ErrorInfo {
        return ErrorInfo(
            error: error,
            context: context,
            timestamp: Date(),
            userInfo: userInfo,
            threadInfo: getThreadInfo(),
            deviceInfo: getDeviceInfo()
        )
    }
    
    private func logError(_ errorInfo: ErrorInfo) {
        let message = """
        Error: \(errorInfo.error.localizedDescription)
        Context: \(errorInfo.context)
        Timestamp: \(errorInfo.timestamp)
        Thread: \(errorInfo.threadInfo.name)
        Device: \(errorInfo.deviceInfo.model)
        """
        
        logger.error("\(message)")
        
        // Log additional details if available
        if !errorInfo.userInfo.isEmpty {
            logger.debug("User Info: \(errorInfo.userInfo)")
        }
    }
    
    // MARK: - Specific Error Handling
    
    private func handleSpecificError(_ error: Error, context: String) {
        switch error {
        case let cameraError as CameraError:
            handleCameraError(cameraError, context: context)
        case let storageError as StorageError:
            handleStorageError(storageError, context: context)
        case let stateMachineError as StateMachineError:
            handleStateMachineError(stateMachineError, context: context)
        case let exifError as EXIFError:
            handleEXIFError(exifError, context: context)
        case let photoCaptureError as PhotoCaptureError:
            handlePhotoCaptureError(photoCaptureError, context: context)
        case let exportError as ExportError:
            handleExportError(exportError, context: context)
        default:
            handleGenericError(error, context: context)
        }
    }
    
    private func handleCameraError(_ error: CameraError, context: String) {
        logger.error("Camera error: \(error.localizedDescription) in context: \(context)")
        
        // Handle specific camera errors
        switch error {
        case .permissionDenied:
            // TODO: Show permission request UI
            break
        case .thermalThrottling:
            // TODO: Show thermal warning UI
            break
        case .deviceNotAvailable:
            // TODO: Show device unavailable UI
            break
        default:
            break
        }
    }
    
    private func handleStorageError(_ error: StorageError, context: String) {
        logger.error("Storage error: \(error.localizedDescription) in context: \(context)")
        
        // Handle specific storage errors
        switch error {
        case .storageFull:
            // TODO: Show storage full UI
            break
        case .dataCorruption:
            // TODO: Show data corruption warning
            break
        default:
            break
        }
    }
    
    private func handleStateMachineError(_ error: StateMachineError, context: String) {
        logger.error("State machine error: \(error.localizedDescription) in context: \(context)")
        
        // Handle specific state machine errors
        switch error {
        case .invalidStateTransition:
            // TODO: Reset state machine
            break
        case .sessionNotActive:
            // TODO: Show session not active UI
            break
        default:
            break
        }
    }
    
    private func handleEXIFError(_ error: EXIFError, context: String) {
        logger.error("EXIF error: \(error.localizedDescription) in context: \(context)")
    }
    
    private func handlePhotoCaptureError(_ error: PhotoCaptureError, context: String) {
        logger.error("Photo capture error: \(error.localizedDescription) in context: \(context)")
    }
    
    private func handleExportError(_ error: ExportError, context: String) {
        logger.error("Export error: \(error.localizedDescription) in context: \(context)")
    }
    
    private func handleGenericError(_ error: Error, context: String) {
        logger.error("Generic error: \(error.localizedDescription) in context: \(context)")
    }
    
    // MARK: - Helper Methods
    
    private func shouldReportCrash(_ error: Error) -> Bool {
        // Determine if error should be reported as a crash
        switch error {
        case is CameraError, is StorageError, is StateMachineError:
            return true
        default:
            return false
        }
    }
    
    private func getThreadInfo() -> ThreadInfo {
        return ThreadInfo(
            name: Thread.current.name ?? "Unknown",
            isMainThread: Thread.isMainThread,
            priority: Thread.current.threadPriority
        )
    }
    
    private func getDeviceInfo() -> DeviceInfo {
        return DeviceInfo(
            model: UIDevice.current.model,
            systemName: UIDevice.current.systemName,
            systemVersion: UIDevice.current.systemVersion,
            identifierForVendor: UIDevice.current.identifierForVendor?.uuidString ?? "Unknown"
        )
    }
}

// MARK: - Supporting Types

enum LogLevel {
    case debug
    case info
    case warning
    case error
    case critical
}

struct ErrorInfo {
    let error: Error
    let context: String
    let timestamp: Date
    let userInfo: [String: Any]
    let threadInfo: ThreadInfo
    let deviceInfo: DeviceInfo
}

struct ThreadInfo {
    let name: String
    let isMainThread: Bool
    let priority: Double
}

struct DeviceInfo {
    let model: String
    let systemName: String
    let systemVersion: String
    let identifierForVendor: String
}

// MARK: - ErrorHandler Extensions

extension ErrorHandler {
    
    /// Handles errors with automatic context detection
    static func handle(_ error: Error, file: String = #file, function: String = #function, line: Int = #line) {
        let context = "\(file):\(function):\(line)"
        handle(error, context: context)
    }
    
    /// Logs a message with automatic context detection
    static func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        let context = "\(file):\(function):\(line)"
        log("\(context): \(message)", level: level)
    }
    
    /// Creates a user-friendly error message
    static func userFriendlyMessage(for error: Error) -> String {
        switch error {
        case let cameraError as CameraError:
            return cameraError.userFriendlyMessage
        case let storageError as StorageError:
            return storageError.userFriendlyMessage
        case let stateMachineError as StateMachineError:
            return stateMachineError.userFriendlyMessage
        case let exifError as EXIFError:
            return exifError.userFriendlyMessage
        case let photoCaptureError as PhotoCaptureError:
            return photoCaptureError.userFriendlyMessage
        case let exportError as ExportError:
            return exportError.userFriendlyMessage
        default:
            return "An unexpected error occurred. Please try again."
        }
    }
}

// MARK: - Error Extensions

extension CameraError {
    var userFriendlyMessage: String {
        switch self {
        case .configurationFailed:
            return "Camera configuration failed. Please restart the app."
        case .sessionStartFailed:
            return "Failed to start camera. Please check permissions."
        case .permissionDenied:
            return "Camera permission denied. Please enable camera access in Settings."
        case .deviceNotAvailable:
            return "Camera not available. Please check your device."
        case .thermalThrottling:
            return "Device is overheating. Please wait for it to cool down."
        }
    }
}

extension StorageError {
    var userFriendlyMessage: String {
        switch self {
        case .sessionNotFound:
            return "Session not found. Please try again."
        case .photoNotFound:
            return "Photo not found. Please try again."
        case .storageFull:
            return "Storage is full. Please free up space and try again."
        case .fileSystemError:
            return "File system error. Please try again."
        case .permissionDenied:
            return "Permission denied. Please check app permissions."
        case .invalidPath:
            return "Invalid file path. Please try again."
        case .dataCorruption:
            return "Data corruption detected. Please try again."
        }
    }
}

extension StateMachineError {
    var userFriendlyMessage: String {
        switch self {
        case .invalidStateTransition:
            return "Invalid operation. Please try again."
        case .sessionNotActive:
            return "Session not active. Please start a new session."
        case .viewpointAlreadyCaptured:
            return "Viewpoint already captured. Please try a different viewpoint."
        case .invalidViewpoint:
            return "Invalid viewpoint. Please try again."
        case .classificationTimeout:
            return "Classification timeout. Please try again."
        case .captureFailed:
            return "Capture failed. Please try again."
        }
    }
}

extension EXIFError {
    var userFriendlyMessage: String {
        switch self {
        case .invalidImageData:
            return "Invalid image data. Please try again."
        case .destinationCreationFailed:
            return "Failed to process image. Please try again."
        case .propertiesNotFound:
            return "Image properties not found. Please try again."
        case .finalizationFailed:
            return "Failed to finalize image. Please try again."
        case .dataCreationFailed:
            return "Failed to create image data. Please try again."
        case .unsupportedImageType:
            return "Unsupported image type. Please try again."
        }
    }
}

extension PhotoCaptureError {
    var userFriendlyMessage: String {
        switch self {
        case .photoOutputNotAvailable:
            return "Camera not ready. Please try again."
        case .imageDataNotAvailable:
            return "Image data not available. Please try again."
        case .captureFailed:
            return "Photo capture failed. Please try again."
        case .processingFailed:
            return "Photo processing failed. Please try again."
        case .invalidPhoto:
            return "Invalid photo. Please try again."
        case .fileSystemError:
            return "File system error. Please try again."
        }
    }
}

extension ExportError {
    var userFriendlyMessage: String {
        switch self {
        case .notImplemented:
            return "Export method not implemented. Please try again."
        case .zipCreationFailed:
            return "Failed to create export file. Please try again."
        case .fileSystemError:
            return "File system error. Please try again."
        case .networkError:
            return "Network error. Please check your connection."
        case .authenticationFailed:
            return "Authentication failed. Please check your credentials."
        case .invalidSession:
            return "Invalid session. Please try again."
        case .storageFull:
            return "Storage full. Please free up space and try again."
        }
    }
}
