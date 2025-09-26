import Foundation

/// User-configurable parameters for capture sessions
struct SessionSettings: Codable, Equatable {
    let stabilityFrames: Int
    let confidenceThreshold: Float
    let shutterDelay: TimeInterval
    let lockExposure: Bool
    let jpegQuality: Float
    let guideOpacity: Float
    let voicePrompts: Bool
    let exportTarget: ExportTarget
    let thermalThreshold: Float
    
    init(
        stabilityFrames: Int = 5,
        confidenceThreshold: Float = 0.85,
        shutterDelay: TimeInterval = 0.5,
        lockExposure: Bool = true,
        jpegQuality: Float = 0.9,
        guideOpacity: Float = 0.7,
        voicePrompts: Bool = true,
        exportTarget: ExportTarget = .shareSheet,
        thermalThreshold: Float = 0.8
    ) {
        self.stabilityFrames = stabilityFrames
        self.confidenceThreshold = confidenceThreshold
        self.shutterDelay = shutterDelay
        self.lockExposure = lockExposure
        self.jpegQuality = jpegQuality
        self.guideOpacity = guideOpacity
        self.voicePrompts = voicePrompts
        self.exportTarget = exportTarget
        self.thermalThreshold = thermalThreshold
    }
    
    /// Validates the settings values
    var isValid: Bool {
        return stabilityFrames >= 1 && stabilityFrames <= 20 &&
               confidenceThreshold >= 0.5 && confidenceThreshold <= 1.0 &&
               shutterDelay >= 0.0 && shutterDelay <= 5.0 &&
               jpegQuality >= 0.1 && jpegQuality <= 1.0 &&
               guideOpacity >= 0.0 && guideOpacity <= 1.0 &&
               thermalThreshold >= 0.0 && thermalThreshold <= 1.0
    }
    
    /// Creates a copy with updated values
    func updating(
        stabilityFrames: Int? = nil,
        confidenceThreshold: Float? = nil,
        shutterDelay: TimeInterval? = nil,
        lockExposure: Bool? = nil,
        jpegQuality: Float? = nil,
        guideOpacity: Float? = nil,
        voicePrompts: Bool? = nil,
        exportTarget: ExportTarget? = nil,
        thermalThreshold: Float? = nil
    ) -> SessionSettings {
        return SessionSettings(
            stabilityFrames: stabilityFrames ?? self.stabilityFrames,
            confidenceThreshold: confidenceThreshold ?? self.confidenceThreshold,
            shutterDelay: shutterDelay ?? self.shutterDelay,
            lockExposure: lockExposure ?? self.lockExposure,
            jpegQuality: jpegQuality ?? self.jpegQuality,
            guideOpacity: guideOpacity ?? self.guideOpacity,
            voicePrompts: voicePrompts ?? self.voicePrompts,
            exportTarget: exportTarget ?? self.exportTarget,
            thermalThreshold: thermalThreshold ?? self.thermalThreshold
        )
    }
    
    /// Gets the stability frames as a string
    var stabilityFramesString: String {
        return "\(stabilityFrames) frame\(stabilityFrames == 1 ? "" : "s")"
    }
    
    /// Gets the confidence threshold as a percentage string
    var confidenceThresholdString: String {
        return String(format: "%.0f%%", confidenceThreshold * 100)
    }
    
    /// Gets the shutter delay as a string
    var shutterDelayString: String {
        if shutterDelay < 1.0 {
            return String(format: "%.0f ms", shutterDelay * 1000)
        } else {
            return String(format: "%.1f s", shutterDelay)
        }
    }
    
    /// Gets the JPEG quality as a percentage string
    var jpegQualityString: String {
        return String(format: "%.0f%%", jpegQuality * 100)
    }
    
    /// Gets the guide opacity as a percentage string
    var guideOpacityString: String {
        return String(format: "%.0f%%", guideOpacity * 100)
    }
    
    /// Gets the thermal threshold as a percentage string
    var thermalThresholdString: String {
        return String(format: "%.0f%%", thermalThreshold * 100)
    }
    
    /// Gets the export target description
    var exportTargetDescription: String {
        return exportTarget.description
    }
    
    /// Checks if exposure locking is enabled
    var isExposureLockEnabled: Bool {
        return lockExposure
    }
    
    /// Checks if voice prompts are enabled
    var areVoicePromptsEnabled: Bool {
        return voicePrompts
    }
    
    /// Gets the thermal threshold as a temperature value
    var thermalThresholdTemperature: Float {
        // Convert normalized threshold to temperature (0.0 = 0°C, 1.0 = 100°C)
        return thermalThreshold * 100.0
    }
    
    /// Gets the thermal threshold description
    var thermalThresholdDescription: String {
        let temperature = thermalThresholdTemperature
        return String(format: "%.0f°C", temperature)
    }
    
    /// Gets the shutter delay in milliseconds
    var shutterDelayMilliseconds: Int {
        return Int(shutterDelay * 1000)
    }
    
    /// Gets the stability frames description
    var stabilityFramesDescription: String {
        if stabilityFrames == 1 {
            return "Immediate capture"
        } else if stabilityFrames <= 3 {
            return "Quick stability check"
        } else if stabilityFrames <= 7 {
            return "Standard stability check"
        } else {
            return "Conservative stability check"
        }
    }
    
    /// Gets the confidence threshold description
    var confidenceThresholdDescription: String {
        if confidenceThreshold >= 0.95 {
            return "Very high confidence"
        } else if confidenceThreshold >= 0.9 {
            return "High confidence"
        } else if confidenceThreshold >= 0.8 {
            return "Standard confidence"
        } else if confidenceThreshold >= 0.7 {
            return "Low confidence"
        } else {
            return "Very low confidence"
        }
    }
    
    /// Gets the JPEG quality description
    var jpegQualityDescription: String {
        if jpegQuality >= 0.95 {
            return "Maximum quality"
        } else if jpegQuality >= 0.9 {
            return "High quality"
        } else if jpegQuality >= 0.8 {
            return "Good quality"
        } else if jpegQuality >= 0.7 {
            return "Standard quality"
        } else {
            return "Compressed quality"
        }
    }
    
    /// Gets the guide opacity description
    var guideOpacityDescription: String {
        if guideOpacity >= 0.9 {
            return "Very visible"
        } else if guideOpacity >= 0.7 {
            return "Visible"
        } else if guideOpacity >= 0.5 {
            return "Semi-transparent"
        } else if guideOpacity >= 0.3 {
            return "Subtle"
        } else {
            return "Very subtle"
        }
    }
}

/// Export target enumeration
enum ExportTarget: String, Codable, CaseIterable {
    case shareSheet = "shareSheet"
    case files = "files"
    case s3 = "s3"
    case webdav = "webdav"
    
    /// Human-readable description
    var description: String {
        switch self {
        case .shareSheet:
            return "Share Sheet"
        case .files:
            return "Files App"
        case .s3:
            return "Amazon S3"
        case .webdav:
            return "WebDAV Server"
        }
    }
    
    /// Whether this target requires network connectivity
    var requiresNetwork: Bool {
        switch self {
        case .shareSheet, .files:
            return false
        case .s3, .webdav:
            return true
        }
    }
    
    /// Whether this target requires authentication
    var requiresAuthentication: Bool {
        switch self {
        case .shareSheet, .files:
            return false
        case .s3, .webdav:
            return true
        }
    }
    
    /// Gets the icon name for UI
    var iconName: String {
        switch self {
        case .shareSheet:
            return "square.and.arrow.up"
        case .files:
            return "folder"
        case .s3:
            return "cloud"
        case .webdav:
            return "server.rack"
        }
    }
    
    /// Gets the color for UI
    var color: String {
        switch self {
        case .shareSheet:
            return "blue"
        case .files:
            return "orange"
        case .s3:
            return "green"
        case .webdav:
            return "purple"
        }
    }
}

// MARK: - Default Settings
extension SessionSettings {
    /// Default settings for new sessions
    static let `default` = SessionSettings()
    
    /// Conservative settings for high-quality captures
    static let conservative = SessionSettings(
        stabilityFrames: 7,
        confidenceThreshold: 0.9,
        shutterDelay: 1.0,
        lockExposure: true,
        jpegQuality: 0.95,
        guideOpacity: 0.8,
        voicePrompts: true,
        exportTarget: .shareSheet,
        thermalThreshold: 0.7
    )
    
    /// Fast settings for quick captures
    static let fast = SessionSettings(
        stabilityFrames: 3,
        confidenceThreshold: 0.8,
        shutterDelay: 0.3,
        lockExposure: true,
        jpegQuality: 0.85,
        guideOpacity: 0.6,
        voicePrompts: false,
        exportTarget: .shareSheet,
        thermalThreshold: 0.9
    )
    
    /// Debug settings for development
    static let debug = SessionSettings(
        stabilityFrames: 1,
        confidenceThreshold: 0.5,
        shutterDelay: 0.1,
        lockExposure: false,
        jpegQuality: 0.7,
        guideOpacity: 0.9,
        voicePrompts: true,
        exportTarget: .shareSheet,
        thermalThreshold: 0.95
    )
}
