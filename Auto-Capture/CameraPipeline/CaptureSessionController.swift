import AVFoundation
import Foundation
import OSLog

/// Manages AVCaptureSession configuration and camera pipeline
final class CaptureSessionController: NSObject, CaptureSessionControllerProtocol {
    
    // MARK: - Properties
    
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "capture.session.queue")
    private let logger = Logger(subsystem: "AutoCapture", category: "CameraPipeline")
    
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var photoOutput: AVCapturePhotoOutput?
    
    private var _isSessionRunning = false
    private var _isConfigurationLocked = false
    
    var isSessionRunning: Bool {
        return _isSessionRunning
    }
    
    var isConfigurationLocked: Bool {
        return _isConfigurationLocked
    }
    
    var onError: ((CameraError) -> Void)?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupCaptureSession()
    }
    
    deinit {
        Task {
            try? await stopSession()
        }
    }
    
    // MARK: - Configuration
    
    func configureSession() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                do {
                    try self?.configureCaptureSession()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func configureCaptureSession() throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        // Set session preset for 4:3 aspect ratio
        if captureSession.canSetSessionPreset(.photo) {
            captureSession.sessionPreset = .photo
        } else {
            throw CameraError.configurationFailed
        }
        
        // Add video input
        try addVideoInput()
        
        // Add photo output
        try addPhotoOutput()
        
        logger.info("Capture session configured successfully")
    }
    
    private func addVideoInput() throws {
        // Get the back wide camera
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.deviceNotAvailable
        }
        
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if captureSession.canAddInput(videoDeviceInput) {
                captureSession.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                logger.info("Video input added successfully")
            } else {
                throw CameraError.configurationFailed
            }
        } catch {
            logger.error("Failed to create video device input: \(error.localizedDescription)")
            throw CameraError.configurationFailed
        }
    }
    
    private func addPhotoOutput() throws {
        let photoOutput = AVCapturePhotoOutput()
        
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            self.photoOutput = photoOutput
            
            // Configure photo output settings
            if #available(iOS 16.0, *) {
                photoOutput.maxPhotoDimensions = CMVideoDimensions(width: 4032, height: 3024) // 4:3 ratio
            } else {
                photoOutput.isHighResolutionCaptureEnabled = true
            }
            photoOutput.maxPhotoQualityPrioritization = .quality
            
            logger.info("Photo output added successfully")
        } else {
            throw CameraError.configurationFailed
        }
    }
    
    // MARK: - Session Control
    
    func startSession() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: CameraError.configurationFailed)
                    return
                }
                
                if !self._isSessionRunning {
                    self.captureSession.startRunning()
                    self._isSessionRunning = self.captureSession.isRunning
                    
                    if self._isSessionRunning {
                        self.logger.info("Capture session started successfully")
                        continuation.resume()
                    } else {
                        self.logger.error("Failed to start capture session")
                        continuation.resume(throwing: CameraError.sessionStartFailed)
                    }
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    func stopSession() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: CameraError.configurationFailed)
                    return
                }
                
                if self._isSessionRunning {
                    self.captureSession.stopRunning()
                    self._isSessionRunning = false
                    self.logger.info("Capture session stopped")
                }
                continuation.resume()
            }
        }
    }
    
    // MARK: - Capture Settings
    
    func setExposureLock(_ locked: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self = self,
                      let device = self.videoDeviceInput?.device else {
                    continuation.resume(throwing: CameraError.deviceNotAvailable)
                    return
                }
                
                do {
                    try device.lockForConfiguration()
                    defer { device.unlockForConfiguration() }
                    
                    if locked {
                        device.exposureMode = .locked
                        self._isConfigurationLocked = true
                        self.logger.info("Exposure locked")
                    } else {
                        device.exposureMode = .autoExpose
                        self._isConfigurationLocked = false
                        self.logger.info("Exposure unlocked")
                    }
                    
                    continuation.resume()
                } catch {
                    self.logger.error("Failed to set exposure lock: \(error.localizedDescription)")
                    continuation.resume(throwing: CameraError.configurationFailed)
                }
            }
        }
    }
    
    func setWhiteBalanceLock(_ locked: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self = self,
                      let device = self.videoDeviceInput?.device else {
                    continuation.resume(throwing: CameraError.deviceNotAvailable)
                    return
                }
                
                do {
                    try device.lockForConfiguration()
                    defer { device.unlockForConfiguration() }
                    
                    if locked {
                        device.whiteBalanceMode = .locked
                        self.logger.info("White balance locked")
                    } else {
                        device.whiteBalanceMode = .autoWhiteBalance
                        self.logger.info("White balance unlocked")
                    }
                    
                    continuation.resume()
                } catch {
                    self.logger.error("Failed to set white balance lock: \(error.localizedDescription)")
                    continuation.resume(throwing: CameraError.configurationFailed)
                }
            }
        }
    }
    
    func setAspectRatio(_ ratio: AspectRatio) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: CameraError.configurationFailed)
                    return
                }
                
                self.captureSession.beginConfiguration()
                defer { self.captureSession.commitConfiguration() }
                
                switch ratio {
                case .fourByThree:
                    if self.captureSession.canSetSessionPreset(.photo) {
                        self.captureSession.sessionPreset = .photo
                        self.logger.info("Aspect ratio set to 4:3")
                    } else {
                        continuation.resume(throwing: CameraError.configurationFailed)
                        return
                    }
                case .sixteenByNine:
                    if self.captureSession.canSetSessionPreset(.high) {
                        self.captureSession.sessionPreset = .high
                        self.logger.info("Aspect ratio set to 16:9")
                    } else {
                        continuation.resume(throwing: CameraError.configurationFailed)
                        return
                    }
                }
                
                continuation.resume()
            }
        }
    }
    
    // MARK: - Device Configuration
    
    private func setupCaptureSession() {
        // Configure session for optimal performance
        captureSession.automaticallyConfiguresApplicationAudioSession = false
        
        // Set up session interruption handling
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionWasInterrupted),
            name: AVCaptureSession.wasInterruptedNotification,
            object: captureSession
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterruptionEnded),
            name: .AVCaptureSessionInterruptionEnded,
            object: captureSession
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionRuntimeError),
            name: .AVCaptureSessionRuntimeError,
            object: captureSession
        )
    }
    
    // MARK: - Session Interruption Handling
    
    @objc private func sessionWasInterrupted(notification: NSNotification) {
        guard let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
              let reasonIntegerValue = userInfoValue.integerValue,
              let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) else {
            return
        }
        
        logger.warning("Capture session was interrupted: \(reason.rawValue)")
        
        switch reason {
        case .videoDeviceNotAvailableInBackground:
            // Handle background interruption
            break
        case .audioDeviceInUseByAnotherClient:
            // Handle audio device interruption
            break
        case .videoDeviceInUseByAnotherClient:
            // Handle video device interruption
            break
        case .videoDeviceNotAvailableWithMultipleForegroundApps:
            // Handle multiple foreground apps
            break
        case .videoDeviceNotAvailableDueToSystemPressure:
            // Handle system pressure
            onError?(.thermalThrottling)
            break
        case .sensitiveContentMitigationActivated:
            // Handle sensitive content mitigation
            break
        @unknown default:
            logger.error("Unknown interruption reason: \(reasonIntegerValue)")
        }
    }
    
    @objc private func sessionInterruptionEnded(notification: NSNotification) {
        logger.info("Capture session interruption ended")
        
        // Restart session if needed
        if !_isSessionRunning {
            Task {
                try? await startSession()
            }
        }
    }
    
    @objc private func sessionRuntimeError(notification: NSNotification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else {
            return
        }
        
        logger.error("Capture session runtime error: \(error.localizedDescription)")
        onError?(.sessionStartFailed)
    }
    
    // MARK: - Thermal Monitoring
    
    func checkThermalState() -> Bool {
        guard let device = videoDeviceInput?.device else {
            return false
        }
        
        // Note: thermalState is not available on AVCaptureDevice in iOS 26
        // This is a simplified implementation - in a real app you'd use ProcessInfo
        let thermalState = ProcessInfo.processInfo.thermalState
        logger.info("Device thermal state: \(thermalState.rawValue)")
        
        switch thermalState {
        case .nominal, .fair:
            return true
        case .serious, .critical:
            onError?(.thermalThrottling)
            return false
        @unknown default:
            return true
        }
    }
    
    // MARK: - Camera Device Access
    
    func requestCameraPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                continuation.resume(returning: true)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            case .denied, .restricted:
                continuation.resume(returning: false)
            @unknown default:
                continuation.resume(returning: false)
            }
        }
    }
    
    // MARK: - Public Interface
    
    func getPhotoOutput() -> AVCapturePhotoOutput? {
        return photoOutput
    }
    
    func getVideoPreviewLayer() -> AVCaptureVideoPreviewLayer {
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        return previewLayer
    }
    
    func getCurrentDevice() -> AVCaptureDevice? {
        return videoDeviceInput?.device
    }
}

// MARK: - CameraError Extension

extension CameraError {
    var localizedDescription: String {
        switch self {
        case .configurationFailed:
            return "Failed to configure camera session"
        case .sessionStartFailed:
            return "Failed to start camera session"
        case .permissionDenied:
            return "Camera permission denied"
        case .deviceNotAvailable:
            return "Camera device not available"
        case .thermalThrottling:
            return "Camera throttled due to thermal conditions"
        }
    }
}
