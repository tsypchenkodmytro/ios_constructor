//
//  ScanViewModel.swift
//  floorplan
//
//  Simplified view model following Apple's patterns
//

import SwiftUI
import RoomPlan
import AVFoundation
import Combine

@MainActor
class ScanViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var showSaveSheet = false
    @Published var showTips = false
    @Published var isFlashlightOn = false
    
    // MARK: - Private Properties
    private let service: RoomPlanService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var isScanning: Bool {
        service.isScanning
    }
    
    var capturedRoom: CapturedRoom? {
        service.capturedRoom
    }
    
    var error: Error? {
        service.error
    }
    
    // MARK: - Initialization
    init(service: RoomPlanService) {
        self.service = service
    }
    
    deinit {
        print("🧹 ScanViewModel deinitialized")
        // Cleanup synchronously without MainActor
        
        // Turn off flashlight (safe to call even if already off)
        if let device = AVCaptureDevice.default(for: .video), device.hasTorch {
            try? device.lockForConfiguration()
            device.torchMode = .off
            device.unlockForConfiguration()
        }
        
        // Clear subscriptions
        cancellables.removeAll()
    }
    
    // MARK: - Public Methods
    func startScanning() {
        service.startSession()
    }
    
    func stopScanning() {
        service.stopSession()
    }
    
    func reset() {
        service.reset()
    }
    
    func toggleFlashlight() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
            print("⚠️ Flashlight not available")
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            if device.torchMode == .on {
                device.torchMode = .off
                isFlashlightOn = false
            } else {
                try device.setTorchModeOn(level: 1.0)
                isFlashlightOn = true
            }
            
            device.unlockForConfiguration()
        } catch {
            print("❌ Flashlight error: \(error)")
        }
    }
    
    // MARK: - Cleanup
    func cleanup() {
        print("🧹 Cleaning up ScanViewModel...")
        
        // Turn off flashlight
        if isFlashlightOn {
            if let device = AVCaptureDevice.default(for: .video), device.hasTorch {
                try? device.lockForConfiguration()
                device.torchMode = .off
                device.unlockForConfiguration()
                isFlashlightOn = false
            }
        }
        
        // Stop scanning
        service.stopSession()
        
        // Clear subscriptions
        cancellables.removeAll()
        
        print("✅ ScanViewModel cleanup complete")
    }
}
