# Quickstart Guide: Auto-Capture Fixed Mount iPhone App

## Prerequisites
- iPhone running iOS 17+ (iPhone 13+ recommended for optimal ML performance)
- Stable mount for iPhone in controlled photo booth environment
- Good lighting conditions for car photography
- Camera permissions granted

## Basic Usage Flow

### 1. Start New Session
1. Launch Auto-Capture app
2. Enter vehicle stock number (alphanumeric, 3-20 characters)
3. Tap "Start Session" to begin capture process
4. App creates session folder: `Sessions/{stock}-{YYYYMMDD-HHmmss}/`

### 2. Position Vehicle
1. Position car in photo booth according to first viewpoint (FRONT_DRIVER_3RD)
2. Ensure vehicle is centered in framing guides
3. Wait for app to detect viewpoint with high confidence
4. Listen for voice prompt: "Front driver 3rd position detected"

### 3. Auto-Capture Process
1. App automatically captures photo when:
   - Correct viewpoint detected with ≥85% confidence
   - Detection remains stable for 5 consecutive frames
   - 0.5 second delay after stability confirmed
2. Hear capture confirmation beep
3. App advances to next viewpoint automatically
4. Repeat for all 8 viewpoints:
   - FRONT_DRIVER_3RD → FRONT → FRONT_PASSENGER_3RD → SIDE_PASSENGER → BACK_PASSENGER_3RD → BACK → BACK_DRIVER_3RD → SIDE_DRIVER

### 4. Manual Controls (if needed)
- **Manual Shutter**: Tap shutter button to capture immediately
- **Retake**: Tap retake button to recapture current viewpoint
- **Skip**: Tap skip button to move to next viewpoint (with confirmation)
- **Cancel Session**: Long press cancel to end session early

### 5. Review and Export
1. Review all 8 photos in grid layout
2. Tap any photo to retake if needed
3. Tap "Export" to create ZIP file
4. Share via Share Sheet (email, cloud storage, etc.)
5. Optional: Configure S3/WebDAV for direct upload

## Expected Session Timeline
- **Setup**: 30 seconds (position car, enter stock number)
- **Capture**: 3-5 minutes (8 photos × 30-45 seconds each)
- **Review**: 1-2 minutes (check photos, retake if needed)
- **Export**: 30 seconds (create ZIP, share)

## Success Indicators
- ✅ All 8 viewpoints captured automatically
- ✅ Photos saved with correct naming: `01_FRONT_DRIVER_3RD_20250127-143022.jpg`
- ✅ EXIF metadata includes stock number, viewpoint, session ID
- ✅ Session completed in ≤5 minutes
- ✅ No manual intervention required (except positioning)

## Common Issues and Solutions

### Low Confidence Detection
- **Symptom**: "Adjust position" banner appears
- **Solution**: Reposition vehicle to better match framing guides
- **Prevention**: Ensure good lighting and clean vehicle

### Thermal Throttling
- **Symptom**: Performance degrades during long sessions
- **Solution**: App automatically throttles inference to maintain stability
- **Prevention**: Ensure good ventilation around device

### Storage Full
- **Symptom**: "Storage full" error, new captures blocked
- **Solution**: Export existing sessions or free up device storage
- **Prevention**: Regular export of completed sessions

### Camera Permission Denied
- **Symptom**: Camera preview not available
- **Solution**: Go to Settings > Auto-Capture > Camera > Allow
- **Prevention**: Grant permissions during first launch

## Offline Operation
- All capture functionality works without internet
- Photos and metadata stored locally only
- Export creates ZIP file for sharing
- Optional cloud upload requires internet (configured separately)

## Performance Targets
- **Preview Frame Rate**: 30fps maintained on iPhone 13+
- **Inference Latency**: <150ms typical, <300ms maximum
- **Session Duration**: 8 photos in ≤5 minutes
- **Classification Accuracy**: ≥95% in controlled booth environment
- **Data Integrity**: Zero corrupted files across 1,000 captures

## Safety Guidelines
- Use only in controlled photo booth environment
- Ensure stable iPhone mount to prevent falls
- Maintain clear area around vehicle
- Follow voice prompts to minimize distraction
- Monitor device temperature during extended use
