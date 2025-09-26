import Vision
import CoreML
import Foundation
import OSLog

/// Core ML integration for viewpoint classification
final class ViewpointClassifier: ViewpointClassifierProtocol {
    
    // MARK: - Properties
    
    private var model: MLModel?
    private var visionRequest: VNCoreMLRequest?
    private let logger = Logger(subsystem: "AutoCapture", category: "ViewpointClassifier")
    
    private var _isModelLoaded = false
    private var _averageInferenceTime: TimeInterval = 0.0
    private var _lastInferenceTime: TimeInterval = 0.0
    private var _modelSize: Int64 = 0
    private var _modelVersion: String = "1.0.0"
    
    private var inferenceTimes: [TimeInterval] = []
    private let maxInferenceTimes = 100 // Keep last 100 inference times for average
    
    var isModelLoaded: Bool {
        return _isModelLoaded
    }
    
    var averageInferenceTime: TimeInterval {
        return _averageInferenceTime
    }
    
    var lastInferenceTime: TimeInterval {
        return _lastInferenceTime
    }
    
    var modelSize: Int64 {
        return _modelSize
    }
    
    var modelVersion: String {
        return _modelVersion
    }
    
    // MARK: - Model Management
    
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
            throw ViewpointClassificationError.modelNotLoaded
        }
        
        // Load the model
        let model = try MLModel(contentsOf: modelURL)
        self.model = model
        
        // Get model metadata
        let modelDescription = model.modelDescription
        _modelVersion = modelDescription.metadata[MLModelMetadataKey(rawValue: "version")] as? String ?? "1.0.0"
        
        // Get model size
        do {
            let modelData = try Data(contentsOf: modelURL)
            _modelSize = Int64(modelData.count)
        } catch {
            logger.warning("Could not determine model size: \(error.localizedDescription)")
        }
        
        // Create Vision request
        let visionModel = try VNCoreMLModel(for: model)
        visionRequest = VNCoreMLRequest(model: visionModel) { [weak self] request, error in
            if let error = error {
                self?.logger.error("Vision request failed: \(error.localizedDescription)")
            }
        }
        
        visionRequest?.imageCropAndScaleOption = .scaleFill
        
        _isModelLoaded = true
        logger.info("Viewpoint classifier model loaded successfully")
    }
    
    // MARK: - Classification
    
    func classify(image: CVPixelBuffer) async throws -> ClassificationResult {
        guard isModelLoaded, let visionRequest = visionRequest else {
            throw ViewpointClassificationError.modelNotLoaded
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        return try await withCheckedThrowingContinuation { continuation in
            let handler = VNImageRequestHandler(cvPixelBuffer: image, options: [:])
            
            do {
                try handler.perform([visionRequest])
                
                guard let results = visionRequest.results as? [VNClassificationObservation],
                      let topResult = results.first else {
                    continuation.resume(throwing: ViewpointClassificationError.inferenceFailed)
                    return
                }
                
                let inferenceTime = CFAbsoluteTimeGetCurrent() - startTime
                self.updateInferenceTime(inferenceTime)
                
                let classificationResult = self.createClassificationResult(
                    from: results,
                    inferenceTime: inferenceTime
                )
                
                continuation.resume(returning: classificationResult)
                
            } catch {
                continuation.resume(throwing: ViewpointClassificationError.inferenceFailed)
            }
        }
    }
    
    func classify(image: CGImage) async throws -> ClassificationResult {
        guard isModelLoaded, let visionRequest = visionRequest else {
            throw ViewpointClassificationError.modelNotLoaded
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        return try await withCheckedThrowingContinuation { continuation in
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            
            do {
                try handler.perform([visionRequest])
                
                guard let results = visionRequest.results as? [VNClassificationObservation],
                      let topResult = results.first else {
                    continuation.resume(throwing: ViewpointClassificationError.inferenceFailed)
                    return
                }
                
                let inferenceTime = CFAbsoluteTimeGetCurrent() - startTime
                self.updateInferenceTime(inferenceTime)
                
                let classificationResult = self.createClassificationResult(
                    from: results,
                    inferenceTime: inferenceTime
                )
                
                continuation.resume(returning: classificationResult)
                
            } catch {
                continuation.resume(throwing: ViewpointClassificationError.inferenceFailed)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createClassificationResult(
        from results: [VNClassificationObservation],
        inferenceTime: TimeInterval
    ) -> ClassificationResult {
        // Create confidence dictionary for all viewpoints
        var allConfidences: [Viewpoint: Float] = [:]
        
        for viewpoint in Viewpoint.allCases {
            allConfidences[viewpoint] = 0.0
        }
        
        // Map results to viewpoints
        for result in results {
            if let viewpoint = Viewpoint(rawValue: result.identifier) {
                allConfidences[viewpoint] = result.confidence
            }
        }
        
        // Find the highest confidence viewpoint
        let topViewpoint = allConfidences.max { $0.value < $1.value }?.key ?? .front
        let topConfidence = allConfidences[topViewpoint] ?? 0.0
        
        return ClassificationResult(
            viewpoint: topViewpoint,
            confidence: topConfidence,
            inferenceTime: inferenceTime,
            allConfidences: allConfidences
        )
    }
    
    private func updateInferenceTime(_ time: TimeInterval) {
        _lastInferenceTime = time
        
        // Add to inference times array
        inferenceTimes.append(time)
        
        // Keep only the last maxInferenceTimes
        if inferenceTimes.count > maxInferenceTimes {
            inferenceTimes.removeFirst()
        }
        
        // Calculate average
        _averageInferenceTime = inferenceTimes.reduce(0, +) / Double(inferenceTimes.count)
        
        logger.debug("Inference time: \(String(format: "%.3f", time))s, Average: \(String(format: "%.3f", self._averageInferenceTime))s")
    }
    
    // MARK: - Model Information
    
    func getModelInfo() -> ModelInfo {
        return ModelInfo(
            version: modelVersion,
            size: modelSize,
            isLoaded: isModelLoaded,
            averageInferenceTime: averageInferenceTime,
            lastInferenceTime: lastInferenceTime
        )
    }
    
    func getPerformanceMetrics() -> PerformanceMetrics {
        return PerformanceMetrics(
            averageInferenceTime: averageInferenceTime,
            lastInferenceTime: lastInferenceTime,
            totalInferences: inferenceTimes.count,
            minInferenceTime: inferenceTimes.min() ?? 0.0,
            maxInferenceTime: inferenceTimes.max() ?? 0.0
        )
    }
    
    // MARK: - Model Validation
    
    func validateModel() -> Bool {
        guard isModelLoaded else { return false }
        
        // Check if model size is reasonable (≤50MB)
        if modelSize > 50 * 1024 * 1024 {
            logger.warning("Model size exceeds 50MB: \(self.modelSize) bytes")
            return false
        }
        
        // Check if average inference time is reasonable (<300ms)
        if averageInferenceTime > 0.3 {
            logger.warning("Average inference time exceeds 300ms: \(self.averageInferenceTime)s")
            return false
        }
        
        return true
    }
    
    // MARK: - Cleanup
    
    deinit {
        model = nil
        visionRequest = nil
    }
}

// MARK: - Supporting Types

struct ModelInfo {
    let version: String
    let size: Int64
    let isLoaded: Bool
    let averageInferenceTime: TimeInterval
    let lastInferenceTime: TimeInterval
}

struct PerformanceMetrics {
    let averageInferenceTime: TimeInterval
    let lastInferenceTime: TimeInterval
    let totalInferences: Int
    let minInferenceTime: TimeInterval
    let maxInferenceTime: TimeInterval
}

// MARK: - ViewpointClassificationError Extension

extension ViewpointClassificationError {
    var localizedDescription: String {
        switch self {
        case .modelNotLoaded:
            return "Model not loaded"
        case .inferenceFailed:
            return "Inference failed"
        case .imageProcessingFailed:
            return "Image processing failed"
        case .lowConfidence(let confidence):
            return "Low confidence: \(String(format: "%.1f%%", confidence * 100))"
        }
    }
}
