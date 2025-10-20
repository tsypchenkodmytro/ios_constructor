//
//  ModelViewer3D.swift
//  floorplan
//
//  3D model viewer using QuickLook
//

import SwiftUI
import QuickLook

struct ModelViewer3D: View {
    let url: URL
    let roomName: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            QuickLookPreview(url: url, roomName: roomName, dismiss: dismiss)
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle(roomName)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                Text("Close")
                            }
                        }
                    }
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

