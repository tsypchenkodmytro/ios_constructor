//
//  ModelViewer3D.swift
//  floorplan
//
//  3D model viewer using QuickLook
//

import SwiftUI
import QuickLook
import SceneKit

struct ModelViewer3D: View {
    let url: URL
    let roomName: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var useQuickLook = false   // toggle
    
    var body: some View {
        NavigationView {
            Group {
//                if useQuickLook {
//                    QuickLookPreview(url: url,
//                                     roomName: roomName,
//                                     dismiss: dismiss)
//                } else {
                    SceneKitModelView(url: url)
//                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(roomName)
            .toolbar {
                
                // Close button
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Close")
                        }
                    }
                }
//                // 🔁 Toggle View Button
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button(action: {
//                        withAnimation(.easeInOut) {
//                            useQuickLook.toggle()
//                        }
//                    }) {
//                        HStack(spacing: 6) {
//                            Image(systemName: useQuickLook ? "cube" : "eye")
//                            Text(useQuickLook ? "Coloring View" : "Simple Preview")
//                        }
//                    }
//                }
            }
        }
    }
}

// MARK: - QuickLook Preview
struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    let roomName: String
    let dismiss: DismissAction
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(url: url, dismiss: dismiss)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        let url: URL
        let dismiss: DismissAction
        
        init(url: URL, dismiss: DismissAction) {
            self.url = url
            self.dismiss = dismiss
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return url as QLPreviewItem
        }
        
        func previewControllerDidDismiss(_ controller: QLPreviewController) {
            dismiss()
        }
    }
}

// MARK: - SceneKit Preview with coloring of wall
struct SceneKitModelView: UIViewRepresentable {
    let url: URL
    
    /// Coordinator caches the generated gradient background image per view size
    /// to avoid re-rendering on every update. This improves performance and
    /// ensures correct handling on rotation and layout changes.
    class Coordinator {
        var lastSize: CGSize?
        var cachedImage: UIImage?
    }
    
    /// Creates the coordinator used to store cached background resources.
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    /// Creates and configures the `SCNView`, loads the USDZ scene, applies
    /// component-based coloring, and sets a high-quality gradient background
    /// via `scene.background.contents`.
    ///
    /// - Parameter context: The representable context providing the coordinator.
    /// - Returns: A configured `SCNView` ready for display.
    func makeUIView(context: Context) -> SCNView {

        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = true
        scnView.antialiasingMode = .multisampling4X
        scnView.autoenablesDefaultLighting = true
        do {
            let scene = try SCNScene(url: url, options: nil)
            scnView.scene = scene
            processScene(scene)
        } catch {
            print("❌ Failed to load scene: \(error)")
            let empty = SCNScene()
            scnView.scene = empty
        }
        updateBackground(for: scnView, coordinator: context.coordinator)
        return scnView
    }
    
    /// Updates the `SCNView` when SwiftUI signals a change, ensuring the
    /// gradient background is regenerated if the view size changed (e.g.,
    /// on rotation) while reusing cached images whenever possible.
    func updateUIView(_ uiView: SCNView, context: Context) {
        updateBackground(for: uiView, coordinator: context.coordinator)
    }
    
    /// Updates the SceneKit background image with a cached or newly generated
    /// gradient. The gradient is applied to `scene.background.contents` for
    /// proper integration with SceneKit's rendering pipeline.
    ///
    /// - Parameters:
    ///   - view: The `SCNView` to update.
    ///   - coordinator: The resource cache coordinator.
    private func updateBackground(for view: SCNView, coordinator: Coordinator) {
        let size = view.bounds.size
        guard size.width > 0 && size.height > 0 else { return }
        if coordinator.lastSize != size || coordinator.cachedImage == nil {
            coordinator.cachedImage = makeGradientImage(size: size)
            coordinator.lastSize = size
        }
        if let image = coordinator.cachedImage {
            view.scene?.background.contents = image
        }
    }
    
    /// Generates a vertical gradient image where the top and bottom are black
    /// and the center is a soft white, using multiple intermediate stops to
    /// ensure smooth transitions and good visual contrast.
    ///
    /// - Parameter size: The target size matching the `SCNView` bounds.
    /// - Returns: A high-quality gradient image at screen scale.
    private func makeGradientImage(size: CGSize) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { ctx in
            let layer = CAGradientLayer()
            layer.frame = CGRect(origin: .zero, size: size)
            layer.startPoint = CGPoint(x: 0.5, y: 0.0)
            layer.endPoint = CGPoint(x: 0.5, y: 1.0)
            layer.colors = [
                UIColor.black.cgColor,
                UIColor(white: 0.08, alpha: 1.0).cgColor,
                UIColor(white: 0.22, alpha: 1.0).cgColor,
                UIColor(white: 0.6, alpha: 0.35).cgColor,
                UIColor.white.withAlphaComponent(0.08).cgColor,
                UIColor(white: 0.6, alpha: 0.35).cgColor,
                UIColor(white: 0.22, alpha: 1.0).cgColor,
                UIColor(white: 0.08, alpha: 1.0).cgColor,
                UIColor.black.cgColor
            ]
            layer.locations = [0.0, 0.15, 0.3, 0.45, 0.5, 0.55, 0.7, 0.85, 1.0] as [NSNumber]
            layer.render(in: ctx.cgContext)
        }
        return image
    }
    
    /// Traverses all descendants in the SceneKit graph and applies color
    /// mapping to structural components (walls, doors, windows, floor, ceiling,
    /// objects). Logs any nodes that fail coloring for diagnostic purposes.
    private func processScene(_ scene: SCNScene) {
        // MARK: - here color can be changed as desired
        let colorMap: [String: UIColor] = [
            "wall": UIColor.darkGray,
            "door": UIColor.lightGray,
            "window": UIColor.lightText,
            "floor": UIColor.white,
            "ceiling": UIColor.white,
            "object": UIColor.white
        ]
        var failed: [String] = []
        scene.rootNode.enumerateChildNodes { node, _ in
            if let geometry = node.geometry {
                if let type = componentType(for: node), let color = colorMap[type] {
                    if !apply(color: color, to: geometry, type: type) {
                        failed.append(node.name ?? "unnamed")
                    }
                }
            }
        }
        if !failed.isEmpty {
            print("⚠️ Failed to color nodes: \(failed.joined(separator: ", "))")
        }
    }
    
    /// Attempts to infer the semantic component type from node or geometry
    /// names. Returns `nil` when no match is found.
    private func componentType(for node: SCNNode) -> String? {
        let candidates = [node.name?.lowercased(), node.geometry?.name?.lowercased()].compactMap { $0 }
        for n in candidates {
            print("kind of n",n)
            if n.contains("wall") { return "wall" }
            if n.contains("door") { return "door" }
            if n.contains("window") { return "window" }
            if n.contains("floor") { return "floor" }
            if n.contains("ceiling") || n.contains("roof") { return "ceiling" }
            if n.contains("object") || n.contains("furniture") { return "object" }
        }
        return nil
    }
    
    /// Applies the specified color to the geometry's materials, adding
    /// specular and emission where appropriate (e.g., windows get light
    /// emission and partial transparency). Ensures materials exist and
    /// returns whether the operation succeeded.
    private func apply(color: UIColor, to geometry: SCNGeometry, type: String) -> Bool {
        var materials = geometry.materials
        if materials.isEmpty { materials = [SCNMaterial()] }
        var success = false
        for m in materials {
            m.diffuse.contents = color
            m.specular.contents = UIColor.white
            m.emission.contents = type == "window" ? UIColor.white.withAlphaComponent(0.15) : UIColor.clear
            m.isDoubleSided = true
            if type == "window" {
                m.transparency = 0.4
                m.blendMode = .alpha
            } else {
                m.transparency = 1.0
            }
            success = true
        }
        if geometry.materials.isEmpty { geometry.materials = materials }
        return success
    }
}
