<!--
Sync Impact Report:
Version change: 1.0.0 → 1.0.0 (initial creation)
Modified principles: N/A (new constitution)
Added sections: Architecture Constraints, Safety Rules, Error Handling, Performance Policy
Removed sections: N/A
Templates requiring updates:
  ✅ plan-template.md (Constitution Check section updated)
  ✅ spec-template.md (Auto-Capture specific requirements)
  ✅ tasks-template.md (iOS/SwiftUI task patterns)
Follow-up TODOs: None
-->

# Auto-Capture Constitution

## Core Principles

### I. Offline-First
All capture and review functionality MUST work without network connectivity. ML inference MUST run on-device using Core ML. No cloud dependencies during normal operation. Export and upload are explicit opt-in actions only.

### II. Privacy-by-Default  
Images and metadata MUST remain on device unless user explicitly exports. No background analytics, telemetry, or tracking by default. If telemetry is added later, it MUST be off by default and fully documented.

### III. Determinism
Same inputs MUST yield the same outputs. No hidden randomness in capture flow. State machine MUST be deterministic. File naming MUST be predictable and ordered.

### IV. Safety
MUST be used only in controlled areas. Clear prompts and minimal driver attention burden. Voice prompts to minimize distraction. Block capture at critical device temperatures. Disable flash by default.

### V. Performance
Preview MUST maintain ≥30 fps on iPhone 13+. Inference decisions ≤150ms typical, ≤300ms p95. Complete 8-image session ≤5 minutes in booth conditions. Thermal awareness and frame drop handling required.

### VI. Maintainability
Small, focused modules with clear contracts. Tests before features. Unit tests for naming, EXIF, state transitions. UI tests for complete flows. On-device performance validation required.

## Architecture Constraints

**UI**: SwiftUI (iOS 17+)  
**Camera**: AVFoundation (`AVCaptureSession`, `AVCapturePhotoOutput`), 4:3 stills  
**ML**: Core ML + Vision (`VNCoreMLRequest`) image classification with 8 classes  
**State**: Deterministic finite state machine controlling capture order and overrides  
**Storage**: App Documents → `Sessions/{stock}-{YYYYMMDD-HHmmss}/`  
**Naming**: `{01..08}_{Viewpoint}_{YYYYMMDD-HHmmss}.jpg`  
**Metadata**: EXIF contains stock, viewpoint, sessionId, app version  
**Settings**: UserDefaults (stability frames, confidence, delay, AE/WB lock, JPEG quality, guide opacity, voice prompts, export target)  
**Export**: ZIP + Share Sheet. Optional S3/WebDAV via URLSession. Credentials in Keychain.

## Safety Rules

MUST show "Use only in controlled space" banner on first run and in Settings. Voice prompts minimize driver distraction. No long on-screen text during motion. Block capture if device temperature reaches critical thresholds. Disable flash by default to avoid glare unless user enables it.

## Error Handling

Low confidence → "Adjust position" banner, no capture trigger. Storage full → block capture, prompt to export or free space. Camera denied → single action to open Settings. All errors MUST be recoverable without data loss.

## Performance Policy

Throttle inference (e.g., every k frames) if frame drops occur. Lock AE/WB before shutter then restore. Use background queue for JPEG encoding and ZIP. Monitor thermal state and gracefully degrade if needed.

## Quality Bars

- Preview frame rate: ≥30 fps on iPhone 13+
- Inference decision latency: ≤150ms typical, ≤300ms p95  
- Session time: 8 images in ≤5 minutes in booth conditions
- Classifier accuracy: ≥95% on held-out booth dataset
- Data integrity: 0 corrupted files across 1,000 captures
- Crash safety: no data loss after unexpected termination

## Development Workflow

PRs MUST include: summary, risk assessment, test evidence (screens or logs), and updated docs if behavior changes. No PR merges that violate this Constitution without an amendment. Unit tests for naming, EXIF, state transitions. UI tests for flow. On-device perf checks for p95 latency.

## Governance

Constitution supersedes all other practices. Changes to principles, non-goals, quality bars, or architecture constraints require: (1) dedicated PR, (2) rationale and trade-off record in PR description, (3) updates to Plan/Spec/Tasks as needed. Approval from project owner required. All PRs/reviews must verify compliance. Complexity must be justified.

**Version**: 1.0.0 | **Ratified**: 2025-01-27 | **Last Amended**: 2025-01-27