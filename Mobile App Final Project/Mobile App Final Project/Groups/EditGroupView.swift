//
//  EditGroupView.swift
//  Mobile App Final Project
//
//  Created by Ahmed Mahmud on 11/25/24.
//

import SwiftUI
import FirebaseFirestore
import PhotosUI
import FirebaseStorage

struct EditGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @State var group: Group
    var onSave: (Group) -> Void

    @State private var newName: String
    @State private var newDescription: String
    @State private var newImage: UIImage? = nil
    @State private var showImagePicker: Bool = false
    @State private var isSaving: Bool = false
    @State private var errorMessage: String = ""
    @State private var activeAlert: ActiveAlert?

    enum ActiveAlert: Identifiable {
        case cancel, save, error(String)
        
        var id: String {
            switch self {
            case .cancel:
                return "cancel"
            case .save:
                return "save"
            case .error(let message):
                return "error-\(message)"
            }
        }
    }

    init(group: Group, onSave: @escaping (Group) -> Void) {
        self.group = group
        self.onSave = onSave
        _newName = State(initialValue: group.name)
        _newDescription = State(initialValue: group.description)
    }

    var body: some View {
        Form {
            Section(header: Text("Group Image")) {
                Button(action: {
                    showImagePicker = true
                }) {
                    if let newImage = newImage {
                        Image(uiImage: newImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                    } else if let imageURL = group.imageURL, !imageURL.isEmpty {
                        AsyncImage(url: URL(string: imageURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
                        } placeholder: {
                            Color.gray
                                .frame(height: 200)
                        }
                    } else {
                        Color.gray
                            .frame(height: 200)
                            .overlay(
                                Text("Tap to select image")
                                    .foregroundColor(.white)
                            )
                    }
                }
            }

            Section(header: Text("Group Name")) {
                TextField("Group Name", text: $newName)
            }

            Section(header: Text("Description")) {
                TextField("Description", text: $newDescription)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
        .navigationTitle("Edit Group")
        .navigationBarItems(
            leading: Button("Cancel") {
                activeAlert = .cancel
            },
            trailing: Button("Save") {
                activeAlert = .save
            }
            .disabled(isSaving)
        )
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .cancel:
                return Alert(
                    title: Text("Discard Changes?"),
                    message: Text("Are you sure you want to discard your changes?"),
                    primaryButton: .destructive(Text("Discard")) {
                        dismiss()
                    },
                    secondaryButton: .cancel()
                )
            case .save:
                return Alert(
                    title: Text("Save Changes?"),
                    message: Text("Are you sure you want to save your changes?"),
                    primaryButton: .default(Text("Save")) {
                        saveChanges()
                    },
                    secondaryButton: .cancel()
                )
            case .error(let message):
                return Alert(
                    title: Text("Error"),
                    message: Text(message),
                    dismissButton: .default(Text("OK")) {
                        self.errorMessage = ""
                    }
                )
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $newImage)
        }
    }

    private func saveChanges() {
        guard !newName.isEmpty else {
            errorMessage = "Group name cannot be empty."
            activeAlert = .error(errorMessage)
            return
        }

        isSaving = true
        errorMessage = ""

        let db = Firestore.firestore()
        let groupsCollection = db.collection("groups")
        
        // Safely unwrap group.id
        guard let groupId = group.id else {
            // Handle the error, such as displaying an alert to the user
            print("Error: Group ID is nil.")
            self.errorMessage = "Unable to process the group. Please try again later."
            self.activeAlert = .error(errorMessage)
            isSaving = false
            return
        }

        let groupRef = db.collection("groups").document(groupId)

        // Prepare data to update
        var updatedData: [String: Any] = [
            "name": newName,
            "description": newDescription
        ]

        if let newImage = newImage {
            // Upload new image to Firebase Storage
            uploadGroupImage(groupId: groupId, image: newImage) { imageURL in
                if let imageURL = imageURL {
                    updatedData["imageURL"] = imageURL.absoluteString
                }
                updateGroupDocument(groupRef: groupRef, data: updatedData)
            }
        } else {
            // No new image selected
            updateGroupDocument(groupRef: groupRef, data: updatedData)
        }
    }

    private func uploadGroupImage(groupId: String, image: UIImage, completion: @escaping (URL?) -> Void) {
        let storageRef = Storage.storage().reference().child("groupImages/\(groupId)/group.jpg")
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            self.errorMessage = "Failed to process image."
            activeAlert = .error(errorMessage)
            completion(nil)
            return
        }

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        storageRef.putData(imageData, metadata: metadata) { metadata, error in
            if let error = error {
                self.errorMessage = "Failed to upload image: \(error.localizedDescription)"
                activeAlert = .error(errorMessage)
                completion(nil)
                return
            }

            storageRef.downloadURL { url, error in
                if let error = error {
                    self.errorMessage = "Failed to retrieve image URL: \(error.localizedDescription)"
                    activeAlert = .error(errorMessage)
                    completion(nil)
                    return
                }
                completion(url)
            }
        }
    }

    private func updateGroupDocument(groupRef: DocumentReference, data: [String: Any]) {
        groupRef.updateData(data) { error in
            isSaving = false
            if let error = error {
                self.errorMessage = "Failed to update group: \(error.localizedDescription)"
                activeAlert = .error(errorMessage)
            } else {
                // Update the local group object
                group.name = newName
                group.description = newDescription
                if let imageURL = data["imageURL"] as? String {
                    group.imageURL = imageURL
                }
                onSave(group)
                dismiss()
            }
        }
    }
}
