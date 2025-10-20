//
//  DataService.swift
//  floorplan
//
//  Enhanced data persistence with CoreData and caching
//

import Foundation
import RoomPlan
import Combine
import CoreData
import UIKit
import simd

/// Enhanced data service with database caching and performance optimizations
@MainActor
class DataService: ObservableObject {
    @Published var savedRooms: [SavedRoom] = []
    @Published var isLoading = false
    
    let documentsDirectory: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }()
    
    private let context: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        self.backgroundContext = PersistenceController.shared.container.newBackgroundContext()
        loadRooms()
    }
    
    func save(_ room: CapturedRoom, named name: String) async throws {
        let roomId = UUID()
        let date = Date()
        
        // Calculate statistics (fast, on current thread)
        let wallCount = room.walls.count
        let doorCount = room.doors.count
        let windowCount = room.windows.count
        let objectCount = room.objects.count
        
        let usdzURL = documentsDirectory.appendingPathComponent("\(roomId).usdz")
        let roomDataURL = documentsDirectory.appendingPathComponent("\(roomId).roomdata")
        
        // Parallelize expensive operations using async let
        async let usdzExport: Void = room.export(to: usdzURL, exportOptions: .model)
        async let roomDataWrite: Void = encodeAndWriteRoomData(room, to: roomDataURL)
        async let thumbnailGen: UIImage? = generateThumbnail(for: room)
        
        // Wait for all parallel operations to complete
        try await usdzExport
        try await roomDataWrite
        let thumbnail = await thumbnailGen
        let thumbnailData = thumbnail?.pngData()
        
        // Save to CoreData in background
        try await backgroundContext.perform {
            let entity = RoomEntity(context: self.backgroundContext)
            entity.id = roomId
            entity.name = name
            entity.dateCreated = date
            entity.usdzPath = usdzURL.lastPathComponent
            entity.wallCount = Int32(wallCount)
            entity.doorCount = Int32(doorCount)
            entity.windowCount = Int32(windowCount)
            entity.objectCount = Int32(objectCount)
            entity.thumbnailData = thumbnailData
            
            try self.backgroundContext.save()
        }
        
        // Update UI on main actor
        await MainActor.run {
            let savedRoom = SavedRoom(
                id: roomId,
                name: name,
                date: date,
                wallCount: wallCount,
                doorCount: doorCount,
                windowCount: windowCount,
                objectCount: objectCount,
                thumbnailData: thumbnailData
            )
            savedRooms.append(savedRoom)
            savedRooms.sort { $0.date > $1.date }
        }
        
        print("💾 Saved room '\(name)' with \(wallCount) walls, \(doorCount) doors, \(windowCount) windows")
    }
    
    // Helper function for parallel execution
    private func encodeAndWriteRoomData(_ room: CapturedRoom, to url: URL) async throws {
        let roomStructure = RoomStructureData(from: room)
        let encoder = JSONEncoder()
        let roomData = try encoder.encode(roomStructure)
        try roomData.write(to: url)
    }
    
    func loadRoomStructure(for savedRoom: SavedRoom) -> RoomStructureData? {
        let roomDataURL = documentsDirectory.appendingPathComponent("\(savedRoom.id).roomdata")
        
        guard FileManager.default.fileExists(atPath: roomDataURL.path) else {
            print("❌ Room data file not found: \(roomDataURL.path)")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: roomDataURL)
            let decoder = JSONDecoder()
            let roomStructure = try decoder.decode(RoomStructureData.self, from: data)
            print("✅ Loaded room structure for: \(savedRoom.name)")
            return roomStructure
        } catch {
            print("❌ Failed to load room structure: \(error)")
            return nil
        }
    }
    
    private func loadRooms() {
        isLoading = true
        
        Task {
            do {
                let fetchRequest: NSFetchRequest<RoomEntity> = RoomEntity.fetchRequest()
                fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \RoomEntity.dateCreated, ascending: false)]
                
                let entities = try context.fetch(fetchRequest)
                
                await MainActor.run {
                    self.savedRooms = entities.map { entity in
                        SavedRoom(
                            id: entity.id ?? UUID(),
                            name: entity.name ?? "Untitled",
                            date: entity.dateCreated ?? Date(),
                            wallCount: Int(entity.wallCount),
                            doorCount: Int(entity.doorCount),
                            windowCount: Int(entity.windowCount),
                            objectCount: Int(entity.objectCount),
                            thumbnailData: entity.thumbnailData
                        )
                    }
                    self.isLoading = false
                    print("📂 Loaded \(self.savedRooms.count) rooms from CoreData")
                }
            } catch {
                print("❌ Failed to load rooms: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    func deleteRoom(_ room: SavedRoom) {
        Task {
            // Delete from CoreData
            do {
                let fetchRequest: NSFetchRequest<RoomEntity> = RoomEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", room.id as CVarArg)
                
                let entities = try context.fetch(fetchRequest)
                for entity in entities {
                    context.delete(entity)
                }
                try context.save()
            } catch {
                print("❌ Failed to delete from CoreData: \(error)")
            }
            
            // Delete files
            let usdzURL = documentsDirectory.appendingPathComponent("\(room.id).usdz")
            try? FileManager.default.removeItem(at: usdzURL)
            
            let roomDataURL = documentsDirectory.appendingPathComponent("\(room.id).roomdata")
            try? FileManager.default.removeItem(at: roomDataURL)
            
            // Update UI
            await MainActor.run {
                savedRooms.removeAll { $0.id == room.id }
            }
            
            print("🗑️ Deleted room: \(room.name)")
        }
    }
    
    // MARK: - Thumbnail Generation
    
    private func generateThumbnail(for room: CapturedRoom) async -> UIImage? {
        // Generate a simple thumbnail from room data
        return await Task.detached(priority: .utility) {
            let size = CGSize(width: 200, height: 200)
            let renderer = UIGraphicsImageRenderer(size: size)
            
            let image = renderer.image { context in
                // Background
                UIColor.systemBlue.withAlphaComponent(0.1).setFill()
                context.fill(CGRect(origin: .zero, size: size))
                
                // Draw simple floor plan representation
                let ctx = context.cgContext
                ctx.setStrokeColor(UIColor.systemBlue.cgColor)
                ctx.setLineWidth(2.0)
                
                // Draw walls as rectangles
                let padding: CGFloat = 20
                let drawRect = CGRect(
                    x: padding,
                    y: padding,
                    width: size.width - padding * 2,
                    height: size.height - padding * 2
                )
                ctx.stroke(drawRect)
                
                // Add icon
                let iconSize: CGFloat = 40
                let iconRect = CGRect(
                    x: (size.width - iconSize) / 2,
                    y: (size.height - iconSize) / 2,
                    width: iconSize,
                    height: iconSize
                )
                
                UIColor.systemBlue.setFill()
                ctx.fillEllipse(in: iconRect)
            }
            
            return image
        }.value
    }
}

// MARK: - Room Structure Data (Simplified for 2D rendering)
struct RoomStructureData: Codable {
    struct Surface: Codable {
        let position: SIMD3<Float>
        let dimensions: SIMD3<Float>
        let category: String
        let rotation: Float  // Y-axis rotation (yaw) for top-down view
    }
    
    let walls: [Surface]
    let doors: [Surface]
    let windows: [Surface]
    let objects: [Surface]
    
    init(from room: CapturedRoom) {
        self.walls = room.walls.map { surface in
            Surface(
                position: SIMD3<Float>(
                    surface.transform.columns.3.x,
                    surface.transform.columns.3.y,
                    surface.transform.columns.3.z
                ),
                dimensions: surface.dimensions,
                category: String(describing: surface.category),
                rotation: Self.extractRotation(from: surface.transform)
            )
        }
        
        self.doors = room.doors.map { surface in
            Surface(
                position: SIMD3<Float>(
                    surface.transform.columns.3.x,
                    surface.transform.columns.3.y,
                    surface.transform.columns.3.z
                ),
                dimensions: surface.dimensions,
                category: String(describing: surface.category),
                rotation: Self.extractRotation(from: surface.transform)
            )
        }
        
        self.windows = room.windows.map { surface in
            Surface(
                position: SIMD3<Float>(
                    surface.transform.columns.3.x,
                    surface.transform.columns.3.y,
                    surface.transform.columns.3.z
                ),
                dimensions: surface.dimensions,
                category: String(describing: surface.category),
                rotation: Self.extractRotation(from: surface.transform)
            )
        }
        
        self.objects = room.objects.map { object in
            Surface(
                position: SIMD3<Float>(
                    object.transform.columns.3.x,
                    object.transform.columns.3.y,
                    object.transform.columns.3.z
                ),
                dimensions: object.dimensions,
                category: String(describing: object.category),
                rotation: Self.extractRotation(from: object.transform)
            )
        }
    }
    
    // Helper to extract Y-axis rotation (yaw) from 4x4 transform matrix
    private static func extractRotation(from transform: simd_float4x4) -> Float {
        // Extract Y-axis rotation (yaw) for top-down view
        return atan2(transform.columns.0.z, transform.columns.0.x)
    }
}

// MARK: - Saved Room Model
struct SavedRoom: Identifiable, Codable {
    let id: UUID
    let name: String
    let date: Date
    let wallCount: Int
    let doorCount: Int
    let windowCount: Int
    let objectCount: Int
    let thumbnailData: Data?
    
    init(id: UUID = UUID(), name: String, date: Date, wallCount: Int = 0, doorCount: Int = 0, windowCount: Int = 0, objectCount: Int = 0, thumbnailData: Data? = nil) {
        self.id = id
        self.name = name
        self.date = date
        self.wallCount = wallCount
        self.doorCount = doorCount
        self.windowCount = windowCount
        self.objectCount = objectCount
        self.thumbnailData = thumbnailData
    }
    
    var thumbnail: UIImage? {
        guard let data = thumbnailData else { return nil }
        return UIImage(data: data)
    }
}

