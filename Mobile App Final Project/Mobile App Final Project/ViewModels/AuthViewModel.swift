//
//  AuthViewModel.swift
//  Mobile App Final Project
//
//  Created by Ahmed Mahmud on 11/23/24.
//


import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SwiftUI

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var user: User? = nil
    @Published var errorMessage: String = ""
    @Published var profileImage: UIImage? = nil
    @Published var userData: [String: Any]? = nil

    init() {
        self.user = Auth.auth().currentUser
        self.isAuthenticated = self.user != nil
        if let user = self.user {
            fetchUserData()
        }
    }

    func fetchUserData(completion: ((Bool) -> Void)? = nil) {
        guard let uid = user?.uid else {
            completion?(false)
            return
        }

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(uid)
        userRef.getDocument { (document, error) in
            DispatchQueue.main.async {
                if let document = document, document.exists {
                    self.userData = document.data()
                    if let profileImageURL = self.userData?["profileImageURL"] as? String, !profileImageURL.isEmpty {
                        self.fetchProfileImage(from: profileImageURL)
                    }
                    completion?(true)
                } else {
                    self.errorMessage = "Failed to fetch user data: \(error?.localizedDescription ?? "Unknown error")"
                    completion?(false)
                }
            }
        }
    }

    func fetchProfileImage(from urlString: String) {
        guard let url = URL(string: urlString) else {
            self.profileImage = nil
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let data = data, let image = UIImage(data: data) {
                    self.profileImage = image
                } else {
                    self.profileImage = nil
                }
            }
        }
        task.resume()
    }

    func updateUserProfile(name: String, email: String, profileImage: UIImage?, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(.failure(NSError(domain: "User not authenticated.", code: 0, userInfo: nil)))
            return
        }

        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = name

        changeRequest.commitChanges { error in
            if let error = error {
                completion(.failure(error))
                return
            }

            // Update email
            user.updateEmail(to: email) { error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                // Update Firestore user document
                let db = Firestore.firestore()
                let userRef = db.collection("users").document(user.uid)
                var data: [String: Any] = ["name": name, "email": email]

                // Upload profile image if available
                if let profileImage = profileImage {
                    self.uploadProfileImage(uid: user.uid, image: profileImage) { url in
                        if let url = url {
                            data["profileImageURL"] = url.absoluteString
                            userRef.updateData(data) { error in
                                if let error = error {
                                    completion(.failure(error))
                                    return
                                }
                                self.profileImage = profileImage
                                completion(.success(()))
                            }
                        } else {
                            completion(.failure(NSError(domain: "Failed to upload profile image.", code: 0, userInfo: nil)))
                        }
                    }
                } else {
                    userRef.updateData(data) { error in
                        if let error = error {
                            completion(.failure(error))
                            return
                        }
                        completion(.success(()))
                    }
                }
            }
        }
    }

    private func uploadProfileImage(uid: String, image: UIImage, completion: @escaping (URL?) -> Void) {
        let storageRef = Storage.storage().reference().child("profileImages/\(uid)/profile.jpg")
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            self.errorMessage = "Failed to process image."
            completion(nil)
            return
        }

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        storageRef.putData(imageData, metadata: metadata) { metadata, error in
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

    func signUp(name: String, email: String, password: String, confirmPassword: String, profileImage: UIImage?, completion: @escaping (Bool) -> Void) {
        guard password == confirmPassword else {
            self.errorMessage = "Passwords do not match."
            completion(false)
            return
        }

        // Create user with email and password
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                if let error = error as NSError? {
                    if let errorCode = AuthErrorCode(rawValue: error.code) {
                        switch errorCode {
                        case .emailAlreadyInUse:
                            self.errorMessage = "An account with this email already exists."
                        case .invalidEmail:
                            self.errorMessage = "Invalid email address."
                        case .weakPassword:
                            self.errorMessage = "Your password is too weak. Please use at least 6 characters."
                        default:
                            self.errorMessage = error.localizedDescription
                        }
                    }
                    completion(false)
                } else if let uid = result?.user.uid {
                    self.user = result?.user
                    self.isAuthenticated = true

                    let changeRequest = result?.user.createProfileChangeRequest()
                    changeRequest?.displayName = name
                    changeRequest?.commitChanges { error in
                        if let error = error {
                            self.errorMessage = "Failed to set display name: \(error.localizedDescription)"
                            completion(false)
                            return
                        }

                        // Upload profile image if available
                        if let profileImage = profileImage {
                            self.uploadProfileImage(uid: uid, image: profileImage) { url in
                                if let url = url {
                                    // Proceed to create the personal group
                                    self.createPersonalGroup(uid: uid, name: name, email: email, profileImageURL: url.absoluteString) {
                                        completion(true)
                                    }
                                } else {
                                    self.errorMessage = "Failed to upload profile image."
                                    completion(false)
                                }
                            }
                        } else {
                            // No profile image selected
                            self.createPersonalGroup(uid: uid, name: name, email: email, profileImageURL: "") {
                                completion(true)
                            }
                        }
                    }
                }
            }
        }
    }

    private func createPersonalGroup(uid: String, name: String, email: String, profileImageURL: String, completion: @escaping () -> Void) {
        let db = Firestore.firestore()
        let groupsCollection = db.collection("groups")
        let usersCollection = db.collection("users")

        // Generate a new groupId
        let groupId = groupsCollection.document().documentID

        // Create the personal group data
        let groupName = "\(name)'s Personal Group"
        let groupDescription = "Personal group for \(name)"

        var groupData: [String: Any] = [
            "name": groupName,
            "description": groupDescription,
            "creatorID": uid,
            "groupType": "personal",
            "imageURL": "", // Placeholder to be updated after uploading the image
            "members": [uid],
            "createdAt": Timestamp(date: Date())
        ]

        // Set the group document with the known groupId
        groupsCollection.document(groupId).setData(groupData) { error in
            if let error = error {
                self.errorMessage = "Failed to create personal group: \(error.localizedDescription)"
                completion()
                return
            }

            // Create the user document
            let userData: [String: Any] = [
                "name": name,
                "email": email,
                "profileImageURL": profileImageURL,
                "createdAt": Timestamp(date: Date()),
                "defaultGroupID": groupId,
                "groupIDs": [groupId]
            ]

            usersCollection.document(uid).setData(userData) { error in
                if let error = error {
                    self.errorMessage = "Failed to create user data: \(error.localizedDescription)"
                }

                // Proceed to upload the default group image
                self.fetchAndUploadDefaultGroupImage(groupId: groupId) {
                    completion()
                }
            }
        }
    }

    private func fetchAndUploadDefaultGroupImage(groupId: String, completion: @escaping () -> Void) {
        let defaultGroupImageURL = "https://firebasestorage.googleapis.com/v0/b/woodpecker-dd7b8.firebasestorage.app/o/default_group.png?alt=media&token=e79947b8-7cc6-414a-b2ee-bc9313d61d4f"

        guard let imageURL = URL(string: defaultGroupImageURL) else {
            self.errorMessage = "Invalid default group image URL."
            completion()
            return
        }

        let task = URLSession.shared.dataTask(with: imageURL) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to fetch default group image data: \(error.localizedDescription)"
                    completion()
                }
                return
            }

            guard let imageData = data else {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to fetch default group image data."
                    completion()
                }
                return
            }

            // Proceed with uploading the image data to Firebase Storage
            self.uploadGroupImage(groupId: groupId, imageData: imageData) {
                completion()
            }
        }
        task.resume()
    }

    private func uploadGroupImage(groupId: String, imageData: Data, completion: @escaping () -> Void) {
        let storageRef = Storage.storage().reference().child("groupImages/\(groupId)/group.jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        storageRef.putData(imageData, metadata: metadata) { _, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to upload default group image: \(error.localizedDescription)"
                    completion()
                }
                return
            }

            // Get the download URL for the uploaded image
            storageRef.downloadURL { url, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to retrieve uploaded group image URL: \(error.localizedDescription)"
                        completion()
                    }
                    return
                }

                guard let imageURL = url?.absoluteString else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to retrieve uploaded group image URL."
                        completion()
                    }
                    return
                }

                // Update the group document with the image URL
                let groupsCollection = Firestore.firestore().collection("groups")
                groupsCollection.document(groupId).updateData(["imageURL": imageURL]) { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.errorMessage = "Failed to update group image URL: \(error.localizedDescription)"
                        }
                        completion()
                    }
                }
            }
        }
    }

    func signIn(email: String, password: String, completion: @escaping (Bool) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                if let error = error as NSError? {
                    // Extract the error code
                    if let errorCode = AuthErrorCode(rawValue: error.code) {
                        // Map error codes to user-friendly messages
                        switch errorCode {
                        case .userNotFound:
                            self.errorMessage = "No account found for this email."
                        case .wrongPassword:
                            self.errorMessage = "Incorrect password."
                        case .invalidEmail:
                            self.errorMessage = "Invalid email address."
                        case .userDisabled:
                            self.errorMessage = "Your account has been disabled. Please contact support."
                        default:
                            self.errorMessage = error.localizedDescription
                        }
                    }
                    completion(false)
                } else {
                    self.user = result?.user
                    self.isAuthenticated = true
                    completion(true)
                }
            }
        }
    }
    
    
    func sendPasswordResetEmail(email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    func fetchProfileImage(completion: ((UIImage?) -> Void)? = nil) {
        guard let uid = user?.uid else {
            completion?(nil)
            return
        }

        let storageRef = Storage.storage().reference().child("profileImages/\(uid)/profile.jpg")
        storageRef.getData(maxSize: 4 * 1024 * 1024) { data, error in
            DispatchQueue.main.async {
                if let data = data, let image = UIImage(data: data) {
                    self.profileImage = image
                    completion?(image)
                } else {
                    self.profileImage = nil
                    completion?(nil)
                }
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.user = nil
            self.isAuthenticated = false
        } catch let signOutError as NSError {
            self.errorMessage = signOutError.localizedDescription
        }
    }
}
