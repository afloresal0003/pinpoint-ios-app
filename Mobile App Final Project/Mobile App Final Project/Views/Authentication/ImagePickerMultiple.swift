//
//  ImagePickerMultiple.swift
//  Mobile App Final Project
//
//  Created by Ahmed Mahmud on 11/26/24.
//

import SwiftUI
import PhotosUI

struct ImagePickerMultiple: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var images: [UIImage]
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: ImagePickerMultiple
        
        init(parent: ImagePickerMultiple) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            for result in results {
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                        if let image = object as? UIImage {
                            DispatchQueue.main.async {
                                self.parent.images.append(image) // Removed fixOrientation()
                            }
                        }
                    }
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 0 // 0 for unlimited selection
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // No update needed
    }
}

