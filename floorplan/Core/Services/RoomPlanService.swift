//
//  RoomPlanService.swift
//  floorplan
//
//  Standard Apple RoomPlan implementation following official patterns
//

import RoomPlan
import SwiftUI
import Combine

// MARK: - RoomPlanService
@MainActor
class RoomPlanService: ObservableObject {
    @Published var capturedRoom: CapturedRoom?
    @Published var error: Error?
    @Published var errorId: UUID?
    @Published var isScanning = false
    @Published var isInitialized = false
    @Published var sessionId = UUID()
    
    private var roomCaptureView: RoomCaptureView?
    private var captureDelegate: RoomCaptureSessionDelegate?
    private var sessionConfig = RoomCaptureSession.Configuration()
    
    init() {
        print("🚀 RoomPlanService initialized")
        // Check if RoomPlan is supported and mark as initialized
        Task { @MainActor in
            if RoomCaptureSession.isSupported {
                isInitialized = true
                print("✅ RoomPlan ready")
            } else {
                error = RoomPlanError.deviceNotSupported
                errorId = UUID()
                print("❌ RoomPlan not supported")
            }
        }
    }
    
    deinit {
        print("🧹 RoomPlanService deinitialized")
        // Stop session synchronously without MainActor
        roomCaptureView?.captureSession.stop()
    }
    
    // MARK: - Public Methods
    
    func startSession() {
        guard RoomCaptureSession.isSupported else {
            error = RoomPlanError.deviceNotSupported
            return
        }
        
        // Always create a fresh capture view for each session
        let captureView = RoomCaptureView(frame: .zero)
        let delegate = RoomCaptureSessionDelegate(service: self)
        captureView.delegate = delegate
        roomCaptureView = captureView
        captureDelegate = delegate
        
        // Generate new session ID to trigger view update
        sessionId = UUID()
        
        // Start the session
        captureView.captureSession.run(configuration: sessionConfig)
        isScanning = true
        capturedRoom = nil
        error = nil
        errorId = nil
        print("▶️ RoomPlan session started with fresh capture view (ID: \(sessionId))")
    }
    
    func stopSession() {
        guard let captureView = roomCaptureView else { return }
        captureView.captureSession.stop()
        isScanning = false
        print("⏹️ RoomPlan session stopped")
    }
    
    func getCaptureView() -> RoomCaptureView? {
        return roomCaptureView
    }
    
    func reset() {
        stopSession()
        
        // Clear everything for fresh start (but keep initialized state)
        roomCaptureView = nil
        captureDelegate = nil
        capturedRoom = nil
        error = nil
        errorId = nil
        
        print("🔄 RoomPlanService reset - ready for fresh start")
    }
    
    // MARK: - Internal Methods
    
    func handleCapturedRoom(_ room: CapturedRoom) {
        capturedRoom = room
        isScanning = false
    }
    
    func handleError(_ error: Error) {
        self.error = error
        self.errorId = UUID()
        
        // Don't stop scanning for tracking errors - they're often temporary
        let errorDescription = error.localizedDescription.lowercased()
        if !errorDescription.contains("tracking") {
            isScanning = false
        }
    }
}

// MARK: - Delegate Class
@objc(FloorPlanRoomCaptureSessionDelegate)
private class RoomCaptureSessionDelegate: NSObject, RoomCaptureViewDelegate, NSCoding {
    weak var service: RoomPlanService?
    
    init(service: RoomPlanService) {
        self.service = service
        super.init()
    }
    
    // MARK: - NSCoding
    required init?(coder: NSCoder) {
        super.init()
    }
    
    func encode(with coder: NSCoder) {
        // No encoding needed for delegate
    }
    
    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        if let error = error {
            print("❌ Processing error: \(error.localizedDescription)")
            Task { @MainActor in
                self.service?.handleError(error)
            }
            return false
        }
        return true
    }
    
    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        if let error = error {
            print("❌ Presentation error: \(error.localizedDescription)")
            Task { @MainActor in
                self.service?.handleError(error)
            }
            return
        }
        
        print("✅ Room captured successfully")
        Task { @MainActor in
            self.service?.handleCapturedRoom(processedResult)
        }
    }
    
    func captureView(didFailWithError error: Error) {
        print("❌ Capture failed: \(error.localizedDescription)")
        Task { @MainActor in
            self.service?.handleError(error)
        }
    }
}

// MARK: - Custom Errors
enum RoomPlanError: LocalizedError {
    case deviceNotSupported
    case initializationFailed
    case cameraPermissionDenied
    case invalidState
    
    var errorDescription: String? {
        switch self {
        case .deviceNotSupported:
            return "This device doesn't support RoomPlan. A LiDAR-enabled device is required."
        case .initializationFailed:
            return "Failed to initialize room scanning. Please try again."
        case .cameraPermissionDenied:
            return "Camera access is required for room scanning. Please enable camera access in Settings."
        case .invalidState:
            return "Cannot perform this action in the current state."
        }
    }
}
