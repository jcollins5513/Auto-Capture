import SwiftUI
import AVFoundation
import OSLog
import Combine

/// SwiftUI view for live capture with camera preview and ML classification
struct LiveCaptureView: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel = LiveCaptureViewModel()
    @State private var showingReview = false
    @State private var showingSettings = false
    
    private let logger = Logger(subsystem: "AutoCapture", category: "LiveCaptureView")
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Camera preview
            cameraPreviewSection
            
            // Overlay UI
            overlaySection
            
            // Loading indicator
            if viewModel.isLoading {
                loadingSection
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            Task {
                await viewModel.startCapture()
            }
        }
        .onDisappear {
            Task {
                await viewModel.stopCapture()
            }
        }
        .sheet(isPresented: $showingReview) {
            if let session = viewModel.currentSession {
                ReviewView(session: session)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    // MARK: - View Components
    
    private var cameraPreviewSection: some View {
        CameraPreviewView(previewLayer: viewModel.previewLayer)
            .ignoresSafeArea()
    }
    
    private var overlaySection: some View {
        VStack {
            // Top section
            topSection
            
            Spacer()
            
            // Center section
            centerSection
            
            Spacer()
            
            // Bottom section
            bottomSection
        }
    }
    
    private var topSection: some View {
        HStack {
            // Back button
            Button(action: {
                Task {
                    await viewModel.cancelSession()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Session info
            VStack(alignment: .trailing) {
                Text("Stock: \(viewModel.stockNumber)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(viewModel.completedPhotos)/8 Photos")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
            .background(Color.black.opacity(0.5))
            .cornerRadius(12)
            
            Spacer()
            
            // Settings button
            Button(action: {
                showingSettings = true
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
        }
        .padding()
    }
    
    private var centerSection: some View {
        VStack(spacing: 16) {
            // Current viewpoint
            if let currentViewpoint = viewModel.currentViewpoint {
                viewpointSection(currentViewpoint)
            }
            
            // Classification result
            if let classificationResult = viewModel.classificationResult {
                classificationSection(classificationResult)
            }
            
            // Stability indicator
            if viewModel.isDetecting {
                stabilitySection
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private var bottomSection: some View {
        HStack(spacing: 20) {
            // Manual capture button
            Button(action: {
                Task {
                    await viewModel.capturePhoto()
                }
            }) {
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
            }
            .disabled(!viewModel.canCapture)
            
            // Retake button
            Button(action: {
                Task {
                    await viewModel.retakePhoto()
                }
            }) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
            .disabled(!viewModel.canRetake)
            
            // Skip button
            Button(action: {
                Task {
                    await viewModel.skipViewpoint()
                }
            }) {
                Image(systemName: "forward.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
            .disabled(!viewModel.canSkip)
        }
        .padding()
        .background(Color.black.opacity(0.5))
        .cornerRadius(20)
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            
            Text("Initializing...")
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.8))
    }
    
    // MARK: - Helper Views
    
    private func viewpointSection(_ viewpoint: Viewpoint) -> some View {
        VStack(spacing: 8) {
            Text("Current Viewpoint")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            
            Text(viewpoint.description)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(viewpoint.framingGuide)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }
    
    private func classificationSection(_ result: ClassificationResult) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Detected:")
                Spacer()
                Text(result.viewpoint.description)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            
            HStack {
                Text("Confidence:")
                Spacer()
                Text("\(Int(result.confidence * 100))%")
                    .fontWeight(.semibold)
                    .foregroundColor(confidenceColor(result.confidence))
            }
            .foregroundColor(.white)
            
            if result.confidence < 0.85 {
                Text("Adjust position for better detection")
                    .font(.caption)
                    .foregroundColor(.yellow)
            }
        }
    }
    
    private var stabilitySection: some View {
        VStack(spacing: 8) {
            Text("Stability Check")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            
            ProgressView(value: viewModel.stabilityProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .green))
            
            Text("\(Int(viewModel.stabilityProgress * 100))%")
                .font(.caption)
                .foregroundColor(.white)
        }
    }
    
    private func confidenceColor(_ confidence: Float) -> Color {
        if confidence >= 0.9 {
            return .green
        } else if confidence >= 0.7 {
            return .yellow
        } else {
            return .red
        }
    }
}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer?

    func makeUIView(context: Context) -> CameraPreviewContainerView {
        let view = CameraPreviewContainerView()
        view.backgroundColor = .black
        view.updatePreviewLayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewContainerView, context: Context) {
        uiView.updatePreviewLayer(previewLayer)
    }

    static func dismantleUIView(_ uiView: CameraPreviewContainerView, coordinator: ()) {
        uiView.updatePreviewLayer(nil)
    }
}

final class CameraPreviewContainerView: UIView {
    private var activePreviewLayer: AVCaptureVideoPreviewLayer?

    func updatePreviewLayer(_ layer: AVCaptureVideoPreviewLayer?) {
        guard activePreviewLayer !== layer else { return }

        activePreviewLayer?.removeFromSuperlayer()
        activePreviewLayer = layer

        guard let layer else { return }

        layer.frame = bounds
        layer.videoGravity = .resizeAspectFill
        self.layer.addSublayer(layer)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        activePreviewLayer?.frame = bounds
    }
}

// MARK: - ViewModel

@MainActor
class LiveCaptureViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var currentSession: CaptureSession?
    @Published var currentViewpoint: Viewpoint?
    @Published var classificationResult: ClassificationResult?
    @Published var isDetecting = false
    @Published var isLoading = false
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published var stockNumber = ""
    @Published var completedPhotos = 0
    @Published var stabilityProgress: Float = 0.0
    @Published var previewLayer: AVCaptureVideoPreviewLayer?

    // MARK: - Private Properties

    private let captureSessionController: CaptureSessionController
    private let sessionStore: SessionStoreProtocol
    private let settingsStore: SessionSettingsStoreProtocol
    private let viewpointClassifier: ViewpointClassifierProtocol
    private let stabilityGate: StabilityGate
    private let photoCaptureManager: PhotoCaptureManager
    private let stateMachine: CaptureStateMachineProtocol
    private var sessionSettings: SessionSettings
    private var classificationTask: Task<Void, Never>?

    private let logger = Logger(subsystem: "AutoCapture", category: "LiveCaptureViewModel")

    // MARK: - Initialization

    init(
        captureSessionController: CaptureSessionController = CaptureSessionController(),
        sessionStore: SessionStoreProtocol = SessionStore(),
        settingsStore: SessionSettingsStoreProtocol? = nil,
        viewpointClassifier: ViewpointClassifierProtocol = ViewpointClassifier(),
        stabilityGate: StabilityGate = StabilityGate()
    ) {
        self.captureSessionController = captureSessionController
        self.sessionStore = sessionStore
        let resolvedSettingsStore = settingsStore ?? SessionSettingsStore()
        self.settingsStore = resolvedSettingsStore
        self.viewpointClassifier = viewpointClassifier
        self.stabilityGate = stabilityGate
        self.sessionSettings = resolvedSettingsStore.loadSettings()
        self.photoCaptureManager = PhotoCaptureManager(
            captureSessionController: captureSessionController,
            sessionStore: sessionStore
        )
        self.stateMachine = CaptureStateMachine(
            stabilityGate: stabilityGate,
            viewpointClassifier: viewpointClassifier,
            photoCaptureManager: photoCaptureManager,
            sessionStore: sessionStore
        )
        self.previewLayer = captureSessionController.getVideoPreviewLayer()

        bindCallbacks()
    }

    deinit {
        classificationTask?.cancel()
    }

    // MARK: - Computed Properties

    var canCapture: Bool {
        !isLoading && stateMachine.canCapture()
    }

    var canRetake: Bool {
        !isLoading && stateMachine.canRetake()
    }

    var canSkip: Bool {
        !isLoading && stateMachine.canSkip()
    }

    // MARK: - Capture Lifecycle

    func startCapture() async {
        guard !isLoading else { return }
        let trimmedStockNumber = stockNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedStockNumber.isEmpty else {
            presentError("Enter a stock number to begin.")
            return
        }

        stockNumber = trimmedStockNumber

        isLoading = true
        defer { isLoading = false }

        do {
            sessionSettings = settingsStore.loadSettings()
            let permissionGranted = await captureSessionController.requestCameraPermission()
            guard permissionGranted else {
                presentError("Camera permission is required. Enable access in Settings.")
                return
            }

            try await captureSessionController.configureSession()
            try await captureSessionController.startSession()

            if !viewpointClassifier.isModelLoaded {
                try await viewpointClassifier.loadModel()
            }

            stabilityGate.reset()
            stabilityGate.updateConfiguration(
                requiredStabilityFrames: sessionSettings.stabilityFrames,
                confidenceThreshold: sessionSettings.confidenceThreshold
            )

            try await stateMachine.startSession(stockNumber: trimmedStockNumber, settings: sessionSettings)

            syncSessionState()
            updateProgress(stateMachine.sessionProgress)
            isDetecting = true

            startClassificationLoopIfNeeded()

        } catch {
            logger.error("Failed to start capture: \(error.localizedDescription)")
            presentError("Unable to start capture. \(error.localizedDescription)")
        }
    }

    func stopCapture() async {
        classificationTask?.cancel()
        classificationTask = nil

        do {
            try await captureSessionController.stopSession()
        } catch {
            logger.error("Failed to stop capture: \(error.localizedDescription)")
        }
    }

    func capturePhoto() async {
        guard canCapture else { return }

        do {
            let photo = try await stateMachine.capturePhoto()
            logger.info("Captured photo: \(photo.viewpoint.rawValue)")
            syncSessionState()
        } catch {
            logger.error("Capture failed: \(error.localizedDescription)")
            presentError("Capture failed. \(error.localizedDescription)")
        }
    }

    func retakePhoto() async {
        guard let viewpoint = currentViewpoint, canRetake else { return }

        do {
            try await stateMachine.retakePhoto(for: viewpoint)
            syncSessionState()
        } catch {
            logger.error("Retake failed: \(error.localizedDescription)")
            presentError("Retake failed. \(error.localizedDescription)")
        }
    }

    func skipViewpoint() async {
        guard let viewpoint = currentViewpoint, canSkip else { return }

        do {
            try await stateMachine.skipViewpoint(viewpoint)
            syncSessionState()
        } catch {
            logger.error("Skip failed: \(error.localizedDescription)")
            presentError("Skip failed. \(error.localizedDescription)")
        }
    }

    func cancelSession() async {
        classificationTask?.cancel()
        classificationTask = nil

        do {
            try await stateMachine.cancelSession()
            try await captureSessionController.stopSession()
        } catch {
            logger.error("Cancel session failed: \(error.localizedDescription)")
        }

        resetSessionState()
    }

    // MARK: - Private Helpers

    private func bindCallbacks() {
        stateMachine.onStateChange = { [weak self] state in
            guard let self else { return }
            Task { @MainActor in
                self.handleStateChange(state)
            }
        }

        stateMachine.onProgressUpdate = { [weak self] progress in
            guard let self else { return }
            Task { @MainActor in
                self.updateProgress(progress)
            }
        }

        stateMachine.onError = { [weak self] error in
            guard let self else { return }
            Task { @MainActor in
                self.logger.error("State machine error: \(error.localizedDescription)")
                self.presentError(error.localizedDescription)
            }
        }

        captureSessionController.onError = { [weak self] error in
            guard let self else { return }
            Task { @MainActor in
                self.logger.error("Camera error: \(error.localizedDescription)")
                self.presentError(error.localizedDescription)
            }
        }

        sessionStore.onStorageFull = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.presentError("Storage is full. Free up space to continue capturing.")
            }
        }

        sessionStore.onStorageError = { [weak self] storageError in
            guard let self else { return }
            Task { @MainActor in
                self.presentError(storageError.localizedDescription)
            }
        }
    }

    private func handleStateChange(_ state: CaptureState) {
        switch state {
        case .detecting, .stable, .sessionActive:
            isDetecting = true
        case .capturing, .retaking:
            isDetecting = false
        case .completed:
            isDetecting = false
            syncSessionState()
        case .idle, .cancelled:
            isDetecting = false
        case .error(let error):
            isDetecting = false
            presentError(error.localizedDescription)
        }
    }

    private func updateProgress(_ progress: SessionProgress) {
        completedPhotos = progress.completedViewpoints.count
        currentViewpoint = progress.currentViewpoint ?? stateMachine.currentViewpoint
        stabilityProgress = currentViewpoint.flatMap { stabilityGate.getStabilityProgress(for: $0) } ?? 0.0
        syncSessionState()
    }

    private func syncSessionState() {
        currentSession = stateMachine.currentSession
        currentViewpoint = stateMachine.currentViewpoint
    }

    private func resetSessionState() {
        currentSession = nil
        currentViewpoint = nil
        classificationResult = nil
        completedPhotos = 0
        stabilityProgress = 0.0
        isDetecting = false
        stockNumber = ""
        stabilityGate.reset()
    }

    private func presentError(_ message: String) {
        errorMessage = message
        showingError = true
    }

    private func startClassificationLoopIfNeeded() {
        guard classificationTask == nil else { return }
        classificationTask = Task { [weak self] in
            guard let self else { return }
            await self.runClassificationLoop()
        }
    }

    private func runClassificationLoop() async {
        // Classification loop will be implemented when video data output is wired.
        logger.debug("Classification loop not yet implemented")
        classificationTask = nil
    }
}

// MARK: - Preview

struct LiveCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        LiveCaptureView()
    }
}
