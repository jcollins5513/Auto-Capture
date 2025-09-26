# AGENTS.md

## Project Purpose
Automate eight standard vehicle photos from a fixed iPhone mount using on-device ML.

## Setup
- Xcode 16+, iOS 17+ SDK
- `ios/Auto-Capture.xcodeproj`
- Run target: Auto-Capture on a real device

## Commands
- Build: Xcode default build
- Lint: SwiftLint (if present)
- Tests: Xcode test plan

## Code Conventions
- SwiftUI for UI. AVFoundation for capture. Vision+CoreML for inference.
- No external network calls unless export is invoked.

## Important Paths
- Capture pipeline: `ios/.../CameraPipeline`
- ML wrapper: `ios/.../ML`
- State machine: `ios/.../Flow`
- Storage/export: `ios/.../Storage`, `ios/.../Export`
- Docs: `/docs`

## Model Contract
`ViewpointClassifier.classify(pixelBuffer) -> (label: Viewpoint, confidence: Double)`  
Labels: see Spec.md “Viewpoints Canonical Labels”.  
Tunable: `stabilityFrames`, `confidenceThreshold`.

## Quality Bar
- Preview ~30 fps, capture latency ≤ 300 ms from stability trigger.
- Crash-safe writes. Zero data loss on power loss.

## Guardrails
- Keep capture offline. Do not add trackers or analytics without user opt-in.
- Do not depend on Photos library.

## Roadmap Hints
- Optional AR overlay alignment
- Optional segmentation to mask background
- Optional voice guidance

## Agent Tasks
- Prioritize Tasks.md in order.
- Keep PRs atomic and documented.
- Update Spec.md if behavior changes.

## Dev Environment Tips
- Use `swiftlint` to check code quality before commits
- Run tests on real device for ML performance validation
- Use Xcode's built-in Core ML model validation tools

## Testing Instructions
- Run `swiftlint` before committing
- Execute Xcode test plan on real device
- Validate ML model performance with test dataset

## PR Instructions
- Title format: [Auto-Capture] <Description>
- Always run `swiftlint` and tests before committing
- Update Spec.md if behavior changes