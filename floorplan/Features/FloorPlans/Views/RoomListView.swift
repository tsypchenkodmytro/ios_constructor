//
//  RoomListView.swift
//  floorplan
//
//  Browse saved rooms - Enhanced with dark mode and loading states
//

import SwiftUI

struct RoomListView: View {
    @EnvironmentObject private var dataService: DataService
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background color for dark mode
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                
                Group {
                    if dataService.isLoading {
                        LoadingView()
                    } else if dataService.savedRooms.isEmpty {
                        emptyState
                    } else {
                        roomList
                    }
                }
            }
            .navigationTitle("My Rooms")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !dataService.isLoading && !dataService.savedRooms.isEmpty {
                        Text("\(dataService.savedRooms.count)")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color.blue.gradient)
                            )
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(colorScheme == .dark ? 0.2 : 0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "viewfinder.circle")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue.gradient)
            }
            
            VStack(spacing: 12) {
                Text("No Rooms Yet")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Text("Tap the Scan tab to start scanning\nyour first room with LiDAR")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Hint card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("Quick Tip")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Text("Make sure you have good lighting and slowly move around the room for best results.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: colorScheme == .dark ? .secondarySystemBackground : .systemGray6))
            )
            .padding(.horizontal, 40)
            .padding(.top, 20)
            
            Spacer()
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Room List
    
    private var roomList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(dataService.savedRooms) { room in
                    RoomCard(room: room)
                }
            }
            .padding()
        }
    }
}

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading rooms...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Room Card (Enhanced with Dark Mode)

struct RoomCard: View {
    let room: SavedRoom
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationLink(destination: RoomDetailView(room: room)) {
            HStack(spacing: 16) {
                // Thumbnail or Icon
                Group {
                    if let thumbnail = room.thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 70, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.gradient)
                                .frame(width: 70, height: 70)
                            
                            Image(systemName: "square.stack.3d.up.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                }
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 4, x: 0, y: 2)
                
                // Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(room.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(room.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    
                    // Stats
                    HStack(spacing: 8) {
                        StatBadge(icon: "square.split.2x2", count: room.wallCount, color: .blue)
                        StatBadge(icon: "door.left.hand.open", count: room.doorCount, color: .green)
                        StatBadge(icon: "rectangle.portrait", count: room.windowCount, color: .cyan)
                    }
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: colorScheme == .dark ? .secondarySystemBackground : .white))
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Badge
struct StatBadge: View {
    let icon: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}

#Preview {
    RoomListView()
        .environmentObject(DataService())
}
