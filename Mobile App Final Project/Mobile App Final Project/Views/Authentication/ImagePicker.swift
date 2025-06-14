//
//  ImagePicker.swift
//  Mobile App Final Project
//
//  Created by Ahmed Mahmud on 11/23/24.
//

import SwiftUI
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var configuration: PHPickerConfiguration

    init(image: Binding<UIImage?>) {
        _image = image
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        self.configuration = config
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // No update needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
                return
            }

            provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                if let uiImage = image as? UIImage {
                    DispatchQueue.main.async {
                        self?.parent.image = uiImage // Removed fixOrientation()
                    }
                }
            }
        }
    }
}
