// ViewpointClassifierProtocol.swift - API Contract
// Core ML integration for viewpoint classification

import Vision
import CoreML
import Foundation

protocol ViewpointClassifierProtocol {
    // Model management
    func loadModel() async throws
    var isModelLoaded: Bool { get }
    
    // Classification
    func classify(image: CVPixelBuffer) async throws -> ClassificationResult
    func classify(image: CGImage) async throws -> ClassificationResult
    
    // Performance
    var averageInferenceTime: TimeInterval { get }
    var modelSize: Int64 { get }
    var modelVersion: String { get }
}

struct ClassificationResult {
    let viewpoint: Viewpoint
    let confidence: Float
    let inferenceTime: TimeInterval
    let allConfidences: [Viewpoint: Float]
}

enum ViewpointClassificationError: Error {
    case modelNotLoaded
    case inferenceFailed
    case imageProcessingFailed
    case lowConfidence(confidence: Float)
}

// Implementation requirements:
// - Must use Core ML with Vision framework
// - Must return one of 8 standard viewpoints
// - Must provide confidence scores for all viewpoints
// - Must achieve <150ms typical inference time
// - Must handle model loading and error states
// - Must support CVPixelBuffer and CGImage input formats
// - Must be thread-safe for concurrent classification
// - Model size must be ≤50MB
