//
//  RoomScanView.swift
//  floorplan
//
//  Clean scan view with state machine and view model
//

import SwiftUI
import RoomPlan
import CoreData

struct RoomScanView: View {
    @StateObject private var service = RoomPlanService()
    @StateObject private var viewModel: ScanViewModel
    @State private var showErrorAlert = false
    @State private var saveSuccess = false
    
    init() {
        let service = RoomPlanService()
        _service = StateObject(wrappedValue: service)
        _viewModel = StateObject(wrappedValue: ScanViewModel(service: service))
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Camera View
            cameraView
            
            // Loading Overlay
            if case .initializing = service.state {
                loadingOverlay
            }
            
            // Gradient Overlay
            VStack {
                LinearGradient(
                    colors: [.black.opacity(0.3), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .ignoresSafeArea()
                Spacer()
            }
            
            // UI Overlays
            VStack(spacing: 12) {
                // Status Indicators
                if viewModel.isScanning {
                    scanningStatusView
                }
                
                // Tips Button
                if viewModel.isReady {
                    tipsButton
                }
                
                Spacer()
                
                // Control Panel
                controlPanel
                    .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $viewModel.showSaveSheet) {
            if let room = viewModel.capturedRoom {
                SaveRoomSheet(room: room, onSaveSuccess: $saveSuccess)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $viewModel.showTips) {
            ScanningTipsSheet()
        }
        .alert("Scanning Error", isPresented: $showErrorAlert) {
            Button("OK") {
                viewModel.reset()
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "An unknown error occurred")
        }
        .onChange(of: service.state) { _, newState in
            if case .failed = newState {
                showErrorAlert = true
            }
        }
        .onChange(of: saveSuccess) { _, success in
            if success {
                viewModel.reset()
                viewModel.showSaveSheet = false
                saveSuccess = false
            }
        }
        .task {
            await viewModel.initialize()
        }
        .onAppear {
            // Prevent screen from sleeping during scanning
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            // Re-enable screen timeout when leaving scan screen
            UIApplication.shared.isIdleTimerDisabled = false
            viewModel.cleanup()
        }
    }
    
    // MARK: - Subviews
    
    private var cameraView: some View {
        Group {
            if let captureView = service.captureView {
                RoomCaptureViewRepresentable(captureView: captureView)
                    .ignoresSafeArea()
            } else {
                cameraPlaceholder
            }
        }
    }
    
    private var cameraPlaceholder: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.6))
            
            Text("Camera Initializing...")
                .font(.headline)
                .foregroundColor(.white)
            
            if let error = viewModel.error {
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("Initializing 3D Scanner...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
    }
    
    private var scanningStatusView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(.red.opacity(0.5), lineWidth: 4)
                            .scaleEffect(1.5)
                            .opacity(0.8)
                    )
                
                Text("Scanning...")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            }
            
            // Scan timer
            if viewModel.scanDuration > 0 {
                Text(viewModel.formatDuration(viewModel.scanDuration))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Quality indicator
            HStack(spacing: 4) {
                Image(systemName: viewModel.scanQuality.icon)
                    .font(.caption2)
                    .foregroundColor(viewModel.scanQuality.color)
                Text(viewModel.scanQuality.text)
                    .font(.caption2)
                    .foregroundColor(viewModel.scanQuality.color)
            }
            
            // Stuck indicator
            if viewModel.isStuck {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text("Try moving around the room")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.top, 60)
    }
    
    private var tipsButton: some View {
        Button(action: { viewModel.showTips = true }) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb")
                Text("Scanning Tips")
            }
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.blue.opacity(0.8))
            .clipShape(Capsule())
        }
        .padding(.top, 60)
    }
    
    private var controlPanel: some View {
        HStack(spacing: 16) {
            // Flashlight toggle (when ready)
            if viewModel.isReady {
                Button(action: { viewModel.toggleFlashlight() }) {
                    ZStack {
                        Circle()
                            .fill(viewModel.isFlashlightOn ? Color.yellow : Color.gray)
                            .frame(width: 50, height: 50)
                            .shadow(color: (viewModel.isFlashlightOn ? Color.yellow : Color.gray).opacity(0.4), radius: 8)
                        
                        Image(systemName: viewModel.isFlashlightOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
            }
            
            // Restart button (when stuck)
            if viewModel.isStuck {
                Button(action: { viewModel.restartScanning() }) {
                    ZStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 50, height: 50)
                            .shadow(color: Color.orange.opacity(0.4), radius: 8)
                        
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
            }
            
            // Main scan button
            Button(action: {
                if viewModel.isScanning {
                    viewModel.stopScanning()
                } else {
                    // If there's a completed scan, reset first
                    if viewModel.capturedRoom != nil {
                        viewModel.reset()
                    }
                    viewModel.startScanning()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(viewModel.isScanning ? Color.red : Color.blue)
                        .frame(width: 70, height: 70)
                        .shadow(color: (viewModel.isScanning ? Color.red : Color.blue).opacity(0.4), radius: 10)
                    
                    Image(systemName: viewModel.isScanning ? "stop.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .disabled(!viewModel.isReady && !viewModel.isScanning && viewModel.capturedRoom == nil)
            
            // Save button (when scan is completed)
            if viewModel.capturedRoom != nil && !viewModel.isScanning {
                Button(action: {
                    viewModel.showSaveSheet = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Save")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(.green)
                    .clipShape(Capsule())
                    .shadow(color: .green.opacity(0.4), radius: 10)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isScanning)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isStuck)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.capturedRoom != nil)
    }
}

// MARK: - UIViewRepresentable Wrapper
struct RoomCaptureViewRepresentable: UIViewRepresentable {
    let captureView: RoomCaptureView
    
    func makeUIView(context: Context) -> RoomCaptureView {
        print("🎥 Presenting RoomCaptureView")
        return captureView
    }
    
    func updateUIView(_ uiView: RoomCaptureView, context: Context) {
        // No manual updates needed
    }
    
    static func dismantleUIView(_ uiView: RoomCaptureView, coordinator: ()) {
        print("🧹 Dismantling RoomCaptureView")
    }
}

// MARK: - Save Sheet
struct SaveRoomSheet: View {
    let room: CapturedRoom
    @Binding var onSaveSuccess: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var roomName = ""
    @State private var isSaving = false
    @State private var saveError: Error?
    @State private var showSaveError = false
    
    @EnvironmentObject private var dataService: DataService
    
    private var wallCount: Int { room.walls.count }
    private var doorCount: Int { room.doors.count }
    private var windowCount: Int { room.windows.count }
    private var objectCount: Int { room.objects.count }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header icon
                ZStack {
                    Circle()
                        .fill(.blue.gradient)
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
                .padding(.top, 20)
                
                // Room name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Room Name")
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)
                    
                    TextField("e.g., Living Room, Kitchen", text: $roomName)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .submitLabel(.done)
                }
                .padding(.horizontal)
                
                // Stats cards
                HStack(spacing: 12) {
                    QuickStatCard(icon: "square.split.2x2", value: "\(wallCount)", color: .blue)
                    QuickStatCard(icon: "door.left.hand.open", value: "\(doorCount)", color: .green)
                    QuickStatCard(icon: "rectangle.portrait", value: "\(windowCount)", color: .cyan)
                    QuickStatCard(icon: "cube.box", value: "\(objectCount)", color: .orange)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Scan Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveRoom()
                    } label: {
                        if isSaving {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Saving...")
                            }
                        } else {
                            Text("Save")
                        }
                    }
                    .bold()
                    .disabled(roomName.isEmpty || isSaving)
                }
            }
        }
        .alert("Save Error", isPresented: $showSaveError) {
            Button("OK") {
                showSaveError = false
            }
        } message: {
            Text(saveError?.localizedDescription ?? "Failed to save room")
        }
    }
    
    private func saveRoom() {
        guard !roomName.isEmpty else { return }
        
        isSaving = true
        
        Task {
            do {
                try await dataService.save(room, named: roomName)
                print("✅ Room saved successfully: \(roomName)")
                
                await MainActor.run {
                    isSaving = false
                    onSaveSuccess = true
                    dismiss()
                }
            } catch {
                print("❌ Failed to save room: \(error)")
                
                await MainActor.run {
                    saveError = error
                    showSaveError = true
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Quick Stat Card
struct QuickStatCard: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Scanning Tips Sheet
struct ScanningTipsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.yellow.gradient)
                        
                        Text("Scanning Tips")
                            .font(.title.bold())
                        
                        Text("Follow these tips for the best scanning results")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 10)
                    
                    // Tips
                    VStack(alignment: .leading, spacing: 16) {
                        TipRow(
                            icon: "figure.walk",
                            title: "Move Slowly",
                            description: "Walk around the room slowly and steadily. Quick movements can reduce scan quality."
                        )
                        
                        TipRow(
                            icon: "lightbulb",
                            title: "Good Lighting",
                            description: "Ensure the room is well-lit. Use the flashlight button if needed for dark areas."
                        )
                        
                        TipRow(
                            icon: "arrow.up.and.down.and.arrow.left.and.right",
                            title: "Cover All Areas",
                            description: "Point your device at walls, corners, doors, and windows. Don't miss any surfaces."
                        )
                        
                        TipRow(
                            icon: "clock",
                            title: "Take Your Time",
                            description: "Spend 30-60 seconds scanning for best results. Quality over speed!"
                        )
                        
                        TipRow(
                            icon: "eye",
                            title: "Stay Focused",
                            description: "Keep the camera view clear and avoid covering the LiDAR sensor."
                        )
                        
                        TipRow(
                            icon: "checkmark.circle",
                            title: "Complete Coverage",
                            description: "Make sure to scan from different heights and angles for complete room capture."
                        )
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Tips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Tip Row
struct TipRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    RoomScanView()
        .environmentObject(DataService(context: PersistenceController.shared.container.viewContext))
}
