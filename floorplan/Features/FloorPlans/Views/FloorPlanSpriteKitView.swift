//
//  FloorPlanSpriteKitView.swift
//  floorplan
//
//  Enhanced 2D floor plan renderer with improved accuracy and UI
//

import SwiftUI
import SpriteKit

struct FloorPlanSpriteKitView: View {
    let roomStructure: RoomStructureData
    let roomName: String
    @State private var showMeasurements = true
    @State private var useImperialUnits = false
    @State private var sceneRef: FloorPlanScene?
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var isProcessingShare = false
    
    var body: some View {
        GeometryReader { geometry in
            SpriteKitContainer(
                roomStructure: roomStructure,
                roomName: roomName,
                viewSize: geometry.size,
                showMeasurements: showMeasurements,
                useImperialUnits: useImperialUnits,
                sceneRef: $sceneRef
            )
            .ignoresSafeArea(.all, edges: .bottom)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("Zoom Out", systemImage: "minus.magnifyingglass", action: { 
                    sceneRef?.zoomOut()
                })
                .labelStyle(.iconOnly)
                
                Button("Zoom In", systemImage: "plus.magnifyingglass", action: { 
                    sceneRef?.zoomIn()
                })
                .labelStyle(.iconOnly)
                
                Menu {
                    Button(showMeasurements ? "Hide" : "Show",
                           systemImage: showMeasurements ? "ruler" : "ruler.fill",
                           action: {
                        showMeasurements.toggle()
                        sceneRef?.toggleMeasurements()
                    })
                    .labelStyle(.iconOnly)
                    
                    Button("\(useImperialUnits ? "m" : "ft")",
                           action: {
                        useImperialUnits.toggle()
                        sceneRef?.toggleUnits()
                    })
                    .labelStyle(.titleOnly)
                    
                    Divider()
                    
                    Button("Share", systemImage: "square.and.arrow.up", action: {
                        Task {
                            await shareFloorPlan()
                        }
                    })
                    .labelStyle(.iconOnly)
                    
                    Button("Reset", systemImage: "arrow.counterclockwise", action: {
                        sceneRef?.resetView()
                    })
                    .labelStyle(.iconOnly)
                } label: {
                    Button("Options", systemImage: "ellipsis", action: {})
                        .labelStyle(.iconOnly)
                }
            }
        }
        .onAppear {
            // Prevent screen from sleeping while viewing floor plan
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            // Re-enable screen timeout when leaving floor plan
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .sheet(isPresented: $showShareSheet) {
            if !shareItems.isEmpty {
                ShareSheet(items: shareItems)
            }
        }
        .overlay {
            if isProcessingShare {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Preparing to share...")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
    
    private func shareFloorPlan() async {
        // Show loading overlay
        await MainActor.run {
            isProcessingShare = true
            shareItems = [] // Clear previous items
        }
        
        guard let scene = sceneRef,
              let view = scene.view else { 
            print("❌ Failed to get scene or view for sharing")
            await MainActor.run {
                isProcessingShare = false
            }
            return 
        }
        
        print("📸 Capturing floor plan image...")
        
        // Add a small delay to ensure the loading UI shows
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Capture the scene as an image
        let image = await MainActor.run {
            let renderer = UIGraphicsImageRenderer(size: view.bounds.size)
            return renderer.image { context in
                view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
            }
        }
        
        print("✅ Image captured, size: \(image.size)")
        print("📝 Setting up share items...")
        
        // Set up share items and present sheet
        await MainActor.run {
            shareItems = [image, "Floor Plan: \(roomName)"]
            print("📦 Share items count: \(shareItems.count)")
            isProcessingShare = false
            showShareSheet = true
            print("📱 Presenting share sheet...")
        }
    }
}

// MARK: - ShareSheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        print("🔄 Creating UIActivityViewController with \(items.count) items")
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // Configure for iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            controller.popoverPresentationController?.sourceView = UIApplication.shared.windows.first
            controller.popoverPresentationController?.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            controller.popoverPresentationController?.permittedArrowDirections = []
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

struct SpriteKitContainer: UIViewRepresentable {
    let roomStructure: RoomStructureData
    let roomName: String
    let viewSize: CGSize
    let showMeasurements: Bool
    let useImperialUnits: Bool
    @Binding var sceneRef: FloorPlanScene?
    
    func makeUIView(context: Context) -> SKView {
        let skView = SKView()
        skView.backgroundColor = .white
        if #available(iOS 13.0, *) {
            skView.overrideUserInterfaceStyle = .light
        }
        skView.showsFPS = false
        skView.showsNodeCount = false
        skView.ignoresSiblingOrder = true
        
        let scene = FloorPlanScene(
            roomStructure: roomStructure,
            roomName: roomName,
            size: viewSize,
            showMeasurements: showMeasurements,
            useImperialUnits: useImperialUnits
        )
        scene.scaleMode = .aspectFill
        skView.presentScene(scene)
        
        // Store scene reference for toolbar actions
        sceneRef = scene
        
        return skView
    }
    
    func updateUIView(_ uiView: SKView, context: Context) {
        if let scene = uiView.scene as? FloorPlanScene {
            scene.size = viewSize
            scene.updateLayout()
            scene.updateSettings(showMeasurements: showMeasurements, useImperialUnits: useImperialUnits)
        }
    }
}

// MARK: - FloorPlanScene
class FloorPlanScene: SKScene, UIGestureRecognizerDelegate {
    
    // MARK: - Constants
    private enum Constants {
        static let wallLineWidth: CGFloat = 4.0
        static let doorLineWidth: CGFloat = 2.0
        static let buttonSize: CGFloat = 52.0
        static let buttonSpacing: CGFloat = 14.0
        static let buttonMargin: CGFloat = 20.0
        static let buttonBottomStart: CGFloat = 120.0
        static let measurementFontSize: CGFloat = 12.0
        static let floorFillAlpha: CGFloat = 0.3
        static let measurementStrokeWidth: CGFloat = 3.0
        static let minZoomScale: CGFloat = 0.3
        static let maxZoomScale: CGFloat = 8.0
        static let zoomFactor: CGFloat = 1.4
    }
    
    let roomStructure: RoomStructureData
    let roomName: String
    
    private var contentNode: SKNode!
    private var wallsLayer: SKNode!
    private var doorsLayer: SKNode!
    private var windowsLayer: SKNode!
    private var labelsLayer: SKNode!
    private var floorLayer: SKNode!
    
    private var initialScale: CGFloat = 1.0
    private var currentScale: CGFloat = 1.0
    private var lastPanPosition: CGPoint = .zero
    
    private var showMeasurements: Bool
    private var useImperialUnits: Bool
    
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)
    
    init(roomStructure: RoomStructureData, roomName: String, size: CGSize, showMeasurements: Bool = true, useImperialUnits: Bool = false) {
        self.roomStructure = roomStructure
        self.roomName = roomName
        self.showMeasurements = showMeasurements
        self.useImperialUnits = useImperialUnits
        super.init(size: size)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        backgroundColor = .white
        
        hapticGenerator.prepare()
        setupScene()
        setupGestures(for: view)
    }
    
    func updateLayout() {
        // Layout updates handled by SwiftUI toolbar now
    }
    
    func updateSettings(showMeasurements: Bool, useImperialUnits: Bool) {
        self.showMeasurements = showMeasurements
        self.useImperialUnits = useImperialUnits
        addMeasurements()
    }
    
    
    private func setupScene() {
        // Add full-screen white background to prevent any black areas
        let backgroundNode = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        backgroundNode.fillColor = .white
        backgroundNode.strokeColor = .clear
        backgroundNode.zPosition = -100
        addChild(backgroundNode)
        
        // Create layered structure
        contentNode = SKNode()
        addChild(contentNode)
        
        // Create layers for better organization
        floorLayer = SKNode()
        floorLayer.zPosition = -3
        contentNode.addChild(floorLayer)
        
        
        wallsLayer = SKNode()
        wallsLayer.zPosition = 1
        contentNode.addChild(wallsLayer)
        
        doorsLayer = SKNode()
        doorsLayer.zPosition = 2
        contentNode.addChild(doorsLayer)
        
        windowsLayer = SKNode()
        windowsLayer.zPosition = 2
        contentNode.addChild(windowsLayer)
        
        // Labels layer outside contentNode so they don't scale
        labelsLayer = SKNode()
        labelsLayer.zPosition = 10
        addChild(labelsLayer)
        
        // Calculate bounds and scale
        let bounds = calculateBounds()
        let viewSize = size
        
        guard viewSize.width > 0 && viewSize.height > 0 else { return }
        
        let roomWidth = CGFloat(bounds.maxX - bounds.minX)
        let roomHeight = CGFloat(bounds.maxZ - bounds.minZ)
        
        guard roomWidth > 0 && roomHeight > 0 else { return }
        
        let scaleX = viewSize.width * 0.75 / roomWidth
        let scaleY = viewSize.height * 0.75 / roomHeight
        initialScale = min(scaleX, scaleY)
        currentScale = initialScale
        
        contentNode.position = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        
        // Draw floor plan elements
        drawFloorArea(bounds: bounds)
        drawWalls()
        drawDoors()
        drawWindows()
        if showMeasurements {
            addMeasurements()
        }
        
    }
    
    private func calculateBounds() -> (minX: Float, maxX: Float, minZ: Float, maxZ: Float) {
        var minX: Float = .infinity
        var maxX: Float = -.infinity
        var minZ: Float = .infinity
        var maxZ: Float = -.infinity
        
        let allSurfaces = roomStructure.walls + roomStructure.doors + roomStructure.windows
        
        for surface in allSurfaces {
            let pos = surface.position
            let dim = surface.dimensions
            let rotation = surface.rotation
            
            let halfWidth = dim.x / 2
            let dx = halfWidth * cos(rotation)
            let dz = halfWidth * sin(rotation)
            
            let x1 = pos.x - dx
            let z1 = pos.z - dz
            let x2 = pos.x + dx
            let z2 = pos.z + dz
            
            minX = min(minX, x1, x2)
            maxX = max(maxX, x1, x2)
            minZ = min(minZ, z1, z2)
            maxZ = max(maxZ, z1, z2)
        }
        
        if minX == .infinity {
            return (minX: -2, maxX: 2, minZ: -2, maxZ: 2)
        }
        
        let paddingX = (maxX - minX) * 0.15
        let paddingZ = (maxZ - minZ) * 0.15
        
        return (minX: minX - paddingX, maxX: maxX + paddingX, 
                minZ: minZ - paddingZ, maxZ: maxZ + paddingZ)
    }
    
    private func calculateWallEndpoints(surface: RoomStructureData.Surface) -> (start: CGPoint, end: CGPoint) {
        let centerX = CGFloat(surface.position.x) * currentScale
        let centerZ = -CGFloat(surface.position.z) * currentScale
        let width = CGFloat(surface.dimensions.x)
        let rotation = CGFloat(surface.rotation)
        
        let halfWidth = width / 2
        let dx = halfWidth * cos(rotation) * currentScale
        let dz = -halfWidth * sin(rotation) * currentScale
        
        let start = CGPoint(x: centerX - dx, y: centerZ - dz)
        let end = CGPoint(x: centerX + dx, y: centerZ + dz)
        
        return (start, end)
    }
    
    private func drawFloorArea(bounds: (minX: Float, maxX: Float, minZ: Float, maxZ: Float)) {
        let width = CGFloat(bounds.maxX - bounds.minX) * currentScale
        let height = CGFloat(bounds.maxZ - bounds.minZ) * currentScale
        let centerX = CGFloat((bounds.maxX + bounds.minX) / 2) * currentScale
        let centerZ = -CGFloat((bounds.maxZ + bounds.minZ) / 2) * currentScale
        
        let floorRect = CGRect(
            x: centerX - width / 2,
            y: centerZ - height / 2,
            width: width,
            height: height
        )
        
        let floorNode = SKShapeNode(rect: floorRect, cornerRadius: 8)
        floorNode.fillColor = .white
        floorNode.strokeColor = .clear
        floorNode.lineWidth = 0.0
        floorLayer.addChild(floorNode)
    }
    
    
    private func drawWalls() {
        for wall in roomStructure.walls {
            let (start, end) = calculateWallEndpoints(surface: wall)
            
            // Draw wall with modern clean styling
            let wallPath = CGMutablePath()
            wallPath.move(to: start)
            wallPath.addLine(to: end)
            
            // Main wall with scale-responsive width
            let wallNode = SKShapeNode(path: wallPath)
            wallNode.strokeColor = UIColor.black
            wallNode.lineWidth = max(3.0, Constants.wallLineWidth / (currentScale / initialScale))
            wallNode.lineCap = .round
            wallNode.glowWidth = 0.5
            
            wallsLayer.addChild(wallNode)
        }
    }
    
    private func drawDoors() {
        doorsLayer.removeAllChildren()
        for door in roomStructure.doors {
            let (start, end) = calculateWallEndpoints(surface: door)

            // Match window design: erase wall segment under the door
            let angle = atan2(end.y - start.y, end.x - start.x)
            let perpAngle = angle + .pi / 2
            let currentWallWidth = max(3.0, Constants.wallLineWidth / (currentScale / initialScale))
            let eraserWidth = currentWallWidth + 2.0
            let erasePath = CGMutablePath()
            erasePath.move(to: start)
            erasePath.addLine(to: end)
            let eraseNode = SKShapeNode(path: erasePath)
            eraseNode.strokeColor = .white
            eraseNode.lineWidth = eraserWidth
            eraseNode.lineCap = .butt
            doorsLayer.addChild(eraseNode)

            // Draw two thin, parallel light-gray lines for door frame
            // Make them shorter than the full opening to represent door frame properly
            let offset: CGFloat = 2.0
            let offsetX = offset * cos(perpAngle)
            let offsetY = offset * sin(perpAngle)
            
            // Shorten the door frame lines by 10% on each end to create proper door frame
            let doorFrameInset: CGFloat = 0.1
            let dx = (end.x - start.x) * doorFrameInset
            let dy = (end.y - start.y) * doorFrameInset
            
            let frameStart = CGPoint(x: start.x + dx, y: start.y + dy)
            let frameEnd = CGPoint(x: end.x - dx, y: end.y - dy)

            let line1Start = CGPoint(x: frameStart.x + offsetX, y: frameStart.y + offsetY)
            let line1End = CGPoint(x: frameEnd.x + offsetX, y: frameEnd.y + offsetY)
            let path1 = CGMutablePath()
            path1.move(to: line1Start)
            path1.addLine(to: line1End)
            let node1 = SKShapeNode(path: path1)
            node1.strokeColor = UIColor.lightGray
            node1.lineWidth = 1.5
            node1.lineCap = .butt
            doorsLayer.addChild(node1)

            let line2Start = CGPoint(x: frameStart.x - offsetX, y: frameStart.y - offsetY)
            let line2End = CGPoint(x: frameEnd.x - offsetX, y: frameEnd.y - offsetY)
            let path2 = CGMutablePath()
            path2.move(to: line2Start)
            path2.addLine(to: line2End)
            let node2 = SKShapeNode(path: path2)
            node2.strokeColor = UIColor.lightGray
            node2.lineWidth = 1.5
            node2.lineCap = .butt
            doorsLayer.addChild(node2)

            // Draw the door swing arc in the same thin light-gray style
            // Use the actual door opening center as the hinge point
            let doorWidth = hypot(end.x - start.x, end.y - start.y)
            let arcRadius = min(doorWidth * 0.85, 45.0)
            
            // Use the actual door frame endpoint as the hinge point
            // The arc should start exactly from where the door frame meets the wall
            let hingePoint = frameStart  // Use the door frame start as hinge point
            
            // Calculate arc angles based on door orientation
            // The arc should sweep 90 degrees inward into the room
            let doorAngle = angle // angle of the door opening line
            let arcStartAngle = doorAngle
            let arcEndAngle = doorAngle - .pi / 2  // Reverse direction to open inward
            
            let arcPath = UIBezierPath(arcCenter: hingePoint,
                                       radius: arcRadius,
                                       startAngle: arcStartAngle,
                                       endAngle: arcEndAngle,
                                       clockwise: false)  // Counter-clockwise for inward opening
            let arcNode = SKShapeNode(path: arcPath.cgPath)
            arcNode.strokeColor = UIColor.lightGray
            arcNode.lineWidth = 1.5
            arcNode.lineCap = .round
            doorsLayer.addChild(arcNode)
        }
    }
    
    private func drawWindows() {
        windowsLayer.removeAllChildren()
        for window in roomStructure.windows {
            let (start, end) = calculateWallEndpoints(surface: window)
            
            // Create a white gap over the wall where the window sits
            let angle = atan2(end.y - start.y, end.x - start.x)
            let perpAngle = angle + .pi / 2
            let currentWallWidth = max(3.0, Constants.wallLineWidth / (currentScale / initialScale))
            let eraserWidth = currentWallWidth + 2.0
            let erasePath = CGMutablePath()
            erasePath.move(to: start)
            erasePath.addLine(to: end)
            let eraseNode = SKShapeNode(path: erasePath)
            eraseNode.strokeColor = .white
            eraseNode.lineWidth = eraserWidth
            eraseNode.lineCap = .butt
            windowsLayer.addChild(eraseNode)

            // Draw two light, parallel strokes as the window borders
            let offset: CGFloat = 2.0
            let offsetX = offset * cos(perpAngle)
            let offsetY = offset * sin(perpAngle)

            let line1Start = CGPoint(x: start.x + offsetX, y: start.y + offsetY)
            let line1End = CGPoint(x: end.x + offsetX, y: end.y + offsetY)
            let path1 = CGMutablePath()
            path1.move(to: line1Start)
            path1.addLine(to: line1End)
            let node1 = SKShapeNode(path: path1)
            node1.strokeColor = UIColor.lightGray
            node1.lineWidth = 1.5
            node1.lineCap = .butt
            windowsLayer.addChild(node1)

            let line2Start = CGPoint(x: start.x - offsetX, y: start.y - offsetY)
            let line2End = CGPoint(x: end.x - offsetX, y: end.y - offsetY)
            let path2 = CGMutablePath()
            path2.move(to: line2Start)
            path2.addLine(to: line2End)
            let node2 = SKShapeNode(path: path2)
            node2.strokeColor = UIColor.lightGray
            node2.lineWidth = 1.5
            node2.lineCap = .butt
            windowsLayer.addChild(node2)
        }
    }

    private func addMeasurements() {
        labelsLayer.removeAllChildren()
        
        guard showMeasurements else { return }
        
        // Add measurements for walls
        for wall in roomStructure.walls {
            addMeasurement(for: wall)
        }
        
        // Add measurements for doors
        for door in roomStructure.doors {
            addMeasurement(for: door)
        }
    }
    
    private func addMeasurement(for surface: RoomStructureData.Surface) {
        let (start, end) = calculateWallEndpoints(surface: surface)
        
        // Convert to scene coordinates (considering contentNode position and scale)
        let sceneStart = contentNode.convert(start, to: self)
        let sceneEnd = contentNode.convert(end, to: self)
        let sceneMidpoint = CGPoint(x: (sceneStart.x + sceneEnd.x) / 2, y: (sceneStart.y + sceneEnd.y) / 2)
        
        // Calculate distance in screen space to determine if label should be shown
        let screenDistance = hypot(sceneEnd.x - sceneStart.x, sceneEnd.y - sceneStart.y)
        
        let distance = hypot(end.x - start.x, end.y - start.y) / currentScale
        let meters = Float(distance)
        
        // Skip very small measurements
        guard meters > 0.1 else { return }
        
        // Calculate zoom-aware font size (like Apple Maps)
        // Scale between 8pt (zoomed out) and 14pt (zoomed in)
        let zoomRatio = currentScale / initialScale
        let minFontSize: CGFloat = 8.0
        let maxFontSize: CGFloat = 14.0
        let fontSize = min(maxFontSize, max(minFontSize, Constants.measurementFontSize * sqrt(zoomRatio)))
        
        // Hide labels if wall is too short on screen (prevents overlap)
        let minScreenDistance: CGFloat = fontSize * 3.5
        guard screenDistance > minScreenDistance else { return }
        
        // Format measurement based on unit preference
        let measurementText: String
        if useImperialUnits {
            // Convert meters to feet and inches
            let totalInches = meters * 39.3701  // 1 meter = 39.3701 inches
            let feet = Int(totalInches / 12)
            let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
            
            if feet > 0 {
                measurementText = "\(feet)' \(inches)\""
            } else {
                measurementText = "\(inches)\""
            }
        } else {
            // Metric (meters)
            measurementText = String(format: "%.1fm", meters)
        }
        
        // Calculate angle of the wall
        let wallAngle = atan2(sceneEnd.y - sceneStart.y, sceneEnd.x - sceneStart.x)
        let absAngle = abs(wallAngle)
        
        // Determine if wall is more horizontal or vertical
        let isHorizontal = absAngle < .pi / 4 || absAngle > 3 * .pi / 4
        
        // Calculate stroke width based on font size
        let strokeWidth = max(2.0, fontSize / 6.0)
        
        // Create text label with stroke for visibility
        let label = SKLabelNode(text: measurementText)
        label.position = sceneMidpoint
        label.fontSize = fontSize
        label.fontColor = .black
        label.fontName = "Helvetica-Bold"
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        
        // Add black stroke for contrast (simplified - only 4 directions for performance)
        let strokeLabel = label.copy() as! SKLabelNode
        strokeLabel.fontColor = .white
        strokeLabel.position = sceneMidpoint
        strokeLabel.zPosition = -1
        
        // Create stroke effect (4 directions instead of 8 for better performance)
        for offset in [CGPoint(x: -strokeWidth, y: 0),
                       CGPoint(x: strokeWidth, y: 0),
                       CGPoint(x: 0, y: -strokeWidth),
                       CGPoint(x: 0, y: strokeWidth)] {
            let stroke = strokeLabel.copy() as! SKLabelNode
            stroke.position = CGPoint(x: sceneMidpoint.x + offset.x, y: sceneMidpoint.y + offset.y)
            
            // Align text horizontally or vertically based on wall orientation
            if isHorizontal {
                stroke.zRotation = 0
            } else {
                stroke.zRotation = .pi / 2
            }
            
            labelsLayer.addChild(stroke)
        }
        
        // Align text horizontally or vertically based on wall orientation
        if isHorizontal {
            label.zRotation = 0
        } else {
            label.zRotation = .pi / 2
        }
        
        labelsLayer.addChild(label)
    }
    
    
    
    
    private func setupGestures(for view: SKView) {
        // Pan gesture for moving the floor plan
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.minimumNumberOfTouches = 2
        panGesture.maximumNumberOfTouches = 2
        view.addGestureRecognizer(panGesture)
        
        // Pinch gesture for zooming
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinchGesture)
        
        // Rotation gesture for rotating the floor plan
        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        view.addGestureRecognizer(rotationGesture)
        
        // Allow simultaneous gestures (pan, pinch, and rotate together)
        panGesture.delegate = self
        pinchGesture.delegate = self
        rotationGesture.delegate = self
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard gesture.numberOfTouches == 2 else { return }
        
        switch gesture.state {
        case .began:
            lastPanPosition = contentNode.position
            
        case .changed:
            let translation = gesture.translation(in: gesture.view)
            
            // Apply translation directly to content node
            let newPosition = CGPoint(
                x: lastPanPosition.x + translation.x,
                y: lastPanPosition.y - translation.y  // Invert Y for SpriteKit coordinate system
            )
            
            contentNode.position = newPosition
            
        case .ended, .cancelled:
            // Optional: Add momentum/deceleration here if desired
            break
            
        default:
            break
        }
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard gesture.state == .began || gesture.state == .changed else { return }
        
        let newScale = currentScale * gesture.scale
        let minScale = initialScale * Constants.minZoomScale
        let maxScale = initialScale * Constants.maxZoomScale
        
        if newScale >= minScale && newScale <= maxScale {
            // Apply absolute scale, not relative
            let targetScale = newScale / initialScale
            contentNode.setScale(targetScale)
            currentScale = newScale
            
            // Update measurements to stay fixed size
            addMeasurements()
        }
        
        gesture.scale = 1.0
    }
    
    @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        switch gesture.state {
        case .began, .changed:
            // Apply rotation to the content node (invert for correct direction)
            contentNode.zRotation -= gesture.rotation
            
            // Reset the gesture rotation to get incremental changes
            gesture.rotation = 0
            
        case .ended, .cancelled:
            // Optional: Add snap-to-angle behavior here if desired
            break
            
        default:
            break
        }
    }
    
    
    func zoomIn() {
        let newScale = currentScale * Constants.zoomFactor
        let maxScale = initialScale * Constants.maxZoomScale
        
        if newScale <= maxScale {
            let targetScale = newScale / initialScale
            let scaleAction = SKAction.scale(to: targetScale, duration: 0.25)
            scaleAction.timingMode = .easeInEaseOut
            contentNode.run(scaleAction) {
                self.addMeasurements()
            }
            currentScale = newScale
        }
    }
    
    func zoomOut() {
        let newScale = currentScale / Constants.zoomFactor
        let minScale = initialScale * Constants.minZoomScale
        
        if newScale >= minScale {
            let targetScale = newScale / initialScale
            let scaleAction = SKAction.scale(to: targetScale, duration: 0.25)
            scaleAction.timingMode = .easeInEaseOut
            contentNode.run(scaleAction) {
                self.addMeasurements()
            }
            currentScale = newScale
        }
    }
    
    func resetView() {
        // Reset scale
        currentScale = initialScale
        let scaleAction = SKAction.scale(to: 1.0, duration: 0.4)
        scaleAction.timingMode = .easeInEaseOut
        
        // Reset position
        let moveAction = SKAction.move(to: CGPoint(x: size.width / 2, y: size.height / 2), duration: 0.4)
        moveAction.timingMode = .easeInEaseOut
        
        // Reset rotation
        let rotateAction = SKAction.rotate(toAngle: 0, duration: 0.4)
        rotateAction.timingMode = .easeInEaseOut
        
        // Run all actions together
        let groupAction = SKAction.group([scaleAction, moveAction, rotateAction])
        contentNode.run(groupAction) {
            self.addMeasurements()
        }
    }
    
    
    func toggleMeasurements() {
        showMeasurements.toggle()
        addMeasurements()
    }
    
    func toggleUnits() {
        useImperialUnits.toggle()
        addMeasurements()
    }
}

// MARK: - UIGestureRecognizerDelegate
extension FloorPlanScene {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow pan and pinch gestures to work simultaneously
        return true
    }
}
