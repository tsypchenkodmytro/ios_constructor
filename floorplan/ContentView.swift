//
//  ContentView.swift
//  floorplan
//
//  Main app navigation - Modern UI
//

import SwiftUI
import RoomPlan

struct ContentView: View {
    @StateObject private var dataService = DataService()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Saved Rooms
            RoomListView()
                .tabItem {
                    Label("Rooms", systemImage: "square.stack.3d.up.fill")
                }
                .tag(0)
            
            // Scan (uses Apple's RoomPlan)
            if supportsRoomPlan {
                RoomScanView()
                    .tabItem {
                        Label("Scan", systemImage: "viewfinder.circle.fill")
                    }
                    .tag(1)
            } else {
                UnsupportedView()
                    .tabItem {
                        Label("Scan", systemImage: "exclamationmark.triangle.fill")
                    }
                    .tag(1)
            }
            
            // Settings
            SettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle.fill")
                }
                .tag(2)
        }
        .accentColor(.blue)
        .environmentObject(dataService)
        .preferredColorScheme(.dark)
    }
    
    private var supportsRoomPlan: Bool {
        RoomCaptureSession.isSupported
    }
}

// MARK: - Settings View

struct SettingsView: View {
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: "iphone.gen3")
                            .font(.title2)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Device")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(UIDevice.current.model)
                                .font(.headline)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "lidar.fill")
                            .font(.title2)
                            .foregroundColor(.purple)
                        VStack(alignment: .leading) {
                            Text("LiDAR Status")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(RoomCaptureSession.isSupported ? "Available" : "Not Available")
                                .font(.headline)
                                .foregroundColor(RoomCaptureSession.isSupported ? .green : .red)
                        }
                    }
                } header: {
                    Text("Device Information")
                }
                
                Section {
                    Link(destination: URL(string: "https://developer.apple.com/documentation/roomplan")!) {
                        HStack {
                            Image(systemName: "book.fill")
                                .foregroundColor(.orange)
                            Text("RoomPlan Documentation")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Resources")
                }
                
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Framework")
                        Spacer()
                        Text("RoomPlan + Vision")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("About")
        }
    }
}

// MARK: - Unsupported Device View (Legacy)

private struct UnsupportedDeviceView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(.orange)
                        .padding(.top, 40)
                    
                    Text("LiDAR Not Available")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("""
                RoomPlan requires:
                • iPhone 12 Pro or later
                • iPad Pro (2020 or later)
                • iOS 16.0 or later
                • LiDAR sensor
                """)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Device Capabilities")
                            .font(.headline)
                        
                        CapabilityRow(name: "ARKit World Tracking", supported: true)
                        CapabilityRow(name: "LiDAR Scanning", supported: RoomCaptureSession.isSupported)
                        CapabilityRow(name: "Scene Depth", supported: RoomCaptureSession.isSupported)
                        CapabilityRow(name: "Smoothed Depth", supported: RoomCaptureSession.isSupported)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationTitle("Device Check")
        }
    }
}

struct CapabilityRow: View {
    let name: String
    let supported: Bool
    
    var body: some View {
        HStack {
            Text(name)
                .font(.subheadline)
            Spacer()
            Image(systemName: supported ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(supported ? .green : .red)
        }
    }
}

// Duplicate SettingsView removed - already defined above

#Preview {
    ContentView()
}
