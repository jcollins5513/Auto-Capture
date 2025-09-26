# Tasks: Auto-Capture Fixed Mount iPhone App

**Input**: Design documents from `/specs/001-fixed-mount-iphone/`
**Prerequisites**: plan.md (required), research.md, data-model.md, contracts/

## Execution Flow (main)
```
1. Load plan.md from feature directory
   → If not found: ERROR "No implementation plan found"
   → Extract: tech stack, libraries, structure
2. Load optional design documents:
   → data-model.md: Extract entities → model tasks
   → contracts/: Each file → contract test task
   → research.md: Extract decisions → setup tasks
3. Generate tasks by category:
   → Setup: project init, dependencies, linting
   → Tests: contract tests, integration tests
   → Core: models, services, CLI commands
   → Integration: DB, middleware, logging
   → Polish: unit tests, performance, docs
4. Apply task rules:
   → Different files = mark [P] for parallel
   → Same file = sequential (no [P])
   → Tests before implementation (TDD)
5. Number tasks sequentially (T001, T002...)
6. Generate dependency graph
7. Create parallel execution examples
8. Validate task completeness:
   → All contracts have tests?
   → All entities have models?
   → All endpoints implemented?
9. Return: SUCCESS (tasks ready for execution)
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions
- **iOS native app**: `Auto-Capture/` for main app, `Auto-CaptureTests/` for unit tests, `Auto-CaptureUITests/` for UI tests
- Paths shown below assume iOS project structure with modular organization

## Phase 3.1: Setup
- [x] T001 Create Xcode project structure with Auto-Capture target (iOS 17+, SwiftUI)
- [x] T002 [P] Add Info.plist camera permission strings (NSCameraUsageDescription)
- [x] T003 [P] Configure project dependencies (AVFoundation, Vision, Core ML, OSLog)
- [x] T004 [P] Set up modular folder structure per implementation plan

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3
**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**
- [x] T005 [P] Contract test for CaptureSessionController in Auto-CaptureTests/CaptureSessionControllerTests.swift
- [x] T006 [P] Contract test for ViewpointClassifier in Auto-CaptureTests/ViewpointClassifierTests.swift
- [x] T007 [P] Contract test for CaptureStateMachine in Auto-CaptureTests/CaptureStateMachineTests.swift
- [x] T008 [P] Contract test for SessionStore in Auto-CaptureTests/SessionStoreTests.swift
- [x] T009 [P] Unit test for file naming logic in Auto-CaptureTests/FileNamingTests.swift
- [x] T010 [P] Unit test for EXIF metadata handling in Auto-CaptureTests/EXIFTests.swift
- [x] T011 [P] Unit test for state machine transitions in Auto-CaptureTests/StateMachineTests.swift
- [x] T012 [P] UI test for complete capture flow in Auto-CaptureUITests/CaptureFlowTests.swift

## Phase 3.3: Core Implementation (ONLY after tests are failing)
- [x] T013 [P] CaptureSession model in Auto-Capture/Models/CaptureSession.swift
- [x] T014 [P] PhotoCapture model in Auto-Capture/Models/PhotoCapture.swift
- [x] T015 [P] Viewpoint enum in Auto-Capture/Models/Viewpoint.swift
- [x] T016 [P] SessionSettings model in Auto-Capture/Models/SessionSettings.swift
- [x] T017 [P] EXIFData model in Auto-Capture/Models/EXIFData.swift
- [x] T018 [P] CaptureSessionController implementation in Auto-Capture/CameraPipeline/CaptureSessionController.swift
- [x] T019 [P] PhotoCaptureManager implementation in Auto-Capture/CameraPipeline/PhotoCaptureManager.swift
- [x] T020 [P] ViewpointClassifier implementation in Auto-Capture/ML/ViewpointClassifier.swift
- [x] T021 [P] StabilityGate implementation in Auto-Capture/ML/StabilityGate.swift
- [x] T022 [P] CaptureStateMachine implementation in Auto-Capture/Flow/CaptureStateMachine.swift
- [x] T023 [P] SessionStore implementation in Auto-Capture/Storage/SessionStore.swift
- [x] T024 [P] Exporter implementation in Auto-Capture/Storage/Exporter.swift

## Phase 3.4: Integration
- [x] T025 [P] SwiftUI StartView in Auto-Capture/UI/StartView.swift
- [x] T026 [P] SwiftUI LiveCaptureView in Auto-Capture/UI/LiveCaptureView.swift
- [x] T027 [P] SwiftUI ReviewView in Auto-Capture/UI/ReviewView.swift
- [x] T028 [P] SwiftUI SettingsView in Auto-Capture/UI/SettingsView.swift
- [x] T029 [P] EXIFHandler utility in Auto-Capture/Utils/EXIFHandler.swift
- [x] T030 [P] ErrorHandler utility in Auto-Capture/Utils/ErrorHandler.swift
- [x] T031 [P] ThermalMonitor utility in Auto-Capture/Utils/ThermalMonitor.swift
- [x] T032 Core ML model integration and loading in Auto-Capture/ML/ModelManager.swift
- [x] T033 Background queue for JPEG encoding in Auto-Capture/Services/EncodingService.swift

## Phase 3.5: Polish
- [x] T034 [P] Performance tests for 30fps preview in Auto-CaptureTests/PerformanceTests.swift
- [x] T035 [P] On-device latency validation (<150ms typical) in Auto-CaptureTests/LatencyTests.swift
- [x] T036 [P] Data integrity tests (0 corrupted files across 1,000 captures) in Auto-CaptureTests/DataIntegrityTests.swift
- [x] T037 [P] Crash safety tests (no data loss on termination) in Auto-CaptureTests/CrashSafetyTests.swift
- [x] T038 [P] Manual testing with quickstart.md scenarios in Auto-CaptureUITests/QuickstartValidationTests.swift
- [x] T039 [P] Edge case tests (poor lighting, partial occlusion) in Auto-CaptureTests/EdgeCaseTests.swift

## Dependencies
- Tests (T005-T012) before implementation (T013-T033)
- Models (T013-T017) before services (T018-T024)
- Core services before integration (T025-T033)
- Integration before polish (T034-T039)
- T018 blocks T032 (camera controller before ML integration)
- T020 blocks T021 (classifier before stability gate)
- T022 blocks T025-T027 (state machine before UI views)

## Parallel Example
```
# Launch T005-T012 together (all contract and unit tests):
Task: "Contract test for CaptureSessionController in Auto-CaptureTests/CaptureSessionControllerTests.swift"
Task: "Contract test for ViewpointClassifier in Auto-CaptureTests/ViewpointClassifierTests.swift"
Task: "Contract test for CaptureStateMachine in Auto-CaptureTests/CaptureStateMachineTests.swift"
Task: "Contract test for SessionStore in Auto-CaptureTests/SessionStoreTests.swift"
Task: "Unit test for file naming logic in Auto-CaptureTests/FileNamingTests.swift"
Task: "Unit test for EXIF metadata handling in Auto-CaptureTests/EXIFTests.swift"
Task: "Unit test for state machine transitions in Auto-CaptureTests/StateMachineTests.swift"
Task: "UI test for complete capture flow in Auto-CaptureUITests/CaptureFlowTests.swift"

# Launch T013-T017 together (all model creation):
Task: "CaptureSession model in Auto-Capture/Models/CaptureSession.swift"
Task: "PhotoCapture model in Auto-Capture/Models/PhotoCapture.swift"
Task: "Viewpoint enum in Auto-Capture/Models/Viewpoint.swift"
Task: "SessionSettings model in Auto-Capture/Models/SessionSettings.swift"
Task: "EXIFData model in Auto-Capture/Models/EXIFData.swift"
```

## Notes
- [P] tasks = different files, no dependencies
- Verify tests fail before implementing
- Commit after each task
- Avoid: vague tasks, same file conflicts
- Follow Auto-Capture constitution principles throughout implementation

## Task Generation Rules
*Applied during main() execution*

1. **From Contracts**:
   - Each contract file → contract test task [P]
   - Each protocol method → implementation task
   
2. **From Data Model**:
   - Each entity → model creation task [P]
   - Relationships → validation tasks
   
3. **From User Stories**:
   - Each story → integration test [P]
   - Quickstart scenarios → validation tasks

4. **Ordering**:
   - Setup → Tests → Models → Services → UI → Polish
   - Dependencies block parallel execution

## Validation Checklist
*GATE: Checked by main() before returning*

- [x] All contracts have corresponding tests (4 contracts → 4 test tasks)
- [x] All entities have model tasks (5 entities → 5 model tasks)
- [x] All tests come before implementation
- [x] Parallel tasks truly independent
- [x] Each task specifies exact file path
- [x] No task modifies same file as another [P] task
- [x] Follows Auto-Capture constitution requirements
- [x] Includes performance and data integrity validation tasks
