//
//  SettingsView.swift
//  Auto-Capture
//
//  Created by Justin Collins on 9/25/25.
//

import Combine
import OSLog
import SwiftUI

/// SwiftUI view for configuring session settings
struct SettingsView: View {
    // MARK: - Properties

    @StateObject private var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    private let logger = Logger(subsystem: "AutoCapture", category: "SettingsView")
    
    // MARK: - Init

    init(settingsStore: SessionSettingsStoreProtocol? = nil) {
        let resolvedStore = settingsStore ?? SessionSettingsStore()
        _viewModel = StateObject(wrappedValue: SettingsViewModel(settingsStore: resolvedStore))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                // Capture Settings Section
                captureSettingsSection
                
                // ML Settings Section
                mlSettingsSection
                
                // UI Settings Section
                uiSettingsSection
                
                // Export Settings Section
                exportSettingsSection
                
                // Advanced Settings Section
                advancedSettingsSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.saveSettings()
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.hasChanges)
                }
            }
            .alert(
                "Error",
                isPresented: $viewModel.showingError,
                actions: {
                    Button("OK", role: .cancel) { }
                },
                message: {
                    Text(viewModel.errorMessage)
                }
            )
        }
        .onAppear {
            viewModel.loadSettings()
        }
    }
    
    // MARK: - View Sections
    
    private var captureSettingsSection: some View {
        Section("Capture Settings") {
            stabilityFramesControl
            shutterDelayControl
            jpegQualityControl
            exposureLockToggle
        }
    }

    private var stabilityFramesControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Stability Frames")
                Spacer()
                Text("\(viewModel.settings.stabilityFrames)")
                    .foregroundColor(.secondary)
            }

            Slider(
                value: Binding<Double>(
                    get: { Double(viewModel.settings.stabilityFrames) },
                    set: { viewModel.updateStabilityFrames(Int($0.rounded())) }
                ),
                in: 1...20,
                step: 1
            )

            Text(viewModel.settings.stabilityFramesDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var shutterDelayControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Shutter Delay")
                Spacer()
                Text(viewModel.settings.shutterDelayString)
                    .foregroundColor(.secondary)
            }

            Slider(
                value: Binding<Double>(
                    get: { viewModel.settings.shutterDelay },
                    set: { viewModel.updateShutterDelay($0) }
                ),
                in: 0.1...5.0,
                step: 0.1
            )

            Text("Delay before capture after stability confirmed")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var jpegQualityControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("JPEG Quality")
                Spacer()
                Text(viewModel.settings.jpegQualityString)
                    .foregroundColor(.secondary)
            }

            Slider(
                value: Binding<Double>(
                    get: { Double(viewModel.settings.jpegQuality) },
                    set: { viewModel.updateJpegQuality(Float($0)) }
                ),
                in: 0.1...1.0,
                step: 0.05
            )

            Text(viewModel.settings.jpegQualityDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var exposureLockToggle: some View {
        Toggle("Lock Exposure", isOn: Binding<Bool>(
            get: { viewModel.settings.lockExposure },
            set: { viewModel.updateLockExposure($0) }
        ))
    }
    
    private var mlSettingsSection: some View {
        Section("ML Settings") {
            // Confidence Threshold
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Confidence Threshold")
                    Spacer()
                    Text(viewModel.settings.confidenceThresholdString)
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: Binding<Double>(
                        get: { Double(viewModel.settings.confidenceThreshold) },
                        set: { viewModel.updateConfidenceThreshold(Float($0)) }
                    ),
                    in: 0.5...1.0,
                    step: 0.05
                )
                
                Text(viewModel.settings.confidenceThresholdDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var uiSettingsSection: some View {
        Section("UI Settings") {
            // Guide Opacity
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Guide Opacity")
                    Spacer()
                    Text(viewModel.settings.guideOpacityString)
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: Binding<Double>(
                        get: { Double(viewModel.settings.guideOpacity) },
                        set: { viewModel.updateGuideOpacity(Float($0)) }
                    ),
                    in: 0.0...1.0,
                    step: 0.1
                )
                
                Text(viewModel.settings.guideOpacityDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Voice Prompts
            Toggle("Voice Prompts", isOn: Binding(
                get: { viewModel.settings.voicePrompts },
                set: { viewModel.updateVoicePrompts($0) }
            ))
        }
    }
    
    private var exportSettingsSection: some View {
        Section("Export Settings") {
            // Export Target
            Picker(
                "Export Target",
                selection: Binding<ExportTarget>(
                    get: { viewModel.settings.exportTarget },
                    set: { viewModel.updateExportTarget($0) }
                )
            ) {
                ForEach(ExportTarget.allCases, id: \.self) { target in
                    HStack {
                        Image(systemName: target.iconName)
                        Text(target.description)
                    }
                    .tag(target)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }
    
    private var advancedSettingsSection: some View {
        Section("Advanced Settings") {
            // Thermal Threshold
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Thermal Threshold")
                    Spacer()
                    Text(viewModel.settings.thermalThresholdDescription)
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: Binding<Double>(
                        get: { Double(viewModel.settings.thermalThreshold) },
                        set: { viewModel.updateThermalThreshold(Float($0)) }
                    ),
                    in: 0.0...1.0,
                    step: 0.1
                )
                
                Text("Device temperature threshold for performance throttling")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Reset to Defaults
            Button("Reset to Defaults") {
                viewModel.resetToDefaults()
            }
            .foregroundColor(.red)
        }
    }
}

// MARK: - ViewModel

@MainActor
class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var settings: SessionSettings
    @Published var originalSettings: SessionSettings
    @Published var showingError = false
    @Published var errorMessage = ""
    
    private let settingsStore: SessionSettingsStoreProtocol
    
    // MARK: - Computed Properties

    var hasChanges: Bool { settings != originalSettings }

    // MARK: - Methods

    init(settingsStore: SessionSettingsStoreProtocol? = nil) {
        let resolvedStore = settingsStore ?? SessionSettingsStore()
        self.settingsStore = resolvedStore
        let stored = resolvedStore.loadSettings()
        self.settings = stored
        self.originalSettings = stored
        logger.info("SettingsViewModel initialized with stored settings")
    }

    func loadSettings() {
        let stored = settingsStore.loadSettings()
        settings = stored
        originalSettings = stored
        logger.info("Settings loaded")
    }

    func saveSettings() async {
        do {
            try settingsStore.saveSettings(settings)
            logger.info("Settings saved")
            originalSettings = settings
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    func resetToDefaults() {
        settings = SessionSettings.default
    }
    
    // MARK: - Update Methods
    
    func updateStabilityFrames(_ value: Int) {
        settings = settings.updating(stabilityFrames: value)
    }
    
    func updateConfidenceThreshold(_ value: Float) {
        settings = settings.updating(confidenceThreshold: value)
    }
    
    func updateShutterDelay(_ value: TimeInterval) {
        settings = settings.updating(shutterDelay: value)
    }
    
    func updateLockExposure(_ value: Bool) {
        settings = settings.updating(lockExposure: value)
    }
    
    func updateJpegQuality(_ value: Float) {
        settings = settings.updating(jpegQuality: value)
    }
    
    func updateGuideOpacity(_ value: Float) {
        settings = settings.updating(guideOpacity: value)
    }
    
    func updateVoicePrompts(_ value: Bool) {
        settings = settings.updating(voicePrompts: value)
    }
    
    func updateExportTarget(_ value: ExportTarget) {
        settings = settings.updating(exportTarget: value)
    }
    
    func updateThermalThreshold(_ value: Float) {
        settings = settings.updating(thermalThreshold: value)
    }
    
    private let logger = Logger(subsystem: "AutoCapture", category: "SettingsViewModel")
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
