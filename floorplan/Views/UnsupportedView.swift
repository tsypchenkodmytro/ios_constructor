//
//  UnsupportedView.swift
//  floorplan
//
//  Modern unsupported device view
//

import SwiftUI
import RoomPlan

struct UnsupportedView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 40)
                    
                    // Icon
                    ZStack {
                        Circle()
                            .fill(.orange.opacity(0.1))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.orange.gradient)
                    }
                    
                    // Title
                    VStack(spacing: 12) {
                        Text("LiDAR Not Available")
                            .font(.title.bold())
                        
                        Text("This device doesn't support RoomPlan scanning")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Requirements card
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Requirements", systemImage: "checklist")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            RequirementRow(text: "iPhone 12 Pro or later")
                            RequirementRow(text: "iPad Pro (2020 or later)")
                            RequirementRow(text: "iOS 16.0 or later")
                            RequirementRow(text: "LiDAR sensor")
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    
                    // Current device
                    VStack(spacing: 8) {
                        Text("Your Device")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "iphone.gen3")
                                .foregroundColor(.blue)
                            Text(UIDevice.current.model)
                                .font(.headline)
                        }
                        .padding()
                        .background(.blue.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Device Check")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Requirement Row
struct RequirementRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.orange.opacity(0.6))
            Text(text)
                .font(.subheadline)
        }
    }
}

