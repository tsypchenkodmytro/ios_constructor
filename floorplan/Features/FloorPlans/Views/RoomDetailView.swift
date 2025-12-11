//
//  RoomDetailView.swift
//  floorplan
//
//  Room details with 3D model and floor plan
//

import SwiftUI
import RoomPlan

struct RoomDetailView: View {
    let room: SavedRoom
    @EnvironmentObject private var dataService: DataService
    @Environment(\.dismiss) private var dismiss
    @State private var showFloorPlan = false
    @State private var show3DModel = false
    @State private var showDeleteAlert = false
    
    private var modelURL: URL {
        dataService.documentsDirectory.appendingPathComponent("\(room.id).usdz")
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Icon
                ZStack {
                    Circle()
                        .fill(.blue.gradient)
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }
                .padding(.top, 20)
                
                // Room Info
                VStack(spacing: 8) {
                    Text(room.name)
                        .font(.title.bold())
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(room.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: { show3DModel = true }) {
                        HStack {
                            Image(systemName: "cube.fill")
                            Text("View 3D Model")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue.gradient)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button(action: { showFloorPlan = true }) {
                        HStack {
                            Image(systemName: "map")
                            Text("View 2D Floor Plan")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green.gradient)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
                
                // Room Statistics
                VStack(alignment: .leading, spacing: 12) {
                    Text("Room Statistics")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(icon: "square.split.2x2", value: "\(room.wallCount)", label: "Walls", color: .blue)
                        StatCard(icon: "door.left.hand.open", value: "\(room.doorCount)", label: "Doors", color: .green)
                        StatCard(icon: "rectangle.portrait", value: "\(room.windowCount)", label: "Windows", color: .cyan)
                        StatCard(icon: "cube.box", value: "\(room.objectCount)", label: "Objects", color: .orange)
                    }
                    .padding(.horizontal)
                }
                
                // File Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("File Information")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        InfoRow(label: "Format", value: "USDZ")
                        InfoRow(label: "Location", value: "Documents")
                        InfoRow(label: "ID", value: String(room.id.uuidString.prefix(8)) + "...")
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
                
                // Delete Button
                Button(action: { showDeleteAlert = true }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Room")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.red.opacity(0.1))
                    .foregroundColor(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                Spacer(minLength: 20)
            }
        }
        .navigationTitle("Room Details")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $show3DModel) {
            ModelViewer3D(url: modelURL, roomName: room.name)
        }
        .sheet(isPresented: $showFloorPlan) {
            NavigationView {
                if let roomStructure = dataService.loadRoomStructure(for: room) {
                    FloorPlanSpriteKitView(roomStructure: roomStructure, roomName: room.name)
                        .navigationTitle(room.name)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    showFloorPlan = false
                                }
                            }
                        }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        Text("Unable to load floor plan")
                            .font(.headline)
                        Text("The room data may not be available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showFloorPlan = false
                            }
                        }
                    }
                }
            }
            .preferredColorScheme(.light)
            .interactiveDismissDisabled()
        }
        .alert("Delete Room", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteRoom()
            }
        } message: {
            Text("Are you sure you want to delete '\(room.name)'? This action cannot be undone.")
        }
    }
    
    private func deleteRoom() {
        dataService.deleteRoom(room)
        dismiss()
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title.bold())
                .monospacedDigit()
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit())
        }
    }
}
