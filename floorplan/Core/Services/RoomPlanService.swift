//
//  RoomPlanService.swift
//  floorplan
//
//  Clean wrapper for Apple's RoomPlan framework with state machine
//

import RoomPlan
import SwiftUI
import Combine

// MARK: - Scan State Machine
enum ScanState: Equatable {
    case uninitialized
    case initializing
    case ready
    case scanning
    case processing
    case completed(CapturedRoom)
    case failed(Error)
    
    static func == (lhs: ScanState, rhs: ScanState) -> Bool {
        switch (lhs, rhs) {
        case (.uninitialized, .uninitialized),
             (.initializing, .initializing),
             (.ready, .ready),
             (.scanning, .scanning),
             (.processing, .processing):
            return true
        case (.completed, .completed),
             (.failed, .failed):
            return true
        default:
            return false
        }
    }
    
    var isScanning: Bool {
        if case .scanning = self { return true }
        return false
    }
    
    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }
    
    var capturedRoom: CapturedRoom? {
        if case .completed(let room) = self { return room }
        return nil
    }
    
    var error: Error? {
        if case .failed(let error) = self { return error }
        return nil
    }
}

// MARK: - RoomPlanService
@MainActor
class RoomPlanService: ObservableObject {
    @Published private(set) var state: ScanState = .uninitialized
    
    private(set) var captureView: RoomCaptureView?
    private var delegate: RoomCaptureDelegate?
    
    init() {
        print("🚀 RoomPlanService initialized")
    }
    
    deinit {
        print("🧹 RoomPlanService deinitialized")
        captureView?.captureSession.stop()
        captureView = nil
        delegate = nil
    }
    
    // MARK: - Public Methods
    
    func initialize() async throws {
        guard state == .uninitialized else {
            print("⚠️ Already initialized, current state: \(state)")
            return
        }
        
        state = .initializing
        print("🔧 Initializing RoomPlanService...")
        
        guard RoomCaptureSession.isSupported else {
            let error = RoomPlanError.deviceNotSupported
            state = .failed(error)
            throw error
        }
        
        // Create capture view
        let view = RoomCaptureView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let del = RoomCaptureDelegate(service: self)
        view.delegate = del
        
        self.captureView = view
        self.delegate = del
        
        state = .ready
        print("✅ RoomPlanService ready")
    }
    
    func startScanning() throws {
        guard case .ready = state else {
            print("❌ Cannot start scanning from state: \(state)")
            throw RoomPlanError.invalidState
        }
        
        guard let captureView = captureView else {
            throw RoomPlanError.initializationFailed
        }
        
        print("▶️ Starting scan...")
        state = .scanning
        
        let config = RoomCaptureSession.Configuration()
        captureView.captureSession.run(configuration: config)
        
        print("✅ Scanning started")
    }
    
    func stopScanning() {
        guard case .scanning = state else {
            print("⚠️ Not currently scanning, state: \(state)")
            return
        }
        
        print("⏹️ Stopping scan...")
        state = .processing
        
        captureView?.captureSession.stop()
    }
    
    func reset() {
        print("🔄 Resetting service...")
        
        // Stop scanning if active
        if case .scanning = state {
            captureView?.captureSession.stop()
        }
        
        // Return to ready state
        state = .ready
        print("✅ Service reset to ready state")
    }
    
    // MARK: - Internal Methods
    
    func handleScanCompletion(room: CapturedRoom) {
        print("✅ Scan completed successfully")
        state = .completed(room)
    }
    
    func handleScanError(_ error: Error) {
        print("❌ Scan failed: \(error.localizedDescription)")
        state = .failed(error)
    }
    
    private func cleanup() {
        captureView?.captureSession.stop()
        captureView = nil
        delegate = nil
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

// MARK: - Delegate Wrapper
@objc(FloorPlanRoomCaptureDelegate)
private final class RoomCaptureDelegate: NSObject, RoomCaptureViewDelegate, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }
    
    weak var service: RoomPlanService?
    
    init(service: RoomPlanService) {
        self.service = service
        super.init()
    }
    
    required init?(coder: NSCoder) {
        super.init()
    }
    
    func encode(with coder: NSCoder) {
        // No encoding needed - this is just a delegate
    }
    
    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        if let error = error {
            print("❌ RoomPlan processing error: \(error)")
            Task { @MainActor in
                self.service?.handleScanError(error)
            }
            return false
        }
        return true
    }
    
    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        Task { @MainActor in
            guard let service = self.service else { return }
            
            if let error = error {
                print("❌ RoomPlan presentation error: \(error)")
                service.handleScanError(error)
                return
            }
            
            print("✅ Room data received from RoomPlan")
            service.handleScanCompletion(room: processedResult)
        }
    }
    
    func captureView(didFailWithError error: Error) {
        print("❌ RoomPlan capture failed: \(error)")
        Task { @MainActor in
            self.service?.handleScanError(error)
        }
    }
}

