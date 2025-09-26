import Foundation

/// Metadata embedded in captured photos
struct EXIFData: Codable, Equatable {
    let stockNumber: String
    let viewpoint: String
    let sessionId: String
    let appVersion: String
    let captureTimestamp: Date
    let deviceModel: String
    let iosVersion: String
    let cameraSettings: CameraSettings?
    
    init(
        stockNumber: String,
        viewpoint: String,
        sessionId: String,
        appVersion: String,
        captureTimestamp: Date,
        deviceModel: String,
        iosVersion: String,
        cameraSettings: CameraSettings? = nil
    ) {
        self.stockNumber = stockNumber
        self.viewpoint = viewpoint
        self.sessionId = sessionId
        self.appVersion = appVersion
        self.captureTimestamp = captureTimestamp
        self.deviceModel = deviceModel
        self.iosVersion = iosVersion
        self.cameraSettings = cameraSettings
    }
    
    /// Validates the EXIF data
    var isValid: Bool {
        return !stockNumber.isEmpty &&
               !viewpoint.isEmpty &&
               !sessionId.isEmpty &&
               !appVersion.isEmpty &&
               !deviceModel.isEmpty &&
               !iosVersion.isEmpty &&
               isValidAppVersion &&
               isValidSessionId
    }
    
    /// Validates app version format (semantic versioning)
    private var isValidAppVersion: Bool {
        let pattern = "^\\d+\\.\\d+\\.\\d+$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: appVersion.utf16.count)
        return regex?.firstMatch(in: appVersion, options: [], range: range) != nil
    }
    
    /// Validates session ID format (UUID)
    private var isValidSessionId: Bool {
        return UUID(uuidString: sessionId) != nil
    }
    
    /// Gets the capture timestamp as a formatted string
    var captureTimestampString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: captureTimestamp)
    }
    
    /// Gets the capture date as a formatted string
    var captureDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: captureTimestamp)
    }
    
    /// Gets the capture time as a formatted string
    var captureTimeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: captureTimestamp)
    }
    
    /// Gets the app version components
    var appVersionComponents: (major: Int, minor: Int, patch: Int)? {
        let components = appVersion.split(separator: ".")
        guard components.count == 3,
              let major = Int(components[0]),
              let minor = Int(components[1]),
              let patch = Int(components[2]) else {
            return nil
        }
        return (major: major, minor: minor, patch: patch)
    }
    
    /// Checks if this is a newer app version than the given version
    func isNewerThan(_ version: String) -> Bool {
        guard let current = appVersionComponents,
              let other = EXIFData.appVersionComponents(version) else {
            return false
        }
        
        if current.major != other.major {
            return current.major > other.major
        } else if current.minor != other.minor {
            return current.minor > other.minor
        } else {
            return current.patch > other.patch
        }
    }
    
    /// Gets app version components from version string
    static func appVersionComponents(_ version: String) -> (major: Int, minor: Int, patch: Int)? {
        let components = version.split(separator: ".")
        guard components.count == 3,
              let major = Int(components[0]),
              let minor = Int(components[1]),
              let patch = Int(components[2]) else {
            return nil
        }
        return (major: major, minor: minor, patch: patch)
    }
    
    /// Gets the device model description
    var deviceModelDescription: String {
        switch deviceModel {
        case "iPhone15,2":
            return "iPhone 14 Pro"
        case "iPhone15,3":
            return "iPhone 14 Pro Max"
        case "iPhone14,7":
            return "iPhone 14"
        case "iPhone14,8":
            return "iPhone 14 Plus"
        case "iPhone13,1":
            return "iPhone 12 mini"
        case "iPhone13,2":
            return "iPhone 12"
        case "iPhone13,3":
            return "iPhone 12 Pro"
        case "iPhone13,4":
            return "iPhone 12 Pro Max"
        case "iPhone12,1":
            return "iPhone 11"
        case "iPhone12,3":
            return "iPhone 11 Pro"
        case "iPhone12,5":
            return "iPhone 11 Pro Max"
        default:
            return deviceModel
        }
    }
    
    /// Gets the iOS version description
    var iosVersionDescription: String {
        return "iOS \(iosVersion)"
    }
    
    /// Gets the viewpoint description
    var viewpointDescription: String {
        return Viewpoint(rawValue: viewpoint)?.description ?? viewpoint
    }
    
    /// Gets the capture method description
    var captureMethodDescription: String {
        if let settings = cameraSettings {
            return "Auto-capture with \(settings.exposureMode.rawValue) exposure"
        } else {
            return "Manual capture"
        }
    }
    
    /// Gets the camera settings description
    var cameraSettingsDescription: String {
        guard let settings = cameraSettings else {
            return "No camera settings recorded"
        }
        
        var description = "ISO \(Int(settings.iso))"
        description += ", \(String(format: "%.1f", settings.aperture))f"
        description += ", \(String(format: "%.0f", settings.focalLength))mm"
        
        if settings.flashMode != .off {
            description += ", Flash \(settings.flashMode.rawValue)"
        }
        
        return description
    }
    
    /// Gets the capture quality description
    var captureQualityDescription: String {
        guard let settings = cameraSettings else {
            return "Unknown quality"
        }
        
        let iso = settings.iso
        let aperture = settings.aperture
        
        if iso <= 100 && aperture <= 2.8 {
            return "Excellent quality"
        } else if iso <= 400 && aperture <= 4.0 {
            return "Good quality"
        } else if iso <= 800 && aperture <= 5.6 {
            return "Standard quality"
        } else {
            return "Basic quality"
        }
    }
    
    /// Gets the capture environment description
    var captureEnvironmentDescription: String {
        guard let settings = cameraSettings else {
            return "Unknown environment"
        }
        
        let iso = settings.iso
        let shutterSpeed = settings.shutterSpeed
        
        if iso <= 100 && shutterSpeed >= 1.0/60.0 {
            return "Bright environment"
        } else if iso <= 400 && shutterSpeed >= 1.0/30.0 {
            return "Normal environment"
        } else if iso <= 800 && shutterSpeed >= 1.0/15.0 {
            return "Low light environment"
        } else {
            return "Very low light environment"
        }
    }
    
    /// Gets the capture stability description
    var captureStabilityDescription: String {
        guard let settings = cameraSettings else {
            return "Unknown stability"
        }
        
        let shutterSpeed = settings.shutterSpeed
        
        if shutterSpeed >= 1.0/60.0 {
            return "Very stable"
        } else if shutterSpeed >= 1.0/30.0 {
            return "Stable"
        } else if shutterSpeed >= 1.0/15.0 {
            return "Moderate stability"
        } else {
            return "Requires stabilization"
        }
    }
    
    /// Gets the capture summary
    var captureSummary: String {
        var summary = "Captured \(viewpointDescription) at \(captureTimestampString)"
        summary += " using \(deviceModelDescription) with \(iosVersionDescription)"
        summary += " via Auto-Capture \(appVersion)"
        
        if let settings = cameraSettings {
            summary += " (ISO \(Int(settings.iso)), \(String(format: "%.1f", settings.aperture))f)"
        }
        
        return summary
    }
    
    /// Gets the capture metadata as a dictionary
    var metadataDictionary: [String: Any] {
        var metadata: [String: Any] = [
            "stockNumber": stockNumber,
            "viewpoint": viewpoint,
            "sessionId": sessionId,
            "appVersion": appVersion,
            "captureTimestamp": captureTimestampString,
            "deviceModel": deviceModel,
            "iosVersion": iosVersion
        ]
        
        if let settings = cameraSettings {
            metadata["cameraSettings"] = settings.metadataDictionary
        }
        
        return metadata
    }
    
    /// Creates EXIF data from a photo capture
    static func fromPhotoCapture(_ photo: PhotoCapture) -> EXIFData {
        return EXIFData(
            stockNumber: photo.exifData.stockNumber,
            viewpoint: photo.viewpoint.rawValue,
            sessionId: photo.sessionId.uuidString,
            appVersion: photo.exifData.appVersion,
            captureTimestamp: photo.capturedAt,
            deviceModel: photo.exifData.deviceModel,
            iosVersion: photo.exifData.iosVersion,
            cameraSettings: photo.exifData.cameraSettings
        )
    }
}

// CameraSettings, FlashMode, WhiteBalanceMode, and ExposureMode are defined in AdditionalTypes.swift
