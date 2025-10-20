//
//  ScanViewModel.swift
//  floorplan
//
//  View model for scan screen with clean state management
//

import SwiftUI
import RoomPlan
import AVFoundation
import Combine

@MainActor
class ScanViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var scanDuration: TimeInterval = 0
    @Published var scanQuality: ScanQuality = .unknown
    @Published var isFlashlightOn = false
    @Published var showSaveSheet = false
    @Published var showTips = false
    
    // MARK: - Private Properties
    private let service: RoomPlanService
    private var scanStartTime: Date?
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var isScanning: Bool {
        service.state.isScanning
    }
    
    var isReady: Bool {
        service.state.isReady
    }
    
    var capturedRoom: CapturedRoom? {
        service.state.capturedRoom
    }
    
    var error: Error? {
        service.state.error
    }
    
    var wallCount: Int {
        capturedRoom?.walls.count ?? 0
    }
    
    var doorCount: Int {
        capturedRoom?.doors.count ?? 0
    }
    
    var windowCount: Int {
        capturedRoom?.windows.count ?? 0
    }
    
    var hasStructures: Bool {
        wallCount > 0 || doorCount > 0 || windowCount > 0
    }
    
    var isStuck: Bool {
        guard isScanning, scanDuration > 30 else { return false }
        return !hasStructures && scanDuration > 45
    }
    
    // MARK: - Initialization
    init(service: RoomPlanService) {
        self.service = service
        setupObservers()
    }
    
    deinit {
        print("🧹 ScanViewModel deinitialized")
        timer?.invalidate()
        timer = nil
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        // Observe state changes
        service.$state
            .sink { [weak self] state in
                self?.handleStateChange(state)
            }
            .store(in: &cancellables)
    }
    
    private func handleStateChange(_ state: ScanState) {
        switch state {
        case .scanning:
            // Scanning started - begin timer
            if scanStartTime == nil {
                startTimer()
            }
        case .processing, .completed, .failed:
            // Scanning stopped - stop timer
            stopTimer()
        default:
            break
        }
    }
    
    // MARK: - Public Methods
    func initialize() async {
        do {
            try await service.initialize()
        } catch {
            print("❌ Failed to initialize: \(error)")
        }
    }
    
    func startScanning() {
        do {
            try service.startScanning()
            scanStartTime = Date()
            scanQuality = .starting
        } catch {
            print("❌ Failed to start scanning: \(error)")
        }
    }
    
    func stopScanning() {
        service.stopScanning()
    }
    
    func restartScanning() {
        service.reset()
        scanDuration = 0
        scanQuality = .unknown
        
        // Small delay before restarting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.startScanning()
        }
    }
    
    func reset() {
        service.reset()
        scanDuration = 0
        scanQuality = .unknown
        scanStartTime = nil
    }
    
    func toggleFlashlight() {
        Task {
            guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
            
            do {
                try device.lockForConfiguration()
                
                if isFlashlightOn {
                    device.torchMode = .off
                } else {
                    try device.setTorchModeOn(level: 1.0)
                }
                
                device.unlockForConfiguration()
                isFlashlightOn.toggle()
            } catch {
                print("❌ Flashlight error: \(error)")
            }
        }
    }
    
    // MARK: - Timer Management
    private func startTimer() {
        scanStartTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateScanMetrics()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateScanMetrics() {
        guard let startTime = scanStartTime else { return }
        
        scanDuration = Date().timeIntervalSince(startTime)
        scanQuality = calculateQuality()
    }
    
    private func calculateQuality() -> ScanQuality {
        let duration = scanDuration
        let hasData = hasStructures
        
        switch duration {
        case 0..<10:
            return .starting
        case 10..<30:
            return hasData ? .good : .struggling
        case 30..<60:
            return hasData ? .excellent : .struggling
        default:
            return hasData ? .thorough : .struggling
        }
    }
    
    // MARK: - Cleanup
    func cleanup() {
        stopTimer()
        if isFlashlightOn {
            toggleFlashlight()
        }
        cancellables.removeAll()
    }
    
    // MARK: - Formatting
    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Scan Quality Enum
enum ScanQuality {
    case unknown, starting, good, excellent, thorough, struggling
    
    var text: String {
        switch self {
        case .unknown: return "Ready"
        case .starting: return "Starting..."
        case .good: return "Good Coverage"
        case .excellent: return "Excellent!"
        case .thorough: return "Very Thorough"
        case .struggling: return "Having Trouble"
        }
    }
    
    var icon: String {
        switch self {
        case .unknown: return "circle"
        case .starting: return "arrow.clockwise"
        case .good: return "checkmark.circle"
        case .excellent: return "checkmark.circle.fill"
        case .thorough: return "star.circle.fill"
        case .struggling: return "exclamationmark.triangle"
        }
    }
    
    var color: Color {
        switch self {
        case .unknown: return .gray
        case .starting: return .orange
        case .good: return .yellow
        case .excellent: return .green
        case .thorough: return .blue
        case .struggling: return .red
        }
    }
}

