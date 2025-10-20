# FloorPlan - LiDAR Room Scanning with Apple RoomPlan

> Minimal floor plan generation using Apple's native **RoomPlan** framework + optional custom object detection.

![iOS](https://img.shields.io/badge/iOS-16.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![RoomPlan](https://img.shields.io/badge/RoomPlan-Native-green.svg)

---

## 🎯 What This Does

**Uses Apple's RoomPlan** to automatically:

- ✅ Scan rooms with LiDAR
- ✅ Detect walls, doors, windows
- ✅ Detect 30+ furniture types
- ✅ Calculate dimensions
- ✅ **Generate 2D floor plans** (like architectural drawings)
- ✅ Export to USDZ (3D model)

**Plus optional Vision + CoreML** for:

- 🔄 Custom equipment detection (outlets, sprinklers, etc.)

**Total code: ~400 lines** instead of thousands!

---

## 📱 Requirements

- iPhone 12 Pro or later (LiDAR required)
- iOS 16.0+
- Xcode 15.0+

---

## 🏗️ Architecture

### **Simple 3-Layer Design**

```
Views (SwiftUI)
  └── RoomScanView          # Apple's RoomCaptureView wrapper
  └── RoomListView          # Browse saved scans
      ↓
Services
  └── RoomPlanService       # Apple RoomPlan wrapper
  └── ObjectDetectionService # Vision + CoreML (optional)
  └── DataService           # Save/load
      ↓
Apple Frameworks
  └── RoomPlan              # Does 99% of the work
  └── Vision + CoreML       # Custom objects (if needed)
```

### **Key Files**

| File                           | Lines    | Purpose                    |
| ------------------------------ | -------- | -------------------------- |
| `RoomPlanService.swift`        | 50       | Wraps Apple's RoomPlan     |
| `ObjectDetectionService.swift` | 78       | Vision + CoreML (optional) |
| `DataService.swift`            | 53       | Basic persistence          |
| `RoomScanView.swift`           | 98       | Main scanning UI           |
| `RoomListView.swift`           | 34       | Browse rooms               |
| `FloorPlanRenderer.swift`      | 240      | 2D floor plan drawing      |
| `ContentView.swift`            | 184      | Navigation                 |
| **Total**                      | **~640** | **vs 3,000+ manual**       |

---

## 🚀 Getting Started

### 1. Build & Run

```bash
open floorplan.xcodeproj
# Select iPhone Pro device (requires LiDAR)
# CMD + R
```

### 2. Scan a Room

- Tap "Scan" tab
- Point iPhone at walls and move slowly
- Apple's RoomPlan shows real-time 3D model
- Tap "Stop" when done
- Tap "View 2D Floor Plan" to see architectural drawing
- Save with a name

### 3. What You Get Automatically

Apple's `CapturedRoom` provides:

```swift
// Walls with dimensions
room.walls.forEach { wall in
    print("\(wall.dimensions.width)m x \(wall.dimensions.height)m")
}

// Doors with positions
room.doors.forEach { door in
    print("Door at: \(door.transform)")
}

// Windows, openings, furniture (30+ types)
room.windows // All windows
room.objects // Chairs, tables, beds, sofas, etc.

// Export as USDZ (3D model)
try room.export(to: url, exportOptions: .model)
```

---

## 🎨 What RoomPlan Detects

### **Structure (Automatic)**

- Walls + dimensions
- Doors + positions
- Windows + sizes
- Openings (doorways)
- Floor area
- Ceiling height

### **Furniture (30+ Categories)**

- storage, refrigerator, stove
- bed, sink, washer, dryer
- toilet, bathtub, oven
- dishwasher, table, sofa
- chair, fireplace, television
- stairs, and more...

**No training required!**

---

## 🔧 Add Custom Object Detection (Optional)

For objects RoomPlan doesn't detect (outlets, sprinklers, etc.):

### 1. Train a CoreML Model

```bash
# Use YOLOv8, SSD, or similar
# Train on your equipment images
# Export to CoreML format
```

### 2. Add to Xcode

```bash
# Drag YourModel.mlmodel into Xcode project
```

### 3. Load in Code

```swift
// In ObjectDetectionService.swift
func loadModel(named modelName: String) throws {
    let model = try YOLOv8(configuration: MLModelConfiguration())
    visionModel = try VNCoreMLModel(for: model.model)
    setupVisionRequest()
}
```

### 4. Detect During Scan

```swift
// Vision + CoreML detects objects
// ARKit provides 3D depth
// = Objects with 3D coordinates
```

---

## 📂 Implementation Details

### **RoomPlanService (50 lines)**

```swift
import RoomPlan

class RoomPlanService: ObservableObject {
    @Published var capturedRoom: CapturedRoom?
    let captureView = RoomCaptureView()

    func startCapture() {
        let config = RoomCaptureSession.Configuration()
        captureView.captureSession.run(configuration: config)
    }

    func stopCapture() {
        captureView.captureSession.stop()
    }
}
```

### **ObjectDetectionService (78 lines)**

```swift
import Vision
import CoreML

class ObjectDetectionService: ObservableObject {
    private var visionModel: VNCoreMLModel?

    func loadModel(named: String) throws {
        // Load your CoreML model
    }

    func detectObjects(in frame: ARFrame) async {
        // Vision + CoreML detection
    }
}
```

### **DataService (53 lines)**

```swift
class DataService: ObservableObject {
    func save(_ room: CapturedRoom, named: String) throws {
        // RoomPlan exports USDZ automatically
        try room.export(to: url, exportOptions: .model)
    }
}
```

---

## 💡 Why This Approach?

### **Before (Manual ARKit):**

- ❌ 3,000+ lines of code
- ❌ Manual mesh processing
- ❌ Manual dimension calculation
- ❌ Complex coordinate transforms
- ❌ Hard to maintain

### **Now (RoomPlan):**

- ✅ ~400 lines of code
- ✅ Apple handles everything
- ✅ More accurate
- ✅ Built-in features
- ✅ Easy to maintain

### **Apple Does:**

- Scene reconstruction
- Wall/door/window detection
- Furniture detection (30+ types)
- Dimension calculation
- 3D visualization
- USDZ export
- Coaching UI

### **You Do:**

- Wrap RoomPlan in SwiftUI
- Save/load data
- Add custom detection (optional)
- Customize UI

---

## 🎓 How It Works

### **RoomPlan Flow:**

```
1. User scans room with iPhone
   ↓
2. RoomPlan (LiDAR + AI) detects everything
   ↓
3. Real-time 3D model displayed
   ↓
4. Stop → Get CapturedRoom
   ↓
5. Export as USDZ or access structured data
```

### **Custom Detection (Optional):**

```
1. ARFrame captures RGB + Depth
   ↓
2. Vision + CoreML detects custom objects
   ↓
3. ARKit depth → 3D world positions
   ↓
4. Combine with RoomPlan data
```

---

## 🔗 Apple Documentation

- [RoomPlan Framework](https://developer.apple.com/documentation/roomplan) - Main framework
- [Vision Framework](https://developer.apple.com/documentation/vision) - Object detection
- [CoreML](https://developer.apple.com/documentation/coreml) - ML models
- [ARKit](https://developer.apple.com/documentation/arkit) - Depth data

---

## 📊 File Structure

```
floorplan/
├── Core/
│   └── Services/
│       ├── RoomPlanService.swift       # RoomPlan wrapper
│       ├── ObjectDetectionService.swift # Vision + CoreML
│       └── DataService.swift           # Save/load
├── Features/
│   ├── Scanning/Views/
│   │   └── RoomScanView.swift         # Scan UI
│   └── FloorPlans/Views/
│       └── RoomListView.swift         # List UI
├── Views/
│   └── UnsupportedView.swift          # Device check
├── ContentView.swift                  # Navigation
└── floorplanApp.swift                 # Entry point
```

---

## ✨ Next Steps

### **Basic App (Works Now):**

1. Build and run on iPhone Pro
2. Scan rooms with RoomPlan
3. Save and export USDZ

### **Add Custom Detection:**

1. Train CoreML model on your equipment
2. Add model to Xcode
3. Update `ObjectDetectionService.loadModel()`
4. Detect during scanning

### **Customize:**

1. Implement data persistence (save/load metadata)
2. Add export formats (PDF, JSON, etc.)
3. Customize UI/UX
4. Add cloud sync (optional)

---

## 🎯 Use Cases

- **Facility Management**: Building documentation, equipment tracking
- **Real Estate**: Property tours, dimension verification
- **Architecture**: Site surveys, as-built documentation
- **Interior Design**: Space planning, furniture layout

---

## 📝 Notes

- **RoomPlan requires iOS 16+** (if you need iOS 15, use manual ARKit)
- **LiDAR required** (iPhone 12 Pro or later)
- **Custom detection is optional** (RoomPlan detects 30+ objects already)
- **Export is built-in** (USDZ automatic, add more if needed)

---

**Let Apple do the heavy lifting. You focus on your features.** 🚀
