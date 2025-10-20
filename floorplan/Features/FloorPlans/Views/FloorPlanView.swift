//
//  FloorPlanView.swift
//  floorplan
//
//  2D floor plan renderer from CapturedRoom data
//

import SwiftUI
import RoomPlan
import simd

struct FloorPlanView: View {
    let room: CapturedRoom
    @State private var scale: CGFloat = 50 // pixels per meter
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Center the drawing
                let centerX = size.width / 2
                let centerY = size.height / 2
                
                // Draw walls
                drawWalls(context: &context, centerX: centerX, centerY: centerY)
                
                // Draw doors
                drawDoors(context: &context, centerX: centerX, centerY: centerY)
                
                // Draw windows
                drawWindows(context: &context, centerX: centerX, centerY: centerY)
                
                // Draw room labels
                drawLabels(context: &context, centerX: centerX, centerY: centerY)
            }
            .background(Color(white: 0.95))
            .overlay(alignment: .topTrailing) {
                controls
            }
        }
    }
    
    // MARK: - Controls
    private var controls: some View {
        VStack(spacing: 12) {
            Button(action: { scale += 10 }) {
                Image(systemName: "plus.magnifyingglass")
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            Button(action: { scale = max(10, scale - 10) }) {
                Image(systemName: "minus.magnifyingglass")
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            Text("\(Int(scale))px/m")
                .font(.caption2)
                .padding(6)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
        }
        .padding()
    }
    
    // MARK: - Drawing Functions
    
    private func drawWalls(context: inout GraphicsContext, centerX: CGFloat, centerY: CGFloat) {
        for wall in room.walls {
            let path = createWallPath(wall: wall, centerX: centerX, centerY: centerY)
            context.stroke(path, with: .color(.black), lineWidth: 3)
        }
    }
    
    private func drawDoors(context: inout GraphicsContext, centerX: CGFloat, centerY: CGFloat) {
        for door in room.doors {
            let path = createDoorPath(door: door, centerX: centerX, centerY: centerY)
            context.stroke(path, with: .color(.blue), lineWidth: 2)
            
            // Add door arc
            let arcPath = createDoorArc(door: door, centerX: centerX, centerY: centerY)
            context.stroke(arcPath, with: .color(.blue.opacity(0.3)), lineWidth: 1)
        }
    }
    
    private func drawWindows(context: inout GraphicsContext, centerX: CGFloat, centerY: CGFloat) {
        for window in room.windows {
            let path = createWindowPath(window: window, centerX: centerX, centerY: centerY)
            context.stroke(path, with: .color(.cyan), lineWidth: 3)
        }
    }
    
    private func drawLabels(context: inout GraphicsContext, centerX: CGFloat, centerY: CGFloat) {
        // Draw "Room" label in center (you can enhance this)
        let text = Text("Room")
            .font(.title2)
            .foregroundColor(.gray)
        
        context.draw(text, at: CGPoint(x: centerX, y: centerY))
    }
    
    // MARK: - Path Creation
    
    private func createWallPath(wall: CapturedRoom.Surface, centerX: CGFloat, centerY: CGFloat) -> Path {
        var path = Path()
        
        // Extract wall endpoints from transform and dimensions
        let transform = wall.transform
        let dimensions = wall.dimensions
        let width = dimensions.x // width is the x component of dimensions
        
        // Get wall position (simplified - assumes walls align with axes)
        let posX = CGFloat(transform.columns.3.x) * scale
        let posZ = CGFloat(transform.columns.3.z) * scale
        
        let halfWidth = CGFloat(width) * scale / 2
        
        // Draw wall as line (simplified)
        path.move(to: CGPoint(x: centerX + posX - halfWidth, y: centerY - posZ))
        path.addLine(to: CGPoint(x: centerX + posX + halfWidth, y: centerY - posZ))
        
        return path
    }
    
    private func createDoorPath(door: CapturedRoom.Surface, centerX: CGFloat, centerY: CGFloat) -> Path {
        var path = Path()
        
        let transform = door.transform
        let width = door.dimensions.x
        
        let posX = CGFloat(transform.columns.3.x) * scale
        let posZ = CGFloat(transform.columns.3.z) * scale
        let halfWidth = CGFloat(width) * scale / 2
        
        path.move(to: CGPoint(x: centerX + posX - halfWidth, y: centerY - posZ))
        path.addLine(to: CGPoint(x: centerX + posX + halfWidth, y: centerY - posZ))
        
        return path
    }
    
    private func createDoorArc(door: CapturedRoom.Surface, centerX: CGFloat, centerY: CGFloat) -> Path {
        var path = Path()
        
        let transform = door.transform
        let width = door.dimensions.x
        
        let posX = CGFloat(transform.columns.3.x) * scale
        let posZ = CGFloat(transform.columns.3.z) * scale
        let radius = CGFloat(width) * scale
        
        // Draw door swing arc
        path.addArc(
            center: CGPoint(x: centerX + posX, y: centerY - posZ),
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        
        return path
    }
    
    private func createWindowPath(window: CapturedRoom.Surface, centerX: CGFloat, centerY: CGFloat) -> Path {
        var path = Path()
        
        let transform = window.transform
        let width = window.dimensions.x
        
        let posX = CGFloat(transform.columns.3.x) * scale
        let posZ = CGFloat(transform.columns.3.z) * scale
        let halfWidth = CGFloat(width) * scale / 2
        
        // Draw window as double line
        path.move(to: CGPoint(x: centerX + posX - halfWidth, y: centerY - posZ - 2))
        path.addLine(to: CGPoint(x: centerX + posX + halfWidth, y: centerY - posZ - 2))
        path.move(to: CGPoint(x: centerX + posX - halfWidth, y: centerY - posZ + 2))
        path.addLine(to: CGPoint(x: centerX + posX + halfWidth, y: centerY - posZ + 2))
        
        return path
    }
}

#Preview {
    // Preview with dummy data
    Text("FloorPlanView Preview")
}

