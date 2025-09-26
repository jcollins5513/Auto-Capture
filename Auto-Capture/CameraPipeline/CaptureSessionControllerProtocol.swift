// CaptureSessionControllerProtocol.swift - API Contract
// Manages AVCaptureSession configuration and camera pipeline

import AVFoundation
import Foundation

protocol CaptureSessionControllerProtocol {
    // Configuration
    func configureSession() async throws
    func startSession() async throws
    func stopSession() async throws
    
    // Capture settings
    func setExposureLock(_ locked: Bool) async throws
    func setWhiteBalanceLock(_ locked: Bool) async throws
    func setAspectRatio(_ ratio: AspectRatio) async throws
    
    // Session state
    var isSessionRunning: Bool { get }
    var isConfigurationLocked: Bool { get }
    
    // Error handling
    var onError: ((CameraError) -> Void)? { get set }
}

enum AspectRatio {
    case fourByThree
    case sixteenByNine
}

enum CameraError: Error {
    case configurationFailed
    case sessionStartFailed
    case permissionDenied
    case deviceNotAvailable
    case thermalThrottling
}

// Implementation requirements:
// - Must configure AVCaptureSession with photo output
// - Must support 4:3 aspect ratio for car photography
// - Must handle exposure/WB locking before capture
// - Must provide thermal monitoring and graceful degradation
// - Must maintain 30fps preview performance
// - Must handle camera permission requests
