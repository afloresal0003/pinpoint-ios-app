// GroupsView.swift

import SwiftUI
import FirebaseFirestore

struct GroupsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var groups: [Group] = []
    @State private var showCreateGroupView = false
    @State private var showJoinGroupView = false
    @State private var showActionSheet = false
    @State private var errorMessage: String = ""
    
    @Binding var selectedTab: Int // Binding to switch tabs

    var body: some View {
        ZStack {
            List(groups, id: \.id) { group in
                NavigationLink(destination: GroupDetailView(group: group, onLeaveGroup: {
                    // Remove the group from the groups array when left
                    if let index = groups.firstIndex(where: { $0.id == group.id }) {
                        groups.remove(at: index)
                    }
                }, selectedTab: $selectedTab)) {
                    HStack {
                        if let imageURL = group.imageURL, !imageURL.isEmpty {
                            AsyncImage(url: URL(string: imageURL)) { phase in
                                switch phase {
                                case .empty:
                                    Color.gray
                                        .frame(width: 50, height: 50)
                                        .cornerRadius(5)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 50, height: 50)
                                        .clipped()
                                        .cornerRadius(5)
                                case .failure:
                                    Image(systemName: "photo")
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 50, height: 50)
                                        .foregroundColor(.gray)
                                        .background(Color.gray.opacity(0.3))
                                        .cornerRadius(5)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            Color.gray
                                .frame(width: 50, height: 50)
                                .cornerRadius(5)
                        }
                        Text(group.name)
                            .font(.headline)
                            .padding(.leading, 8)
                    }
                    .padding(.vertical, 5) // Adjusted vertical padding
                }
            }
            .listStyle(PlainListStyle())
            .onAppear(perform: fetchGroups)
            .overlay(
                // Display error message if any
                VStack {
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(8)
                            .shadow(radius: 2)
                            .padding(.top, 10)
                    }
                    Spacer()
                },
                alignment: .top
            )

            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showActionSheet = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.blue)
                            .shadow(radius: 5)
                    }
                    .padding()
                }
            }
        }
        .actionSheet(isPresented: $showActionSheet) {
            ActionSheet(title: Text("Select an option"), buttons: [
                .default(Text("Join a Group")) {
                    showJoinGroupView = true
                },
                .default(Text("Create a Group")) {
                    showCreateGroupView = true
                },
                .cancel()
            ])
        }
        .sheet(isPresented: $showCreateGroupView) {
            CreateGroupView() { newGroup in
                // Handle the new group
                groups.append(newGroup)
            }
            .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showJoinGroupView) {
            JoinGroupView { joinedGroup in
                // Handle the joined group
                groups.append(joinedGroup)
            }
            .environmentObject(authViewModel)
        }
    }

    private func fetchGroups() {
        guard let userID = authViewModel.user?.uid else {
            return
        }

        let db = Firestore.firestore()
        let usersCollection = db.collection("users")
        let groupsCollection = db.collection("groups")

        usersCollection.document(userID).getDocument { document, error in
            if let error = error {
                self.errorMessage = "Failed to fetch user data: \(error.localizedDescription)"
                return
            }

            guard let document = document, document.exists, let data = document.data() else {
                self.errorMessage = "User data not found."
                return
            }

            if let groupIDs = data["groupIDs"] as? [String] {
                var fetchedGroups: [Group] = []
                let dispatchGroup = DispatchGroup()

                for groupID in groupIDs {
                    dispatchGroup.enter()
                    groupsCollection.document(groupID).getDocument { groupDoc, error in
                        defer {
                            dispatchGroup.leave()
                        }

                        if let error = error {
                            print("Error fetching group \(groupID): \(error.localizedDescription)")
                            return
                        }

                        if let groupDoc = groupDoc, groupDoc.exists, let groupData = groupDoc.data() {
                            let group = Group(
                                id: groupID,
                                name: groupData["name"] as? String ?? "",
                                description: groupData["description"] as? String ?? "",
                                members: groupData["members"] as? [String] ?? [],
                                imageURL: groupData["imageURL"] as? String
                            )
                            fetchedGroups.append(group)
                        }
                    }
                }

                dispatchGroup.notify(queue: .main) {
                    self.groups = fetchedGroups
                }
            } else {
                self.groups = []
            }
        }
    }
}

struct GroupsView_Previews: PreviewProvider {
    static var previews: some View {
        GroupsView(selectedTab: .constant(0))
            .environmentObject(AuthViewModel()) // Provide AuthViewModel
    }
}
