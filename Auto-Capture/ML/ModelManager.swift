import Foundation
import CoreML
import OSLog
import UniformTypeIdentifiers

/// Manages Core ML model loading and integration
final class ModelManager {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "AutoCapture", category: "ModelManager")
    private var _model: MLModel?
    private var _isModelLoaded = false
    private var _modelInfo: ModelInfo?
    
    // MARK: - Computed Properties
    
    var isModelLoaded: Bool {
        return _isModelLoaded
    }
    
    var model: MLModel? {
        return _model
    }
    
    var modelInfo: ModelInfo? {
        return _modelInfo
    }
    
    // MARK: - Model Loading
    
    func loadModel() async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                do {
                    try self?.loadModelInternal()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func loadModelInternal() throws {
        // Try to load model from app bundle
        guard let modelURL = Bundle.main.url(forResource: "ViewpointClassifier", withExtension: "mlmodelc") else {
            throw ModelError.modelNotFound
        }
        
        // Load the model
        let model = try MLModel(contentsOf: modelURL)
        _model = model
        
        // Get model metadata
        let modelInfo = createModelInfo(from: model, url: modelURL)
        _modelInfo = modelInfo
        
        _isModelLoaded = true
        logger.info("Model loaded successfully: \(modelInfo.version)")
    }
    
    private func createModelInfo(from model: MLModel, url: URL) -> ModelInfo {
        let name = url.lastPathComponent
        let version = model.modelDescription.metadata[MLModelMetadataKey(rawValue: "version")] as? String ?? "1.0.0"
        
        // Get model size
        let modelSize: Int64
        do {
            let modelData = try Data(contentsOf: url)
            modelSize = Int64(modelData.count)
        } catch {
            modelSize = 0
        }
        
        // Get model description
        let description = model.modelDescription.metadata[.description] as? String ?? "Viewpoint classification model"
        
        // Get input/output descriptions
        let inputDescriptions = model.modelDescription.inputDescriptionsByName
        let outputDescriptions = model.modelDescription.outputDescriptionsByName
        
        return ModelInfo(
            version: version,
            size: modelSize,
            isLoaded: true,
            averageInferenceTime: 0.0,
            lastInferenceTime: 0.0
        )
    }
    
    // MARK: - Model Validation
    
    func validateModel() async throws -> ModelValidation {
        guard let model = _model else {
            throw ModelError.modelNotLoaded
        }
        
        // Check model size
        let sizeValidation = validateModelSize()
        
        // Check model structure
        let structureValidation = validateModelStructure(model)
        
        // Check model performance
        let performanceValidation = try await validateModelPerformance(model)
        
        return ModelValidation(
            isValid: sizeValidation.isValid && structureValidation.isValid && performanceValidation.isValid,
            sizeValidation: sizeValidation,
            structureValidation: structureValidation,
            performanceValidation: performanceValidation
        )
    }
    
    private func validateModelSize() -> ValidationResult {
        guard let modelInfo = _modelInfo else {
            return ValidationResult(isValid: false, message: "Model info not available")
        }
        
        let maxSize: Int64 = 50 * 1024 * 1024 // 50MB
        let isValid = modelInfo.size <= maxSize
        
        return ValidationResult(
            isValid: isValid,
            message: isValid ? "Model size is acceptable" : "Model size exceeds 50MB limit"
        )
    }
    
    private func validateModelStructure(_ model: MLModel) -> ValidationResult {
        let inputDescriptions = model.modelDescription.inputDescriptionsByName
        let outputDescriptions = model.modelDescription.outputDescriptionsByName
        
        // Check for required inputs
        guard inputDescriptions["image"] != nil else {
            return ValidationResult(isValid: false, message: "Missing required input: image")
        }
        
        // Check for required outputs
        guard outputDescriptions["classLabel"] != nil else {
            return ValidationResult(isValid: false, message: "Missing required output: classLabel")
        }
        
        guard outputDescriptions["classLabelProbs"] != nil else {
            return ValidationResult(isValid: false, message: "Missing required output: classLabelProbs")
        }
        
        return ValidationResult(isValid: true, message: "Model structure is valid")
    }
    
    private func validateModelPerformance(_ model: MLModel) async throws -> ValidationResult {
        // Create a test input
        let testInput = createTestInput()
        
        // Measure inference time
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            let prediction = try await model.prediction(from: testInput)
            let inferenceTime = CFAbsoluteTimeGetCurrent() - startTime
            
            // Check if inference time is acceptable (<300ms)
            let isValid = inferenceTime < 0.3
            
            return ValidationResult(
                isValid: isValid,
                message: isValid ? "Model performance is acceptable" : "Model inference time exceeds 300ms"
            )
        } catch {
            return ValidationResult(isValid: false, message: "Model inference failed: \(error.localizedDescription)")
        }
    }
    
    private func createTestInput() -> MLFeatureProvider {
        // Create a test image feature
        let testImage = createTestImage()
        let imageFeature = MLFeatureValue(pixelBuffer: testImage)
        
        let inputName = "image"
        let inputFeatures = [inputName: imageFeature]
        
        return try! MLDictionaryFeatureProvider(dictionary: inputFeatures)
    }
    
    private func createTestImage() -> CVPixelBuffer {
        // Create a test pixel buffer
        let width = 224
        let height = 224
        let bytesPerPixel = 4
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            fatalError("Failed to create test pixel buffer")
        }
        
        return buffer
    }
    
    // MARK: - Model Information
    
    func getModelStatistics() -> ModelStatistics {
        guard let modelInfo = _modelInfo else {
            return ModelStatistics(
                name: "Unknown",
                version: "Unknown",
                size: 0,
                isLoaded: false,
                loadTime: 0.0
            )
        }
        
        return ModelStatistics(
            name: modelInfo.version,
            version: modelInfo.version,
            size: modelInfo.size,
            isLoaded: _isModelLoaded,
            loadTime: 0.0 // TODO: Track load time
        )
    }
    
    func getModelCapabilities() -> ModelCapabilities {
        guard let model = _model else {
            return ModelCapabilities(
                supportsImageInput: false,
                supportsPixelBufferInput: false,
                maxInputSize: CGSize.zero,
                supportedImageTypes: []
            )
        }
        
        let inputDescriptions = model.modelDescription.inputDescriptionsByName
        
        return ModelCapabilities(
            supportsImageInput: inputDescriptions["image"] != nil,
            supportsPixelBufferInput: inputDescriptions["image"] != nil,
            maxInputSize: CGSize(width: 224, height: 224), // Standard input size
            supportedImageTypes: [UTType.jpeg, UTType.png]
        )
    }
    
    // MARK: - Model Management
    
    func unloadModel() {
        _model = nil
        _isModelLoaded = false
        _modelInfo = nil
        logger.info("Model unloaded")
    }
    
    func reloadModel() async throws {
        unloadModel()
        try await loadModel()
    }
    
    // MARK: - Model Updates
    
    func checkForModelUpdates() async throws -> ModelUpdateInfo? {
        // TODO: Implement model update checking
        // This would typically involve:
        // 1. Checking for updates from a server
        // 2. Comparing versions
        // 3. Downloading new models if available
        
        return nil
    }
    
    func updateModel(to newModelURL: URL) async throws {
        // TODO: Implement model updating
        // This would typically involve:
        // 1. Downloading the new model
        // 2. Validating the new model
        // 3. Replacing the old model
        // 4. Reloading the model
        
        logger.info("Model update requested")
    }
}

// MARK: - Supporting Types


struct ModelValidation {
    let isValid: Bool
    let sizeValidation: ValidationResult
    let structureValidation: ValidationResult
    let performanceValidation: ValidationResult
}

struct ValidationResult {
    let isValid: Bool
    let message: String
}

struct ModelStatistics {
    let name: String
    let version: String
    let size: Int64
    let isLoaded: Bool
    let loadTime: TimeInterval
}

struct ModelCapabilities {
    let supportsImageInput: Bool
    let supportsPixelBufferInput: Bool
    let maxInputSize: CGSize
    let supportedImageTypes: [UTType]
}

struct ModelUpdateInfo {
    let available: Bool
    let currentVersion: String
    let latestVersion: String
    let downloadURL: URL?
    let releaseNotes: String?
}

// MARK: - ModelError

enum ModelError: Error, LocalizedError {
    case modelNotFound
    case modelNotLoaded
    case modelLoadFailed
    case modelValidationFailed
    case modelUpdateFailed
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "Model not found in app bundle"
        case .modelNotLoaded:
            return "Model not loaded"
        case .modelLoadFailed:
            return "Failed to load model"
        case .modelValidationFailed:
            return "Model validation failed"
        case .modelUpdateFailed:
            return "Model update failed"
        }
    }
}

// MARK: - ModelManager Extensions

extension ModelManager {
    
    /// Gets the model size as a human-readable string
    func getModelSizeString() -> String {
        guard let modelInfo = _modelInfo else {
            return "Unknown"
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: modelInfo.size)
    }
    
    /// Gets the model version as a string
    func getModelVersionString() -> String {
        return _modelInfo?.version ?? "Unknown"
    }
    
    /// Gets the model name as a string
    func getModelNameString() -> String {
        return _modelInfo?.version ?? "Unknown"
    }
    
    /// Checks if the model is ready for use
    func isModelReady() -> Bool {
        return _isModelLoaded && _model != nil
    }
    
    /// Gets the model status description
    func getModelStatusDescription() -> String {
        if _isModelLoaded {
            return "Model loaded and ready"
        } else {
            return "Model not loaded"
        }
    }
}
