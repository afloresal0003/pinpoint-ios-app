// JoinGroupView.swift
import SwiftUI
import FirebaseFirestore

struct JoinGroupView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""
    @State private var searchResults: [Group] = []
    @State private var isSearching: Bool = false
    @State private var errorMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var selectedGroup: Group?
    @State private var userGroupIDs: [String] = []
    @State private var showErrorAlert: Bool = false // For handling errors

    // Define an enum to handle different alert types
    enum ActiveAlert {
        case joinGroup
        case error
    }

    @State private var activeAlert: ActiveAlert? = nil

    var onJoin: (Group) -> Void

    var body: some View {
        NavigationView {
            List {
                ForEach(searchResults, id: \.id) { group in
                    Button(action: {
                        selectedGroup = group
                        activeAlert = .joinGroup // Set the active alert to joinGroup
                    }) {
                        HStack {
                            if let imageURL = group.imageURL, !imageURL.isEmpty {
                                AsyncImage(url: URL(string: imageURL)) { phase in
                                    switch phase {
                                    case .empty:
                                        Color.gray
                                            .frame(width: 50, height: 50)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 50, height: 50)
                                            .clipped()
                                    case .failure:
                                        Color.red // Indicate image loading failure
                                            .frame(width: 50, height: 50)
                                    @unknown default:
                                        Color.gray
                                            .frame(width: 50, height: 50)
                                    }
                                }
                            } else {
                                Color.gray
                                    .frame(width: 50, height: 50)
                            }
                            Text(group.name)
                                .foregroundColor(.primary)
                        }
                    }
                }
                if isSearching {
                    ProgressView("Searching...")
                        .padding()
                } else if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    Text("No Groups with Queried Name Found")
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Join a Group")
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
            .alert(item: $activeAlert) { alert in
                switch alert {
                case .joinGroup:
                    return Alert(
                        title: Text("Join Group"),
                        message: Text("Do you want to join '\(selectedGroup?.name ?? "")'?"),
                        primaryButton: .default(Text("Join")) {
                            if let group = selectedGroup {
                                joinGroup(group)
                            }
                        },
                        secondaryButton: .cancel()
                    )
                case .error:
                    return Alert(
                        title: Text("Error"),
                        message: Text(errorMessage),
                        dismissButton: .default(Text("OK")) {
                            self.errorMessage = ""
                        }
                    )
                }
            }
            // Remove the second .alert modifier to prevent conflicts
            .searchable(text: $searchText, prompt: "Search Groups")
            .onChange(of: searchText) { _ in
                searchGroups()
            }
            .onAppear {
                fetchUserGroups()
            }
        }
    }

    private func fetchUserGroups() {
        guard let userID = authViewModel.user?.uid else {
            self.errorMessage = "User not authenticated."
            self.activeAlert = .error
            return
        }

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userID)
        userRef.getDocument { document, error in
            if let error = error {
                self.errorMessage = "Failed to fetch user data: \(error.localizedDescription)"
                self.activeAlert = .error
                return
            }

            guard let document = document, document.exists, let data = document.data() else {
                self.errorMessage = "User data not found."
                self.activeAlert = .error
                return
            }

            self.userGroupIDs = data["groupIDs"] as? [String] ?? []
        }
    }

    private func searchGroups() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        errorMessage = ""
        searchResults = []

        let db = Firestore.firestore()
        let groupsCollection = db.collection("groups")

        // Query for custom groups
        groupsCollection
            .whereField("groupType", isEqualTo: "custom")
            .getDocuments { snapshot, error in
                self.isSearching = false
                if let error = error {
                    self.errorMessage = "Failed to search groups: \(error.localizedDescription)"
                    self.activeAlert = .error
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.errorMessage = "No groups found."
                    self.activeAlert = .error
                    return
                }

                let groups = documents.compactMap { try? $0.data(as: Group.self) }

                // Filter groups locally based on searchText (case-insensitive substring)
                self.searchResults = groups.filter { group in
                    guard let groupId = group.id else {
                        return false
                    }
                    let matchesSearchText = group.name.lowercased().contains(self.searchText.lowercased())
                    let notInUserGroups = !self.userGroupIDs.contains(groupId)
                    return matchesSearchText && notInUserGroups
                }
            }
    }

    private func joinGroup(_ group: Group) {
        guard let userID = authViewModel.user?.uid else {
            self.errorMessage = "User not authenticated."
            self.activeAlert = .error
            return
        }

        guard let groupId = group.id else {
            self.errorMessage = "Group ID is missing."
            self.activeAlert = .error
            return
        }

        let db = Firestore.firestore()
        let groupRef = db.collection("groups").document(groupId)
        let userRef = db.collection("users").document(userID)

        let batch = db.batch()

        // Add userID to group's members array
        batch.updateData([
            "members": FieldValue.arrayUnion([userID])
        ], forDocument: groupRef)

        // Add groupID to user's groupIDs array
        batch.updateData([
            "groupIDs": FieldValue.arrayUnion([groupId])
        ], forDocument: userRef)

        batch.commit { error in
            if let error = error {
                self.errorMessage = "Failed to join group: \(error.localizedDescription)"
                self.activeAlert = .error
            } else {
                // Successfully joined group
                onJoin(group)
                // Create a post for group joining
                self.createPost(for: .groupJoined, group: group)
                dismiss()
            }
        }
    }
    
    // MARK: - Post Creation

    enum EventType: String {
        case pinCreated = "pin_created"
        case reviewAdded = "review_added"
        case groupJoined = "group_joined"
    }

    private func createPost(for eventType: EventType, group: Group) {
        guard let userID = authViewModel.user?.uid else { return }
        guard let userName = authViewModel.userData?["name"] as? String else { return }
        let groupName = group.name // No need to guard as name is non-optional

        let db = Firestore.firestore()
        let postsCollection = db.collection("posts")
        let postID = postsCollection.document().documentID

        // Prepare details using PostDetails
        let details = PostDetails(
            groupName: groupName,
            placeName: "", // Not applicable for group joining
            reviewSummary: "",
            userName: userName,
            eventType: eventType.rawValue
        )

        // Create the Post instance
        let post = Post(
            id: postID,
            details: details,
            groupID: group.id ?? "",
            likeCount: 0,
            likedBy: [],
            pinID: "", // Not applicable for group joining
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

// Extend ActiveAlert to conform to Identifiable for the .alert(item:) modifier
extension JoinGroupView.ActiveAlert: Identifiable {
    var id: Int {
        switch self {
        case .joinGroup:
            return 1
        case .error:
            return 2
        }
    }
}
