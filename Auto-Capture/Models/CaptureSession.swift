import Foundation

/// Represents a complete photo session for one vehicle
struct CaptureSession: Codable, Identifiable {
    let id: UUID
    let stockNumber: String
    let createdAt: Date
    var completedAt: Date?
    var status: SessionStatus
    var photos: [PhotoCapture]
    let settings: SessionSettings
    
    init(
        id: UUID = UUID(),
        stockNumber: String,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        status: SessionStatus = .created,
        photos: [PhotoCapture] = [],
        settings: SessionSettings
    ) {
        self.id = id
        self.stockNumber = stockNumber
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.status = status
        self.photos = photos
        self.settings = settings
    }
    
    /// Validates the session data
    var isValid: Bool {
        return isValidStockNumber(stockNumber) &&
               (completedAt == nil || completedAt! >= createdAt) &&
               photos.count <= 8 &&
               isValidStatusTransition
    }
    
    /// Checks if stock number is valid (alphanumeric, 3-20 characters)
    private func isValidStockNumber(_ stockNumber: String) -> Bool {
        let pattern = "^[A-Za-z0-9]{3,20}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: stockNumber.utf16.count)
        return regex?.firstMatch(in: stockNumber, options: [], range: range) != nil
    }
    
    /// Validates status transitions according to state machine rules
    private var isValidStatusTransition: Bool {
        switch status {
        case .created:
            return photos.isEmpty
        case .inProgress:
            return !photos.isEmpty && photos.count < 8
        case .completed:
            return photos.count == 8
        case .cancelled:
            return true // Can be cancelled at any time
        case .exported:
            return status == .completed
        }
    }
    
    /// Adds a photo to the session
    mutating func addPhoto(_ photo: PhotoCapture) {
        guard photos.count < 8 else { return }
        photos.append(photo)
        
        // Update status based on photo count
        if photos.count == 1 && status == .created {
            status = .inProgress
        } else if photos.count == 8 && status == .inProgress {
            status = .completed
            completedAt = Date()
        }
    }
    
    /// Removes a photo from the session
    mutating func removePhoto(withId photoId: UUID) {
        photos.removeAll { $0.id == photoId }
        
        // Update status based on photo count
        if photos.isEmpty && status == .inProgress {
            status = .created
        }
    }
    
    /// Marks the session as exported
    mutating func markAsExported() {
        if status == .completed {
            status = .exported
        }
    }
    
    /// Cancels the session
    mutating func cancel() {
        status = .cancelled
    }
    
    /// Gets the next required viewpoint
    var nextRequiredViewpoint: Viewpoint? {
        let capturedViewpoints = Set(photos.map { $0.viewpoint })
        let allViewpoints = Viewpoint.allCases
        
        for viewpoint in allViewpoints {
            if !capturedViewpoints.contains(viewpoint) {
                return viewpoint
            }
        }
        
        return nil // All viewpoints captured
    }
    
    /// Checks if a specific viewpoint is captured
    func isViewpointCaptured(_ viewpoint: Viewpoint) -> Bool {
        return photos.contains { $0.viewpoint == viewpoint }
    }
    
    /// Gets the photo for a specific viewpoint
    func photo(for viewpoint: Viewpoint) -> PhotoCapture? {
        return photos.first { $0.viewpoint == viewpoint }
    }
    
    /// Calculates session progress percentage
    var progressPercentage: Float {
        return Float(photos.count) / 8.0
    }
    
    /// Checks if session is complete
    var isComplete: Bool {
        return photos.count == 8
    }
}

/// Session status enumeration
enum SessionStatus: String, Codable, CaseIterable {
    case created = "created"
    case inProgress = "inProgress"
    case completed = "completed"
    case cancelled = "cancelled"
    case exported = "exported"
    
    /// Human-readable description
    var description: String {
        switch self {
        case .created:
            return "Created"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        case .cancelled:
            return "Cancelled"
        case .exported:
            return "Exported"
        }
    }
    
    /// Whether the session can be modified
    var isModifiable: Bool {
        switch self {
        case .created, .inProgress:
            return true
        case .completed, .cancelled, .exported:
            return false
        }
    }
}

// MARK: - Equatable
extension CaptureSession: Equatable {
    static func == (lhs: CaptureSession, rhs: CaptureSession) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Hashable
extension CaptureSession: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
