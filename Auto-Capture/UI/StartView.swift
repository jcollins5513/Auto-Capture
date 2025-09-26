import SwiftUI
import OSLog
import Combine

/// SwiftUI view for starting a new capture session
struct StartView: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel = StartViewModel()
    @State private var showingSettings = false
    @State private var showingSessionHistory = false
    
    private let logger = Logger(subsystem: "AutoCapture", category: "StartView")
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Stock number input
                stockNumberSection
                
                // Settings preview
                settingsPreviewSection
                
                // Action buttons
                actionButtonsSection
                
                Spacer()
            }
            .padding()
            .navigationTitle("Auto-Capture")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Settings") {
                        showingSettings = true
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("History") {
                        showingSessionHistory = true
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingSessionHistory) {
                SessionHistoryView()
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Auto-Capture")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Automatically capture 8 standard car angles")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var stockNumberSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vehicle Stock Number")
                .font(.headline)
            
            TextField("Enter stock number", text: $viewModel.stockNumber)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.allCharacters)
                .disableAutocorrection(true)
                .onChange(of: viewModel.stockNumber) { _, newValue in
                    viewModel.validateStockNumber(newValue)
                }
            
            if !viewModel.stockNumberError.isEmpty {
                Text(viewModel.stockNumberError)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    private var settingsPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Settings")
                .font(.headline)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Confidence Threshold:")
                    Spacer()
                    Text("\(Int(viewModel.settings.confidenceThreshold * 100))%")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Stability Frames:")
                    Spacer()
                    Text("\(viewModel.settings.stabilityFrames)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("JPEG Quality:")
                    Spacer()
                    Text("\(Int(viewModel.settings.jpegQuality * 100))%")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Voice Prompts:")
                    Spacer()
                    Text(viewModel.settings.voicePrompts ? "On" : "Off")
                        .foregroundColor(.secondary)
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                Task {
                    await viewModel.startSession()
                }
            }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Start Session")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.canStartSession ? Color.blue : Color.gray)
                .cornerRadius(12)
            }
            .disabled(!viewModel.canStartSession)
            
            Button(action: {
                showingSettings = true
            }) {
                HStack {
                    Image(systemName: "gearshape.fill")
                    Text("Configure Settings")
                }
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
class StartViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var stockNumber = ""
    @Published var stockNumberError = ""
    @Published var settings = SessionSettings.default
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published var isLoading = false
    
    // MARK: - Computed Properties
    
    var canStartSession: Bool {
        return !stockNumber.isEmpty && stockNumberError.isEmpty && !isLoading
    }
    
    // MARK: - Methods
    
    func validateStockNumber(_ stockNumber: String) {
        if stockNumber.isEmpty {
            stockNumberError = ""
            return
        }
        
        let pattern = "^[A-Za-z0-9]{3,20}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: stockNumber.utf16.count)
        let isValid = regex?.firstMatch(in: stockNumber, options: [], range: range) != nil
        
        if isValid {
            stockNumberError = ""
        } else {
            stockNumberError = "Stock number must be 3-20 alphanumeric characters"
        }
    }
    
    func startSession() async {
        guard canStartSession else { return }
        
        isLoading = true
        
        do {
            // TODO: Implement session start logic
            // This would typically involve:
            // 1. Creating a new session
            // 2. Navigating to LiveCaptureView
            // 3. Starting the capture process
            
            logger.info("Starting session for stock number: \(self.stockNumber)")
            
            // Simulate session start
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // TODO: Navigate to LiveCaptureView
            
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
        
        isLoading = false
    }
    
    private let logger = Logger(subsystem: "AutoCapture", category: "StartViewModel")
}

// MARK: - Supporting Views

struct SessionHistoryView: View {
    @State private var sessions: [CaptureSession] = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(sessions) { session in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stock: \(session.stockNumber)")
                        .font(.headline)
                    
                    Text("Status: \(session.status.description)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Photos: \(session.photos.count)/8")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Session History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadSessions()
        }
    }
    
    private func loadSessions() {
        // TODO: Load sessions from SessionStore
        sessions = []
    }
}

// MARK: - Preview

struct StartView_Previews: PreviewProvider {
    static var previews: some View {
        StartView()
    }
}
