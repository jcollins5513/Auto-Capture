// AdditionalTypes.swift - Additional model types and enums

import Foundation

// MARK: - Session Status
// SessionStatus is defined in CaptureSession.swift

// MARK: - Camera Settings

struct CameraSettings: Codable, Equatable {
    let iso: Float
    let shutterSpeed: Float
    let aperture: Float
    let focalLength: Float
    let flashMode: FlashMode
    let whiteBalance: WhiteBalanceMode
    let exposureMode: ExposureMode
    
    init(
        iso: Float,
        shutterSpeed: Float,
        aperture: Float,
        focalLength: Float,
        flashMode: FlashMode = .off,
        whiteBalance: WhiteBalanceMode = .auto,
        exposureMode: ExposureMode = .auto
    ) {
        self.iso = iso
        self.shutterSpeed = shutterSpeed
        self.aperture = aperture
        self.focalLength = focalLength
        self.flashMode = flashMode
        self.whiteBalance = whiteBalance
        self.exposureMode = exposureMode
    }
    
    var isoString: String {
        return String(format: "ISO %.0f", iso)
    }
    
    var shutterSpeedString: String {
        if shutterSpeed >= 1.0 {
            return String(format: "%.1fs", shutterSpeed)
        } else {
            return String(format: "1/%.0f", 1.0 / shutterSpeed)
        }
    }
    
    var apertureString: String {
        return String(format: "f/%.1f", aperture)
    }
    
    var focalLengthString: String {
        return String(format: "%.0fmm", focalLength)
    }
    
    /// Gets the camera settings as a dictionary
    var metadataDictionary: [String: Any] {
        return [
            "iso": iso,
            "shutterSpeed": shutterSpeed,
            "aperture": aperture,
            "focalLength": focalLength,
            "flashMode": flashMode.rawValue,
            "whiteBalance": whiteBalance.rawValue,
            "exposureMode": exposureMode.rawValue
        ]
    }
}

enum FlashMode: String, Codable, CaseIterable {
    case off = "off"
    case auto = "auto"
    case on = "on"
    
    var description: String {
        switch self {
        case .off:
            return "Off"
        case .auto:
            return "Auto"
        case .on:
            return "On"
        }
    }
}

enum WhiteBalanceMode: String, Codable, CaseIterable {
    case auto = "auto"
    case locked = "locked"
    case manual = "manual"
    
    var description: String {
        switch self {
        case .auto:
            return "Auto"
        case .locked:
            return "Locked"
        case .manual:
            return "Manual"
        }
    }
}

enum ExposureMode: String, Codable, CaseIterable {
    case auto = "auto"
    case locked = "locked"
    case manual = "manual"
    
    var description: String {
        switch self {
        case .auto:
            return "Auto"
        case .locked:
            return "Locked"
        case .manual:
            return "Manual"
        }
    }
}
