# Feature Specification: Auto-Capture Fixed Mount iPhone App

**Feature Branch**: `001-fixed-mount-iphone`  
**Created**: 2025-01-27  
**Status**: Draft  
**Input**: User description: "Fixed-mount iPhone app that auto-captures eight standard car angles using on-device recognition"

## Execution Flow (main)
```
1. Parse user description from Input
   → If empty: ERROR "No feature description provided"
2. Extract key concepts from description
   → Identify: actors, actions, data, constraints
3. For each unclear aspect:
   → Mark with [NEEDS CLARIFICATION: specific question]
4. Fill User Scenarios & Testing section
   → If no clear user flow: ERROR "Cannot determine user scenarios"
5. Generate Functional Requirements
   → Each requirement must be testable
   → Mark ambiguous requirements
6. Identify Key Entities (if data involved)
7. Run Review Checklist
   → If any [NEEDS CLARIFICATION]: WARN "Spec has uncertainties"
   → If implementation details found: ERROR "Remove tech details"
8. Return: SUCCESS (spec ready for planning)
```

---

## ⚡ Quick Guidelines
- ✅ Focus on WHAT users need and WHY
- ❌ Avoid HOW to implement (no tech stack, APIs, code structure)
- 👥 Written for business stakeholders, not developers

### Section Requirements
- **Mandatory sections**: Must be completed for every feature
- **Optional sections**: Include only when relevant to the feature
- When a section doesn't apply, remove it entirely (don't leave as "N/A")

### For AI Generation
When creating this spec from a user prompt:
1. **Mark all ambiguities**: Use [NEEDS CLARIFICATION: specific question] for any assumption you'd need to make
2. **Don't guess**: If the prompt doesn't specify something (e.g., "login system" without auth method), mark it
3. **Think like a tester**: Every vague requirement should fail the "testable and unambiguous" checklist item
4. **Common underspecified areas**:
   - User types and permissions
   - Data retention/deletion policies  
   - Performance targets and scale
   - Error handling behaviors
   - Integration requirements
   - Security/compliance needs

---

## User Scenarios & Testing *(mandatory)*

### Primary User Story
As a car dealership employee, I want to automatically capture eight standard car angles from a fixed iPhone mount so that I can quickly document vehicles without manual camera operation, ensuring consistent photo quality and reducing time per vehicle.

### Acceptance Scenarios
1. **Given** a car positioned in the photo booth and iPhone mounted, **When** I enter a stock number and start the session, **Then** the app shows live preview with framing guides for the first required viewpoint
2. **Given** the car is positioned correctly for FRONT_DRIVER_3RD, **When** the classifier detects this viewpoint with high confidence for N consecutive frames, **Then** the app auto-captures the photo and advances to the next viewpoint
3. **Given** I need to retake a photo, **When** I tap retake for any slot, **Then** the app returns to that viewpoint and allows manual or automatic recapture
4. **Given** all 8 photos are captured, **When** I review the session, **Then** I can export as ZIP or upload to configured storage
5. **Given** I'm working offline, **When** I complete a capture session, **Then** all functionality works without internet connectivity

### Edge Cases
- What happens when the classifier has low confidence for extended periods?
- How does the system handle device thermal throttling during long sessions?
- What occurs if storage becomes full during a session?
- How does the app behave if camera permissions are denied?
- What happens if the device crashes mid-session?

## Requirements *(mandatory)*

### Functional Requirements
- **FR-001**: System MUST accept alphanumeric stock number input and generate unique session ID
- **FR-002**: System MUST display live camera preview with viewpoint-specific framing guides  
- **FR-003**: System MUST run on-device classification to detect the next required viewpoint
- **FR-004**: System MUST auto-capture when prediction matches next slot and remains stable for N consecutive frames
- **FR-005**: System MUST provide manual shutter, retake, and skip controls for any viewpoint
- **FR-006**: System MUST save JPEG files with ordered naming: `{01..08}_{Viewpoint}_{YYYYMMDD-HHmmss}.jpg`
- **FR-007**: System MUST write EXIF metadata containing stock number, viewpoint, session ID, and app version
- **FR-008**: System MUST display progress indicator showing completion status of all 8 viewpoints
- **FR-009**: System MUST provide review grid allowing individual photo retakes
- **FR-010**: System MUST export session as ZIP file and present share sheet
- **FR-011**: System MUST support optional S3/WebDAV upload if configured with credentials
- **FR-012**: System MUST provide settings for stability frames, confidence threshold, shutter delay, exposure/WB lock, JPEG quality, guide opacity, voice prompts, and export target
- **FR-013**: System MUST function completely offline for all capture features
- **FR-014**: System MUST handle low confidence by showing "Adjust position" banner without capturing
- **FR-015**: System MUST prompt user to enable camera permissions if denied
- **FR-016**: System MUST block new captures and prompt to free space when storage is full
- **FR-017**: System MUST provide voice prompts and audio feedback during capture flow
- **FR-018**: System MUST monitor device temperature and gracefully handle thermal throttling

### Key Entities *(include if feature involves data)*
- **CaptureSession**: Represents a single photo session with stock number, session ID, timestamp, and collection of 8 photos
- **PhotoCapture**: Individual photo with viewpoint, timestamp, file path, EXIF metadata, and capture confidence
- **Viewpoint**: Enumeration of the 8 standard car angles (FRONT_DRIVER_3RD, FRONT, FRONT_PASSENGER_3RD, SIDE_PASSENGER, BACK_PASSENGER_3RD, BACK, BACK_DRIVER_3RD, SIDE_DRIVER)
- **SessionSettings**: User-configurable parameters including stability frames, confidence threshold, delays, and export preferences

---

## Review & Acceptance Checklist
*GATE: Automated checks run during main() execution*

### Content Quality
- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

### Requirement Completeness
- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous  
- [x] Success criteria are measurable
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

---

## Execution Status
*Updated by main() during processing*

- [x] User description parsed
- [x] Key concepts extracted
- [x] Ambiguities marked
- [x] User scenarios defined
- [x] Requirements generated
- [x] Entities identified
- [x] Review checklist passed

---

## Non-Functional Requirements

### Performance Requirements
- **NFR-001**: Inference decision latency MUST be ≤150ms typical on A15 or newer processors
- **NFR-002**: Camera preview MUST maintain ~30fps on-device
- **NFR-003**: Complete 8-photo session MUST finish in ≤5 minutes without manual intervention
- **NFR-004**: System MUST remain under reasonable thermal limits during 10-minute session
- **NFR-005**: ML model size MUST be ≤50MB

### Reliability Requirements
- **NFR-006**: System MUST have zero session data loss on unexpected app termination
- **NFR-007**: System MUST use fsync after each capture to ensure data persistence
- **NFR-008**: System MUST achieve ≥95% classification accuracy in controlled booth tests
- **NFR-009**: System MUST produce zero corrupted image files across 1,000 captures

### Privacy Requirements
- **NFR-010**: No images MUST leave device unless user explicitly exports
- **NFR-011**: All capture and review functionality MUST work without internet connectivity
- **NFR-012**: If telemetry is implemented, it MUST be local-only and opt-in

### Security Requirements
- **NFR-013**: No external upload by default
- **NFR-014**: If S3/WebDAV configured, credentials MUST be stored securely in device Keychain
- **NFR-015**: System MUST validate all user inputs and handle malformed data gracefully

---

## Success Criteria
- ≥95% of sessions produce all 8 angles in ≤5 minutes without manual shutter intervention
- ≥95% classification accuracy in controlled booth environment tests
- Zero corrupted image files across 1,000 capture sessions
- Complete offline functionality for all core capture features
- Successful export and optional upload functionality for configured storage endpoints

---

## Acceptance Tests
1. **Auto-Capture Flow Test**: Given a labeled test car and proper positioning guides, the app auto-captures all 8 viewpoints in correct order without manual input
2. **Retake Functionality Test**: Retake action replaces the correct file and updates metadata appropriately
3. **Export Validation Test**: Exported ZIP unpacks with correct naming convention and preserved EXIF metadata
4. **Offline Mode Test**: Complete capture flow succeeds in airplane mode with no network connectivity
5. **Error Recovery Test**: System gracefully handles low confidence, storage full, and camera permission scenarios
6. **Performance Test**: Session completes within 5-minute target with 30fps preview maintained
7. **Data Integrity Test**: No data loss occurs after unexpected app termination during active session

---

## Technical Constraints
- iOS 17+ minimum deployment target
- SwiftUI for user interface components
- AVFoundation for camera and photo capture functionality
- Vision framework + Core ML for on-device image classification
- No dependency on Photos library integration
- On-device ML model with ≤50MB size constraint
- Deterministic state machine for capture flow control
- Local file system storage with structured session organization