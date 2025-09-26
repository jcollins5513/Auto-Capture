# Research Findings: Auto-Capture Fixed Mount iPhone App

## Technology Decisions

### Core ML Model Strategy
**Decision**: Use Create ML or convert existing model to Core ML format for 8-class viewpoint classification
**Rationale**: Core ML provides optimized on-device inference with Vision framework integration. Supports real-time classification with <150ms latency on A15+ processors.
**Alternatives considered**: 
- Cloud-based inference (rejected: violates offline-first principle)
- Custom Vision framework implementation (rejected: Core ML provides better optimization)

### Camera Pipeline Architecture
**Decision**: AVFoundation with AVCaptureSession, AVCaptureDevice, and AVCapturePhotoOutput
**Rationale**: Native iOS camera framework provides best performance and control. Supports 4:3 aspect ratio, exposure/WB locking, and high-quality JPEG output.
**Alternatives considered**:
- CameraKit (rejected: adds complexity, less control)
- Custom camera implementation (rejected: unnecessary complexity)

### State Management Approach
**Decision**: Deterministic finite state machine for capture flow control
**Rationale**: Ensures predictable behavior, handles retakes and skips correctly, maintains session integrity.
**Alternatives considered**:
- Reactive state management (rejected: adds complexity for simple linear flow)
- Simple boolean flags (rejected: insufficient for complex retake/skip scenarios)

### Storage Strategy
**Decision**: App Documents directory with structured session folders
**Rationale**: Secure, private storage that doesn't require Photos library access. Supports organized session management and easy export.
**Alternatives considered**:
- Photos library integration (rejected: violates privacy-by-default principle)
- Cloud storage only (rejected: violates offline-first principle)

### Export Mechanism
**Decision**: ZIP creation with Share Sheet + optional S3/WebDAV upload
**Rationale**: Provides flexible export options while maintaining privacy controls. Share Sheet allows user choice of destination.
**Alternatives considered**:
- Direct cloud upload only (rejected: reduces user control)
- Email-only export (rejected: too limiting)

## Performance Optimizations

### Inference Throttling
**Decision**: Process every k frames instead of every frame to maintain 30fps preview
**Rationale**: Balances classification accuracy with preview performance. Reduces thermal load and battery consumption.
**Alternatives considered**:
- Process every frame (rejected: causes frame drops)
- Fixed interval processing (rejected: less responsive to user positioning)

### Thermal Management
**Decision**: Monitor device temperature and gracefully degrade performance
**Rationale**: Prevents device shutdown during long sessions. Maintains usability while protecting hardware.
**Alternatives considered**:
- Ignore thermal state (rejected: causes crashes)
- Stop all processing (rejected: too aggressive)

## ML Model Considerations

### Training Data Requirements
**Decision**: Collect labeled booth images with balanced viewpoint classes
**Rationale**: Balanced dataset improves classification accuracy. Booth-specific training handles lighting and positioning variations.
**Alternatives considered**:
- Generic car dataset (rejected: doesn't match booth conditions)
- Synthetic data only (rejected: insufficient for real-world accuracy)

### Model Size Constraint
**Decision**: Keep model ≤50MB for reasonable download and storage
**Rationale**: Balances accuracy with storage efficiency. Fits comfortably in app bundle.
**Alternatives considered**:
- Larger models (rejected: storage and download concerns)
- Smaller models (rejected: likely accuracy compromise)

## Error Handling Strategies

### Low Confidence Handling
**Decision**: Show "Adjust position" banner without capturing
**Rationale**: Prevents poor quality captures while guiding user to correct positioning.
**Alternatives considered**:
- Capture anyway (rejected: leads to poor results)
- Auto-retry (rejected: could create infinite loops)

### Storage Full Handling
**Decision**: Block new captures and prompt for export/cleanup
**Rationale**: Prevents data loss and gives user control over storage management.
**Alternatives considered**:
- Overwrite old sessions (rejected: potential data loss)
- Compress existing images (rejected: quality degradation)

## Security and Privacy

### Credential Storage
**Decision**: Store S3/WebDAV credentials in iOS Keychain
**Rationale**: Secure storage that follows iOS best practices. Credentials are encrypted and protected.
**Alternatives considered**:
- Plain text storage (rejected: security risk)
- User re-entry (rejected: poor user experience)

### Local Telemetry
**Decision**: Optional local-only telemetry for performance monitoring
**Rationale**: Helps with debugging and optimization without compromising privacy.
**Alternatives considered**:
- No telemetry (rejected: harder to optimize)
- Cloud telemetry (rejected: violates privacy principle)
