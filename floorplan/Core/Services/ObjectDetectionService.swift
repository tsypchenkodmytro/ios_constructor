//
//  ObjectDetectionService.swift
//  floorplan
//
//  Object detection using Vision + CoreML for custom equipment
//

import Vision
import CoreML
import ARKit
import Combine

/// Detects custom equipment using Vision + CoreML
@MainActor
class ObjectDetectionService: ObservableObject {
    @Published var detectedObjects: [DetectedObject] = []
    @Published var isProcessing = false
    
    private var visionModel: VNCoreMLModel?
    private var currentRequest: VNCoreMLRequest?
    
    /// Load your CoreML model
    func loadModel(named modelName: String) throws {
        // TODO: Replace with your actual CoreML model
        // let model = try YOLOv8(configuration: MLModelConfiguration())
        // visionModel = try VNCoreMLModel(for: model.model)
        // setupVisionRequest()
        
        print("📦 Ready to load CoreML model: \(modelName)")
    }
    
    private func setupVisionRequest() {
        guard let model = visionModel else { return }
        
        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            self?.handleDetection(request: request, error: error)
        }
        request.imageCropAndScaleOption = .scaleFill
        currentRequest = request
    }
    
    /// Detect objects in ARFrame
    func detectObjects(in frame: ARFrame) async {
        guard let request = currentRequest else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let handler = VNImageRequestHandler(
            cvPixelBuffer: frame.capturedImage,
            orientation: .up
        )
        
        try? handler.perform([request])
    }
    
    private func handleDetection(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNRecognizedObjectObservation] else { return }
        
        Task { @MainActor in
            self.detectedObjects = results.map { observation in
                DetectedObject(
                    type: observation.labels.first?.identifier ?? "unknown",
                    confidence: observation.confidence,
                    boundingBox: observation.boundingBox
                )
            }
        }
    }
}

// MARK: - Detected Object Model
struct DetectedObject: Identifiable {
    let id = UUID()
    let type: String
    let confidence: Float
    let boundingBox: CGRect
}
