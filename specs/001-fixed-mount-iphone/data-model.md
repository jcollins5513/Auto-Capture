# Data Model: Auto-Capture Fixed Mount iPhone App

## Core Entities

### CaptureSession
**Purpose**: Represents a complete photo session for one vehicle
**Fields**:
- `id: UUID` - Unique session identifier
- `stockNumber: String` - Alphanumeric vehicle stock number
- `createdAt: Date` - Session start timestamp
- `completedAt: Date?` - Session completion timestamp (nil if incomplete)
- `status: SessionStatus` - Current session state
- `photos: [PhotoCapture]` - Collection of captured photos (0-8)
- `settings: SessionSettings` - User preferences used for this session

**Validation Rules**:
- Stock number must be alphanumeric, 3-20 characters
- CreatedAt must be before completedAt (if set)
- Photos array cannot exceed 8 items
- Status transitions must follow state machine rules

**State Transitions**:
- `created` → `inProgress` (when first photo captured)
- `inProgress` → `completed` (when all 8 photos captured)
- `inProgress` → `cancelled` (user cancels session)
- `completed` → `exported` (session exported)

### PhotoCapture
**Purpose**: Represents a single captured photo within a session
**Fields**:
- `id: UUID` - Unique photo identifier
- `sessionId: UUID` - Reference to parent session
- `viewpoint: Viewpoint` - Standard car angle captured
- `order: Int` - Sequential order in session (1-8)
- `capturedAt: Date` - Photo capture timestamp
- `filePath: String` - Local file system path
- `confidence: Float` - ML classification confidence (0.0-1.0)
- `isRetake: Bool` - Whether this is a retake of a previous photo
- `originalPhotoId: UUID?` - Reference to original photo if this is a retake
- `exifData: EXIFData` - Embedded metadata

**Validation Rules**:
- Order must be between 1 and 8
- Confidence must be between 0.0 and 1.0
- FilePath must exist and be accessible
- If isRetake is true, originalPhotoId must be set
- CapturedAt must be after session creation

### Viewpoint
**Purpose**: Enumeration of the 8 standard car photography angles
**Values**:
- `frontDriver3rd` - Front driver's side 3/4 view
- `front` - Direct front view
- `frontPassenger3rd` - Front passenger's side 3/4 view
- `sidePassenger` - Side passenger view
- `backPassenger3rd` - Back passenger's side 3/4 view
- `back` - Direct back view
- `backDriver3rd` - Back driver's side 3/4 view
- `sideDriver` - Side driver view

**Validation Rules**:
- Must be one of the 8 defined values
- Order follows standard automotive photography sequence
- Each viewpoint has associated framing guides and ML training labels

### SessionSettings
**Purpose**: User-configurable parameters for capture sessions
**Fields**:
- `stabilityFrames: Int` - Number of consecutive frames required for stability (default: 5)
- `confidenceThreshold: Float` - Minimum confidence for auto-capture (default: 0.85)
- `shutterDelay: TimeInterval` - Delay before capture after stability (default: 0.5s)
- `lockExposure: Bool` - Whether to lock exposure/WB before capture (default: true)
- `jpegQuality: Float` - JPEG compression quality (default: 0.9)
- `guideOpacity: Float` - Framing guide overlay opacity (default: 0.7)
- `voicePrompts: Bool` - Enable voice prompts (default: true)
- `exportTarget: ExportTarget` - Default export destination
- `thermalThreshold: Float` - Device temperature threshold for throttling (default: 0.8)

**Validation Rules**:
- StabilityFrames must be between 1 and 20
- ConfidenceThreshold must be between 0.5 and 1.0
- ShutterDelay must be between 0.0 and 5.0 seconds
- JPEGQuality must be between 0.1 and 1.0
- GuideOpacity must be between 0.0 and 1.0
- ThermalThreshold must be between 0.0 and 1.0

### EXIFData
**Purpose**: Metadata embedded in captured photos
**Fields**:
- `stockNumber: String` - Vehicle stock number
- `viewpoint: String` - Viewpoint name
- `sessionId: String` - Session identifier
- `appVersion: String` - App version that captured the photo
- `captureTimestamp: Date` - When photo was captured
- `deviceModel: String` - iPhone model used
- `iosVersion: String` - iOS version
- `cameraSettings: CameraSettings` - Camera configuration used

**Validation Rules**:
- All fields must be non-empty strings (except optional camera settings)
- CaptureTimestamp must match photo file creation time
- AppVersion must follow semantic versioning format

### CameraSettings
**Purpose**: Camera configuration used for capture
**Fields**:
- `iso: Float` - ISO sensitivity
- `shutterSpeed: Float` - Shutter speed in seconds
- `aperture: Float` - Aperture value
- `focalLength: Float` - Lens focal length
- `flashMode: FlashMode` - Flash setting used
- `whiteBalance: WhiteBalanceMode` - White balance mode
- `exposureMode: ExposureMode` - Exposure mode

## Relationships

### CaptureSession → PhotoCapture
- **Type**: One-to-Many
- **Cardinality**: 1 session has 0-8 photos
- **Constraint**: Photos must belong to exactly one session

### PhotoCapture → Viewpoint
- **Type**: Many-to-One
- **Cardinality**: Multiple photos can have same viewpoint (retakes)
- **Constraint**: Each photo must have exactly one viewpoint

### PhotoCapture → EXIFData
- **Type**: One-to-One
- **Cardinality**: Each photo has exactly one EXIF record
- **Constraint**: EXIF data must match photo metadata

### CaptureSession → SessionSettings
- **Type**: One-to-One
- **Cardinality**: Each session uses one settings configuration
- **Constraint**: Settings are captured at session start (immutable during session)

## State Machine Rules

### Session Status Transitions
```
created → inProgress → completed → exported
   ↓         ↓
cancelled  cancelled
```

### Photo Capture Flow
```
waiting → detecting → stable → capturing → captured
   ↓         ↓         ↓         ↓
failed    failed    failed    failed
```

### Retake Flow
```
captured → retaking → detecting → stable → capturing → captured
```

## Data Persistence

### Storage Locations
- **Sessions**: `Documents/Sessions/{stockNumber}-{sessionId}/`
- **Photos**: `Documents/Sessions/{stockNumber}-{sessionId}/{order}_{viewpoint}_{timestamp}.jpg`
- **Settings**: UserDefaults with key `AutoCapture.Settings`
- **Credentials**: iOS Keychain for S3/WebDAV

### Backup and Recovery
- Session data is automatically backed up to iCloud (if enabled)
- Export creates ZIP with all session data
- No data loss on app crash (fsync after each capture)

## Data Validation

### Input Validation
- Stock numbers: alphanumeric, 3-20 characters
- Timestamps: must be reasonable (not future, not too old)
- File paths: must exist and be accessible
- Confidence values: must be valid probability (0.0-1.0)

### Business Logic Validation
- Cannot capture duplicate viewpoints in same session
- Cannot exceed 8 photos per session
- Cannot retake non-existent photos
- Session cannot be completed with missing viewpoints
