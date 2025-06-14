// AddReviewView.swift
import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

struct AddReviewView: View {
    var pin: Pin
    @EnvironmentObject var viewModel: MapViewModel
    @EnvironmentObject var authViewModel: AuthViewModel // Inject AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var priceRating: Int = 1
    @State private var overallRating: Int = 1
    @State private var notes: String = ""
    @State private var images: [UIImage] = []
    @State private var showImagePicker = false
    @State private var errorMessage: String = ""
    @State private var successMessage: String = ""
    @State private var isSubmitting: Bool = false // To prevent multiple submissions

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Ratings")) {
                    Stepper("Price Rating: \(priceRating)", value: $priceRating, in: 1...3)
                    Stepper("Overall Rating: \(overallRating)", value: $overallRating, in: 1...5)
                    
                    if let pinPricingLevel = pin.pricingLevel {
                        Text("Pricing Level: \(String(repeating: "$", count: pinPricingLevel))")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
                
                Section(header: Text("Images")) {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(images, id: \.self) { image in
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipped()
                            }
                            Button(action: {
                                showImagePicker = true
                            }) {
                                Image(systemName: "plus.circle")
                                    .resizable()
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
                
                if !successMessage.isEmpty {
                    Text(successMessage)
                        .foregroundColor(.green)
                }
            }
            .navigationTitle("Add Review")
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }, trailing: Button("Submit") {
                submitReview()
            }
            .disabled(isSubmitting)) // Disable button while submitting
            .sheet(isPresented: $showImagePicker) {
                ImagePickerMultiple(images: $images)
            }
            .alert(isPresented: Binding<Bool>(
                get: { !errorMessage.isEmpty || !successMessage.isEmpty },
                set: { _ in
                    errorMessage = ""
                    successMessage = ""
                }
            )) {
                if !errorMessage.isEmpty {
                    return Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
                } else {
                    return Alert(title: Text("Success"), message: Text(successMessage), dismissButton: .default(Text("OK")) {
                        presentationMode.wrappedValue.dismiss()
                    })
                }
            }
        }
    }
    
    private func submitReview() {
        guard !isSubmitting else { return } // Prevent multiple submissions
        isSubmitting = true
        
        guard let pinID = pin.id else {
            self.errorMessage = "Invalid Pin ID."
            self.isSubmitting = false
            return
        }
        
        guard let userID = authViewModel.user?.uid else {
            self.errorMessage = "User not authenticated."
            self.isSubmitting = false
            return
        }
        
        let db = Firestore.firestore()
        let reviewID = db.collection("reviews").document().documentID
        let createdAt = Date()
        let reviewData: [String: Any] = [
            "pinID": pinID,
            "userID": userID,
            "priceRating": priceRating,
            "overallRating": overallRating,
            "notes": notes,
            "imageURLs": [], // To be updated after image upload
            "createdAt": Timestamp(date: createdAt),
            "groupIDs": pin.groupIDs
        ]
        
        db.collection("reviews").document(reviewID).setData(reviewData) { error in
            if let error = error {
                errorMessage = "Error submitting review: \(error.localizedDescription)"
                self.isSubmitting = false
            } else {
                // Upload images if any
                if images.isEmpty {
                    // Create a post for review addition
                    self.createPost(for: .reviewAdded, pin: pin, groupIDs: pin.groupIDs, reviewSummary: notes)
                    successMessage = "Review submitted successfully."
                    self.isSubmitting = false
                } else {
                    uploadImages(reviewID: reviewID) { success in
                        if success {
                            // Create a post for review addition after images are uploaded
                            self.createPost(for: .reviewAdded, pin: pin, groupIDs: pin.groupIDs, reviewSummary: notes)
                            successMessage = "Review and images submitted successfully."
                        } else {
                            errorMessage = "Failed to upload some images."
                        }
                        self.isSubmitting = false
                    }
                }
            }
        }
    }
    
    private func uploadImages(reviewID: String, completion: @escaping (Bool) -> Void) {
        let storageRef = Storage.storage().reference()
        var imageURLs: [String] = []
        let dispatchGroup = DispatchGroup()
        var uploadSuccess = true
        
        for (index, image) in images.enumerated() {
            dispatchGroup.enter()
            let imageRef = storageRef.child("reviewImages/\(reviewID)/image\(index).jpg")
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                dispatchGroup.leave()
                continue
            }
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            imageRef.putData(imageData, metadata: metadata) { _, error in
                if let error = error {
                    print("Error uploading image \(index): \(error.localizedDescription)")
                    uploadSuccess = false
                    dispatchGroup.leave()
                    return
                }
                
                imageRef.downloadURL { url, error in
                    if let url = url {
                        imageURLs.append(url.absoluteString)
                    } else {
                        uploadSuccess = false
                    }
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if uploadSuccess {
                // Update the review document with image URLs
                let db = Firestore.firestore()
                db.collection("reviews").document(reviewID).updateData(["imageURLs": imageURLs]) { error in
                    if let error = error {
                        print("Error updating review with image URLs: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        completion(true)
                    }
                }
            } else {
                completion(false)
            }
        }
    }
    
    // MARK: - Post Creation
    
    enum EventType: String {
        case pinCreated = "pin_created"
        case reviewAdded = "review_added"
        case groupJoined = "group_joined"
    }
    
    private func createPost(for eventType: EventType, pin: Pin, groupIDs: [String], reviewSummary: String) {
        guard let userID = authViewModel.user?.uid else { return }
        guard let userName = authViewModel.userData?["name"] as? String else { return }
    
        let db = Firestore.firestore()
        let postsCollection = db.collection("posts")
        let postID = postsCollection.document().documentID
    
        for groupID in groupIDs {
            // Fetch group name
            db.collection("groups").document(groupID).getDocument { groupDoc, error in
                let groupName = groupDoc?.data()?["name"] as? String ?? "Unknown Group"
    
                // Prepare details using PostDetails
                let details = PostDetails(
                    groupName: groupName,
                    placeName: pin.name,
                    reviewSummary: reviewSummary,
                    userName: userName,
                    eventType: eventType.rawValue
                )
    
                // Create the Post instance
                let post = Post(
                    id: postID,
                    details: details,
                    groupID: groupID,
                    likeCount: 0,
                    likedBy: [],
                    pinID: pin.id ?? "",
                    timestamp: Date(),
                    userID: userID
                )
    
                // Add the post document using Codable
                do {
                    try postsCollection.document(postID).setData(from: post) { error in
                        if let error = error {
                            print("Error creating post: \(error.localizedDescription)")
                        } else {
                            print("Post created successfully for event type: \(eventType.rawValue)")
                        }
                    }
                } catch {
                    print("Error encoding post: \(error.localizedDescription)")
                }
            }
        }
    }
}
