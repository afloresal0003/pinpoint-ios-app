// ActivityViewModel.swift
import Foundation
import FirebaseFirestore
import FirebaseAuth

class ActivityViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var errorMessage: String = ""
    
    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    init() {
        fetchPosts()
    }
    
    deinit {
        listener?.remove()
    }
    
    func fetchPosts() {
        listener = db.collection("posts")
            .order(by: "timestamp", descending: true) // Earliest at top
            .addSnapshotListener { [weak self] (querySnapshot, error) in
                guard let self = self else { return }
                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to fetch posts: \(error.localizedDescription)"
                    }
                    return
                }
                
                self.posts = querySnapshot?.documents.compactMap { doc in
                    try? doc.data(as: Post.self)
                } ?? []
            }
    }
    
    func toggleLike(for post: Post) {
        guard let userID = Auth.auth().currentUser?.uid, let postID = post.id else { return }
        
        let postRef = db.collection("posts").document(postID)
        
        if post.likedBy.contains(userID) {
            // Unlike the post
            postRef.updateData([
                "likeCount": FieldValue.increment(Int64(-1)),
                "likedBy": FieldValue.arrayRemove([userID])
            ]) { error in
                if let error = error {
                    print("Error unliking post: \(error.localizedDescription)")
                } else {
                    print("Post unliked successfully.")
                }
            }
        } else {
            // Like the post
            postRef.updateData([
                "likeCount": FieldValue.increment(Int64(1)),
                "likedBy": FieldValue.arrayUnion([userID])
            ]) { error in
                if let error = error {
                    print("Error liking post: \(error.localizedDescription)")
                } else {
                    print("Post liked successfully.")
                }
            }
        }
    }
}
