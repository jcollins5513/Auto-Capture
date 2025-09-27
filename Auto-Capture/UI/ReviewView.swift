import SwiftUI
import OSLog
import Combine
import UIKit

/// SwiftUI view for reviewing captured photos and exporting sessions
struct ReviewView: View {
    
    // MARK: - Properties
    
    let session: CaptureSession
    @StateObject private var viewModel: ReviewViewModel
    @Environment(\.dismiss) private var dismiss
    
    private let logger = Logger(subsystem: "AutoCapture", category: "ReviewView")
    
    // MARK: - Init
    
    init(
        session: CaptureSession,
        sessionStore: SessionStoreProtocol = SessionStore()
    ) {
        self.session = session
        let exporter = Exporter(sessionStore: sessionStore)
        _viewModel = StateObject(
            wrappedValue: ReviewViewModel(
                sessionStore: sessionStore,
                exporter: exporter
            )
        )
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Session info header
                sessionInfoHeader
                
                // Photos grid
                photosGrid
                
                // Export section
                exportSection
            }
            .navigationTitle("Review Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        Task {
                            await viewModel.exportSession()
                        }
                    }
                    .disabled(!viewModel.canExport)
                }
            }
            .alert("Export", isPresented: $viewModel.showingExportAlert) {
                Button("Share Sheet") {
                    Task {
                        await viewModel.exportToShareSheet()
                    }
                }
                Button("Files App") {
                    Task {
                        await viewModel.exportToFiles()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Choose export destination")
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
        .sheet(item: $viewModel.shareURL) { shareURL in
            ShareSheet(activityItems: [shareURL])
        }
        .alert(viewModel.successMessage ?? "", isPresented: Binding(
            get: { viewModel.successMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.successMessage = nil
                }
            }
        )) {
            Button("OK") { }
        }
        .onAppear {
            Task {
                await viewModel.setSession(session)
            }
        }
    }
    
    // MARK: - View Components
    
    private var sessionInfoHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Stock: \(session.stockNumber)")
                        .font(.headline)
                    
                    Text("Session: \(session.id.uuidString.prefix(8))...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(session.photos.count)/8 Photos")
                        .font(.headline)
                        .foregroundColor(session.isComplete ? .green : .orange)
                    
                    Text(session.status.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            if !session.isComplete {
                Text("Session incomplete - some viewpoints may be missing")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var photosGrid: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                ForEach(Viewpoint.allCases, id: \.self) { viewpoint in
                    photoCard(for: viewpoint)
                }
            }
            .padding()
        }
    }
    
    private func photoCard(for viewpoint: Viewpoint) -> some View {
        VStack(spacing: 8) {
            // Photo or placeholder
            if let photo = session.photo(for: viewpoint) {
                photoView(photo)
            } else {
                placeholderView(for: viewpoint)
            }
            
            // Viewpoint info
            VStack(spacing: 4) {
                Text(viewpoint.description)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                if let photo = session.photo(for: viewpoint) {
                    Text("\(Int(photo.confidence * 100))% confidence")
                        .font(.caption2)
                        .foregroundColor(confidenceColor(photo.confidence))
                } else {
                    Text("Not captured")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func photoView(_ photo: PhotoCapture) -> some View {
        AsyncImage(url: URL(fileURLWithPath: photo.filePath)) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .overlay(
                    ProgressView()
                        .scaleEffect(0.8)
                )
        }
        .frame(height: 120)
        .clipped()
        .cornerRadius(8)
        .overlay(
            // Confidence indicator
            VStack {
                HStack {
                    Spacer()
                    confidenceBadge(photo.confidence)
                }
                Spacer()
            }
            .padding(4)
        )
        .onTapGesture {
            // TODO: Show photo detail view
        }
    }
    
    private func placeholderView(for viewpoint: Viewpoint) -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(height: 120)
            .cornerRadius(8)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                    
                    Text("Not captured")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            )
    }
    
    private func confidenceBadge(_ confidence: Float) -> some View {
        Text("\(Int(confidence * 100))%")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(confidenceColor(confidence))
            .cornerRadius(4)
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
    
    private var exportSection: some View {
        VStack(spacing: 16) {
            Divider()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Export Session")
                        .font(.headline)
                    
                    Text("Create ZIP file with all photos")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    Task {
                        await viewModel.exportSession()
                    }
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(viewModel.canExport ? Color.blue : Color.gray)
                    .cornerRadius(8)
                }
                .disabled(!viewModel.canExport)
            }
            
            if viewModel.isExporting {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Exporting...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

// MARK: - ViewModel

@MainActor
class ReviewViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentSession: CaptureSession?
    @Published var isExporting = false
    @Published var showingExportAlert = false
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published var shareURL: URL?
    @Published var successMessage: String?
    
    // MARK: - Computed Properties
    
    var canExport: Bool {
        return currentSession?.isComplete == true && !isExporting
    }
    
    // MARK: - Methods
    
    private let sessionStore: SessionStoreProtocol
    private let exporter: Exporter
    private let logger = Logger(subsystem: "AutoCapture", category: "ReviewViewModel")

    init(sessionStore: SessionStoreProtocol, exporter: Exporter) {
        self.sessionStore = sessionStore
        self.exporter = exporter
    }

    func setSession(_ session: CaptureSession) async {
        currentSession = session

        do {
            if let stored = try await sessionStore.loadSession(id: session.id) {
                currentSession = stored
            }
        } catch {
            logger.error("Failed to load session: \(error.localizedDescription)")
        }
    }
    
    func exportSession() async {
        guard let session = currentSession else { return }
        
        do {
            isExporting = true
            let validation = try await exporter.validateExport(session)
            guard validation.isValid else {
                errorMessage = validation.issues.joined(separator: "\n")
                showingError = true
                isExporting = false
                return
            }
            showingExportAlert = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
        
        isExporting = false
    }
    
    func exportToShareSheet() async {
        guard let session = currentSession else { return }
        isExporting = true
        do {
            let result = try await exporter.exportSession(session, to: .shareSheet)
            shareURL = result.fileURL
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
        isExporting = false
    }
    
    func exportToFiles() async {
        guard let session = currentSession else { return }
        isExporting = true
        do {
            let result = try await exporter.exportSession(session, to: .files)
            if let url = result.fileURL {
                successMessage = "Exported to Files: \(url.lastPathComponent)"
            } else {
                successMessage = "Export complete."
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
        isExporting = false
    }
}

// MARK: - Preview

struct ReviewView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleSession = CaptureSession(
            stockNumber: "ABC123",
            settings: SessionSettings.default
        )
        
        ReviewView(session: sampleSession)
    }
}

// MARK: - Share Sheet Helper

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}
