//
//  CreateGroupView.swift
//  Mobile App Final Project
//
//  Created by Ahmed Mahmud on 11/25/24.
//


import SwiftUI
import FirebaseFirestore
import FirebaseStorage

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var groupName: String = ""
    @State private var groupDescription: String = ""
    @State private var groupImage: UIImage? = nil
    @State private var showImagePicker: Bool = false
    @State private var isCreating: Bool = false
    @State private var errorMessage: String = ""

    var onCreate: (Group) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Group Image")) {
                    Button(action: {
                        showImagePicker = true
                    }) {
                        if let groupImage = groupImage {
                            Image(uiImage: groupImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
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
                    TextField("Group Name", text: $groupName)
                }

                Section(header: Text("Description")) {
                    TextField("Description", text: $groupDescription)
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Create Group")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Create") {
                    createGroup()
                }
                .disabled(isCreating)
            )
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $groupImage)
            }
        }
    }

    private func createGroup() {
        guard !groupName.isEmpty else {
            errorMessage = "Group name cannot be empty."
            return
        }

        isCreating = true
        errorMessage = ""

        guard let userID = authViewModel.user?.uid else {
            errorMessage = "User not authenticated."
            isCreating = false
            return
        }

        let db = Firestore.firestore()
        let storage = Storage.storage()
        let groupsCollection = db.collection("groups")
        let usersCollection = db.collection("users")

        // Generate a new groupId
        let groupId = groupsCollection.document().documentID

        var groupData: [String: Any] = [
            "name": groupName,
            "description": groupDescription,
            "creatorID": userID,
            "groupType": "custom",
            "imageURL": "", // Placeholder to be updated after uploading the image
            "members": [userID],
            "createdAt": Timestamp(date: Date())
        ]

        // Set the group document with the known groupId
        groupsCollection.document(groupId).setData(groupData) { error in
            if let error = error {
                self.errorMessage = "Failed to create group: \(error.localizedDescription)"
                self.isCreating = false
                return
            }

            // Update the user's groupIDs array
            usersCollection.document(userID).updateData([
                "groupIDs": FieldValue.arrayUnion([groupId])
            ]) { error in
                if let error = error {
                    self.errorMessage = "Failed to update user data: \(error.localizedDescription)"
                    self.isCreating = false
                    return
                }

                // Proceed to upload the group image if available
                if let groupImage = groupImage {
                    self.uploadGroupImage(groupId: groupId, image: groupImage) { imageURL in
                        self.isCreating = false
                        if let imageURL = imageURL {
                            // Update the group document with the image URL
                            groupsCollection.document(groupId).updateData(["imageURL": imageURL.absoluteString]) { error in
                                if let error = error {
                                    self.errorMessage = "Failed to update group image URL: \(error.localizedDescription)"
                                    return
                                }
                                // Successfully created group
                                let newGroup = Group(id: groupId, name: groupName, description: groupDescription, members: [userID], imageURL: imageURL.absoluteString)
                                onCreate(newGroup)
                                dismiss()
                            }
                        } else {
                            self.errorMessage = "Failed to upload group image."
                        }
                    }
                } else {
                    // No image to upload
                    self.isCreating = false
                    // Successfully created group
                    let newGroup = Group(id: groupId, name: groupName, description: groupDescription, members: [userID], imageURL: "")
                    onCreate(newGroup)
                    dismiss()
                }
            }
        }
    }

    private func uploadGroupImage(groupId: String, image: UIImage, completion: @escaping (URL?) -> Void) {
        let storageRef = Storage.storage().reference().child("groupImages/\(groupId)/group.jpg")
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            self.errorMessage = "Failed to process image."
            completion(nil)
            return
        }

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        storageRef.putData(imageData, metadata: metadata) { _, error in
            if let error = error {
                self.errorMessage = "Failed to upload image: \(error.localizedDescription)"
                completion(nil)
                return
            }

            storageRef.downloadURL { url, error in
                if let error = error {
                    self.errorMessage = "Failed to retrieve image URL: \(error.localizedDescription)"
                    completion(nil)
                    return
                }
                completion(url)
            }
        }
    }
}
