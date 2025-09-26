import Foundation

/// Enumeration of the 8 standard car photography angles
enum Viewpoint: String, CaseIterable, Codable {
    case frontDriver3rd = "FRONT_DRIVER_3RD"
    case front = "FRONT"
    case frontPassenger3rd = "FRONT_PASSENGER_3RD"
    case sidePassenger = "SIDE_PASSENGER"
    case backPassenger3rd = "BACK_PASSENGER_3RD"
    case back = "BACK"
    case backDriver3rd = "BACK_DRIVER_3RD"
    case sideDriver = "SIDE_DRIVER"
    
    /// Human-readable description
    var description: String {
        switch self {
        case .frontDriver3rd:
            return "Front Driver 3/4"
        case .front:
            return "Front"
        case .frontPassenger3rd:
            return "Front Passenger 3/4"
        case .sidePassenger:
            return "Side Passenger"
        case .backPassenger3rd:
            return "Back Passenger 3/4"
        case .back:
            return "Back"
        case .backDriver3rd:
            return "Back Driver 3/4"
        case .sideDriver:
            return "Side Driver"
        }
    }
    
    /// Short description for UI
    var shortDescription: String {
        switch self {
        case .frontDriver3rd:
            return "FD3"
        case .front:
            return "Front"
        case .frontPassenger3rd:
            return "FP3"
        case .sidePassenger:
            return "SP"
        case .backPassenger3rd:
            return "BP3"
        case .back:
            return "Back"
        case .backDriver3rd:
            return "BD3"
        case .sideDriver:
            return "SD"
        }
    }
    
    /// Order in the capture sequence (1-8)
    var order: Int {
        switch self {
        case .frontDriver3rd: return 1
        case .front: return 2
        case .frontPassenger3rd: return 3
        case .sidePassenger: return 4
        case .backPassenger3rd: return 5
        case .back: return 6
        case .backDriver3rd: return 7
        case .sideDriver: return 8
        }
    }
    
    /// Gets the next viewpoint in sequence
    var next: Viewpoint? {
        let allViewpoints = Viewpoint.allCases.sorted { $0.order < $1.order }
        guard let currentIndex = allViewpoints.firstIndex(of: self),
              currentIndex < allViewpoints.count - 1 else {
            return nil
        }
        return allViewpoints[currentIndex + 1]
    }
    
    /// Gets the previous viewpoint in sequence
    var previous: Viewpoint? {
        let allViewpoints = Viewpoint.allCases.sorted { $0.order < $1.order }
        guard let currentIndex = allViewpoints.firstIndex(of: self),
              currentIndex > 0 else {
            return nil
        }
        return allViewpoints[currentIndex - 1]
    }
    
    /// Gets viewpoint by order number
    static func byOrder(_ order: Int) -> Viewpoint? {
        return allCases.first { $0.order == order }
    }
    
    /// Gets the first viewpoint in sequence
    static var first: Viewpoint {
        return .frontDriver3rd
    }
    
    /// Gets the last viewpoint in sequence
    static var last: Viewpoint {
        return .sideDriver
    }
    
    /// Gets all viewpoints in capture order
    static var inOrder: [Viewpoint] {
        return allCases.sorted { $0.order < $1.order }
    }
    
    /// Checks if this is the first viewpoint
    var isFirst: Bool {
        return self == .frontDriver3rd
    }
    
    /// Checks if this is the last viewpoint
    var isLast: Bool {
        return self == .sideDriver
    }
    
    /// Gets the opposite side viewpoint (for driver/passenger)
    var oppositeSide: Viewpoint? {
        switch self {
        case .frontDriver3rd:
            return .frontPassenger3rd
        case .frontPassenger3rd:
            return .frontDriver3rd
        case .sidePassenger:
            return .sideDriver
        case .sideDriver:
            return .sidePassenger
        case .backDriver3rd:
            return .backPassenger3rd
        case .backPassenger3rd:
            return .backDriver3rd
        case .front, .back:
            return nil // No opposite for front/back
        }
    }
    
    /// Gets viewpoints on the same side (driver or passenger)
    var sameSideViewpoints: [Viewpoint] {
        switch self {
        case .frontDriver3rd, .sideDriver, .backDriver3rd:
            return [.frontDriver3rd, .sideDriver, .backDriver3rd]
        case .frontPassenger3rd, .sidePassenger, .backPassenger3rd:
            return [.frontPassenger3rd, .sidePassenger, .backPassenger3rd]
        case .front, .back:
            return [.front, .back] // Center viewpoints
        }
    }
    
    /// Gets viewpoints in the same position (front, side, back)
    var samePositionViewpoints: [Viewpoint] {
        switch self {
        case .frontDriver3rd, .front, .frontPassenger3rd:
            return [.frontDriver3rd, .front, .frontPassenger3rd]
        case .sidePassenger, .sideDriver:
            return [.sidePassenger, .sideDriver]
        case .backPassenger3rd, .back, .backDriver3rd:
            return [.backPassenger3rd, .back, .backDriver3rd]
        }
    }
    
    /// Gets the angle description for framing guides
    var angleDescription: String {
        switch self {
        case .frontDriver3rd, .frontPassenger3rd, .backDriver3rd, .backPassenger3rd:
            return "3/4 View"
        case .front, .back:
            return "Direct View"
        case .sidePassenger, .sideDriver:
            return "Side View"
        }
    }
    
    /// Gets the framing guide description
    var framingGuide: String {
        switch self {
        case .frontDriver3rd:
            return "Position vehicle so front driver's side corner is visible at 3/4 angle"
        case .front:
            return "Position vehicle directly facing camera, centered"
        case .frontPassenger3rd:
            return "Position vehicle so front passenger's side corner is visible at 3/4 angle"
        case .sidePassenger:
            return "Position vehicle so passenger side is fully visible"
        case .backPassenger3rd:
            return "Position vehicle so back passenger's side corner is visible at 3/4 angle"
        case .back:
            return "Position vehicle directly facing away from camera, centered"
        case .backDriver3rd:
            return "Position vehicle so back driver's side corner is visible at 3/4 angle"
        case .sideDriver:
            return "Position vehicle so driver side is fully visible"
        }
    }
}

// MARK: - Comparable
extension Viewpoint: Comparable {
    static func < (lhs: Viewpoint, rhs: Viewpoint) -> Bool {
        return lhs.order < rhs.order
    }
}

// MARK: - CustomStringConvertible
extension Viewpoint: CustomStringConvertible {
    // description property is already defined in the main enum
}
