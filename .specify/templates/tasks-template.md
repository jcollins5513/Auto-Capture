# Tasks: [FEATURE NAME]

**Input**: Design documents from `/specs/[###-feature-name]/`
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
- **Single project**: `src/`, `tests/` at repository root
- **Web app**: `backend/src/`, `frontend/src/`
- **Mobile**: `api/src/`, `ios/src/` or `android/src/`
- Paths shown below assume single project - adjust based on plan.md structure

## Phase 3.1: Setup
- [ ] T001 Create project structure per implementation plan
- [ ] T002 Initialize [language] project with [framework] dependencies
- [ ] T003 [P] Configure linting and formatting tools

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3
**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**
- [ ] T004 [P] Unit test for file naming logic in Auto-CaptureTests/FileNamingTests.swift
- [ ] T005 [P] Unit test for EXIF metadata handling in Auto-CaptureTests/EXIFTests.swift
- [ ] T006 [P] Unit test for state machine transitions in Auto-CaptureTests/StateMachineTests.swift
- [ ] T007 [P] UI test for complete capture flow in Auto-CaptureUITests/CaptureFlowTests.swift

## Phase 3.3: Core Implementation (ONLY after tests are failing)
- [ ] T008 [P] CaptureSession model in Auto-Capture/Models/CaptureSession.swift
- [ ] T009 [P] ViewpointClassifier service in Auto-Capture/Services/ViewpointClassifier.swift
- [ ] T010 [P] StateMachine for capture flow in Auto-Capture/State/StateMachine.swift
- [ ] T011 [P] CameraManager for AVFoundation in Auto-Capture/Services/CameraManager.swift
- [ ] T012 [P] FileManager for storage in Auto-Capture/Services/FileManager.swift
- [ ] T013 [P] EXIF metadata handling in Auto-Capture/Utils/EXIFHandler.swift
- [ ] T014 [P] Error handling and logging in Auto-Capture/Utils/ErrorHandler.swift

## Phase 3.4: Integration
- [ ] T015 [P] SwiftUI Views for capture interface in Auto-Capture/Views/
- [ ] T016 [P] Core ML model integration in Auto-Capture/ML/ModelManager.swift
- [ ] T017 [P] Background queue for JPEG encoding in Auto-Capture/Services/EncodingService.swift
- [ ] T018 [P] Thermal monitoring in Auto-Capture/Services/ThermalMonitor.swift

## Phase 3.5: Polish
- [ ] T019 [P] Performance tests for 30fps preview in Auto-CaptureTests/PerformanceTests.swift
- [ ] T020 [P] On-device latency validation (<150ms typical)
- [ ] T021 [P] Data integrity tests (0 corrupted files across 1,000 captures)
- [ ] T022 [P] Crash safety tests (no data loss on termination)
- [ ] T023 [P] Manual testing with quickstart.md scenarios

## Dependencies
- Tests (T004-T007) before implementation (T008-T014)
- T008 blocks T009, T015
- T016 blocks T018
- Implementation before polish (T019-T023)

## Parallel Example
```
# Launch T004-T007 together:
Task: "Unit test for file naming logic in Auto-CaptureTests/FileNamingTests.swift"
Task: "Unit test for EXIF metadata handling in Auto-CaptureTests/EXIFTests.swift"
Task: "Unit test for state machine transitions in Auto-CaptureTests/StateMachineTests.swift"
Task: "UI test for complete capture flow in Auto-CaptureUITests/CaptureFlowTests.swift"
```

## Notes
- [P] tasks = different files, no dependencies
- Verify tests fail before implementing
- Commit after each task
- Avoid: vague tasks, same file conflicts

## Task Generation Rules
*Applied during main() execution*

1. **From Contracts**:
   - Each contract file → contract test task [P]
   - Each endpoint → implementation task
   
2. **From Data Model**:
   - Each entity → model creation task [P]
   - Relationships → service layer tasks
   
3. **From User Stories**:
   - Each story → integration test [P]
   - Quickstart scenarios → validation tasks

4. **Ordering**:
   - Setup → Tests → Models → Services → Endpoints → Polish
   - Dependencies block parallel execution

## Validation Checklist
*GATE: Checked by main() before returning*

- [ ] All contracts have corresponding tests
- [ ] All entities have model tasks
- [ ] All tests come before implementation
- [ ] Parallel tasks truly independent
- [ ] Each task specifies exact file path
- [ ] No task modifies same file as another [P] task