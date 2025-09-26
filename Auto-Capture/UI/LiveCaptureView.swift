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
        CameraPreviewView()
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
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        // TODO: Integrate with CaptureSessionController
        // This would typically involve:
        // 1. Getting the preview layer from CaptureSessionController
        // 2. Adding it to the view
        // 3. Setting up the preview layer
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update preview if needed
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
    
    // MARK: - Computed Properties
    
    var canCapture: Bool {
        return !isLoading && currentSession != nil
    }
    
    var canRetake: Bool {
        return !isLoading && currentSession != nil
    }
    
    var canSkip: Bool {
        return !isLoading && currentSession != nil
    }
    
    // MARK: - Methods
    
    func startCapture() async {
        isLoading = true
        
        do {
            // TODO: Implement capture start logic
            // This would typically involve:
            // 1. Starting the camera session
            // 2. Starting the ML classification
            // 3. Setting up the state machine
            
            logger.info("Starting live capture")
            
            // Simulate initialization
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Set initial viewpoint
            currentViewpoint = .frontDriver3rd
            isDetecting = true
            
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
        
        isLoading = false
    }
    
    func stopCapture() async {
        // TODO: Implement capture stop logic
        logger.info("Stopping live capture")
    }
    
    func capturePhoto() async {
        guard canCapture else { return }
        
        do {
            // TODO: Implement photo capture
            logger.info("Capturing photo")
            
            // Simulate capture
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            completedPhotos += 1
            
            // Move to next viewpoint
            if let nextViewpoint = currentViewpoint?.next {
                currentViewpoint = nextViewpoint
            } else {
                // Session complete
                currentViewpoint = nil
            }
            
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    func retakePhoto() async {
        guard canRetake else { return }
        
        do {
            // TODO: Implement photo retake
            logger.info("Retaking photo")
            
            // Simulate retake
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    func skipViewpoint() async {
        guard canSkip else { return }
        
        // TODO: Implement viewpoint skip
        logger.info("Skipping viewpoint")
        
        // Move to next viewpoint
        if let nextViewpoint = currentViewpoint?.next {
            currentViewpoint = nextViewpoint
        } else {
            // Session complete
            currentViewpoint = nil
        }
    }
    
    func cancelSession() async {
        // TODO: Implement session cancellation
        logger.info("Cancelling session")
    }
    
    private let logger = Logger(subsystem: "AutoCapture", category: "LiveCaptureViewModel")
}

// MARK: - Preview

struct LiveCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        LiveCaptureView()
    }
}
