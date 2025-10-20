//
//  FloorPlanRenderer.swift
//  floorplan
//
//  Real 2D floor plan renderer using RoomPlan geometry
//

import SwiftUI
import RoomPlan
import simd

struct FloorPlanRenderer: View {
    let room: CapturedRoom
    @State private var scale: CGFloat = 100 // pixels per meter
    @State private var offset: CGSize = .zero
    
    // Computed room bounds from actual geometry
    private var roomBounds: (minX: Float, maxX: Float, minZ: Float, maxZ: Float) {
        calculateRoomBounds()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(.systemGray6)
                
                // Real floor plan from RoomPlan data
                Canvas { context, size in
                    let centerX = size.width / 2 + offset.width
                    let centerY = size.height / 2 + offset.height
                    
                    // Draw floor area
                    drawFloorArea(context: &context, centerX: centerX, centerY: centerY, size: size)
                    
                    // Draw walls from actual RoomPlan geometry
                    drawRealWalls(context: &context, centerX: centerX, centerY: centerY)
                    
                    // Draw doors from actual RoomPlan geometry
                    drawRealDoors(context: &context, centerX: centerX, centerY: centerY)
                    
                    // Draw windows from actual RoomPlan geometry
                    drawRealWindows(context: &context, centerX: centerX, centerY: centerY)
                    
                    // Draw room dimensions
                    drawRoomDimensions(context: &context, centerX: centerX, centerY: centerY)
                }
                
                // Controls
                VStack {
                    HStack {
                        Spacer()
                        controlPanel
                    }
                    Spacer()
                    statsPanel
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        offset = value.translation
                    }
            )
        }
        .navigationTitle("Floor Plan")
    }
    
    // MARK: - Control Panel
    private var controlPanel: some View {
        VStack(spacing: 8) {
            Button(action: { scale = min(100, scale + 10) }) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(.blue)
                    .clipShape(Circle())
            }
            
            Button(action: { scale = max(20, scale - 10) }) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(.blue)
                    .clipShape(Circle())
            }
            
            Button(action: { offset = .zero; scale = 50 }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(.purple)
                    .clipShape(Circle())
            }
        }
        .padding()
    }
    
    // MARK: - Stats Panel
    private var statsPanel: some View {
        HStack(spacing: 12) {
            Label("\(room.walls.count)", systemImage: "square.split.2x2")
            Label("\(room.doors.count)", systemImage: "door.left.hand.open")
            Label("\(room.windows.count)", systemImage: "rectangle.portrait")
            
            Spacer()
            
            Text("Scale: \(Int(scale))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
    }
    
    // MARK: - Real RoomPlan Geometry Drawing Functions
    
    private func drawFloorArea(context: inout GraphicsContext, centerX: CGFloat, centerY: CGFloat, size: CGSize) {
        let bounds = roomBounds
        let roomWidth = CGFloat(bounds.maxX - bounds.minX) * scale
        let roomHeight = CGFloat(bounds.maxZ - bounds.minZ) * scale
        
        let rect = CGRect(
            x: centerX - roomWidth/2,
            y: centerY - roomHeight/2,
            width: roomWidth,
            height: roomHeight
        )
        
        var floorPath = Path()
        floorPath.addRect(rect)
        context.fill(floorPath, with: .color(.white))
        context.stroke(floorPath, with: .color(.gray.opacity(0.5)), lineWidth: 1)
    }
    
    private func drawRealWalls(context: inout GraphicsContext, centerX: CGFloat, centerY: CGFloat) {
        for wall in room.walls {
            // Extract 3D position from transform matrix
            let transform = wall.transform
            let position = simd_float3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            
            // Get wall dimensions
            let dimensions = wall.dimensions
            let width = dimensions.x
            let height = dimensions.z // Use Z for depth in top-down view
            
            // Convert 3D position to 2D screen coordinates (X/Z projection)
            let screenX = centerX + CGFloat(position.x) * scale
            let screenZ = centerY - CGFloat(position.z) * scale // Flip Z for screen coordinates
            
            // Draw wall as rectangle
            let wallRect = CGRect(
                x: screenX - CGFloat(width) * scale / 2,
                y: screenZ - CGFloat(height) * scale / 2,
                width: CGFloat(width) * scale,
                height: CGFloat(height) * scale
            )
            
            var wallPath = Path()
            wallPath.addRect(wallRect)
            context.fill(wallPath, with: .color(.black))
        }
    }
    
    private func drawRealDoors(context: inout GraphicsContext, centerX: CGFloat, centerY: CGFloat) {
        for door in room.doors {
            // Extract 3D position from transform matrix
            let transform = door.transform
            let position = simd_float3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            
            // Get door dimensions
            let dimensions = door.dimensions
            let width = dimensions.x
            
            // Convert to screen coordinates
            let screenX = centerX + CGFloat(position.x) * scale
            let screenZ = centerY - CGFloat(position.z) * scale
            
            // Draw door opening
            let doorRect = CGRect(
                x: screenX - CGFloat(width) * scale / 2,
                y: screenZ - 4,
                width: CGFloat(width) * scale,
                height: 8
            )
            
            var doorPath = Path()
            doorPath.addRect(doorRect)
            context.fill(doorPath, with: .color(.blue))
            
            // Draw door swing arc
            let arcRadius = CGFloat(width) * scale * 0.8
            var arcPath = Path()
            arcPath.addArc(
                center: CGPoint(x: screenX - CGFloat(width) * scale / 2, y: screenZ),
                radius: arcRadius,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
            context.stroke(arcPath, with: .color(.blue.opacity(0.3)), lineWidth: 1)
        }
    }
    
    private func drawRealWindows(context: inout GraphicsContext, centerX: CGFloat, centerY: CGFloat) {
        for window in room.windows {
            // Extract 3D position from transform matrix
            let transform = window.transform
            let position = simd_float3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            
            // Get window dimensions
            let dimensions = window.dimensions
            let width = dimensions.x
            
            // Convert to screen coordinates
            let screenX = centerX + CGFloat(position.x) * scale
            let screenZ = centerY - CGFloat(position.z) * scale
            
            // Draw window as double line
            let windowWidth = CGFloat(width) * scale
            
            var windowPath1 = Path()
            windowPath1.move(to: CGPoint(x: screenX - windowWidth/2, y: screenZ - 3))
            windowPath1.addLine(to: CGPoint(x: screenX + windowWidth/2, y: screenZ - 3))
            
            var windowPath2 = Path()
            windowPath2.move(to: CGPoint(x: screenX - windowWidth/2, y: screenZ + 3))
            windowPath2.addLine(to: CGPoint(x: screenX + windowWidth/2, y: screenZ + 3))
            
            context.stroke(windowPath1, with: .color(.cyan), lineWidth: 2)
            context.stroke(windowPath2, with: .color(.cyan), lineWidth: 2)
        }
    }
    
    private func drawRoomDimensions(context: inout GraphicsContext, centerX: CGFloat, centerY: CGFloat) {
        let bounds = roomBounds
        let roomWidth = bounds.maxX - bounds.minX
        let roomLength = bounds.maxZ - bounds.minZ
        
        // Draw dimension labels
        let widthText = Text(String(format: "%.2fm", roomWidth))
            .font(.caption)
            .foregroundColor(.gray)
        
        let lengthText = Text(String(format: "%.2fm", roomLength))
            .font(.caption)
            .foregroundColor(.gray)
        
        // Position dimension labels
        context.draw(widthText, at: CGPoint(x: centerX, y: centerY - CGFloat(roomLength) * scale / 2 - 20))
        context.draw(lengthText, at: CGPoint(x: centerX + CGFloat(roomWidth) * scale / 2 + 30, y: centerY))
    }
    
    // MARK: - Geometry Calculations
    
    private func calculateRoomBounds() -> (minX: Float, maxX: Float, minZ: Float, maxZ: Float) {
        var minX: Float = .infinity
        var maxX: Float = -.infinity
        var minZ: Float = .infinity
        var maxZ: Float = -.infinity
        
        // Calculate bounds from all surfaces (walls, doors, windows)
        let allSurfaces = room.walls + room.doors + room.windows
        
        for surface in allSurfaces {
            let position = simd_float3(surface.transform.columns.3.x, surface.transform.columns.3.y, surface.transform.columns.3.z)
            let dimensions = surface.dimensions
            
            let halfWidth = dimensions.x / 2
            let halfDepth = dimensions.z / 2
            
            minX = min(minX, position.x - halfWidth)
            maxX = max(maxX, position.x + halfWidth)
            minZ = min(minZ, position.z - halfDepth)
            maxZ = max(maxZ, position.z + halfDepth)
        }
        
        // Fallback if no surfaces found
        if minX == .infinity {
            return (minX: -2, maxX: 2, minZ: -2, maxZ: 2)
        }
        
        return (minX, maxX, minZ, maxZ)
    }
}

