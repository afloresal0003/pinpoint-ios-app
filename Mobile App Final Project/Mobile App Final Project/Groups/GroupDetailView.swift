import SwiftUI
import FirebaseFirestore

struct GroupDetailView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var mapViewModel: MapViewModel
    @State var group: Group
    var onLeaveGroup: () -> Void = {}
    @State private var showMapView: Bool = false
    //@State private var memberNames: [String] = []
    @State private var memberNames: [(name: String, profileImageURL: String?)] = []
    @State private var showEditView: Bool = false
    @State private var activeAlert: ActiveAlert?
    @State private var errorMessage: String = ""
    
    // Adding this to control the active tab in the parent TabView
    @Binding var selectedTab: Int

    enum ActiveAlert: Identifiable {
        case error(String), leaveGroup

        var id: String {
            switch self {
            case .error(let message):
                return "error-\(message)"
            case .leaveGroup:
                return "leaveGroup"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            ScrollView {
                CollapsibleHeader(group: group)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Description")
                        .font(.headline)
                    Text(group.description)
                        .font(.body)
                        .multilineTextAlignment(.leading)

                    Button(action: {
                        // Fetch pins for the group then switch to the Map tab
                        if let groupId = group.id {
                            mapViewModel.fetchPins(for: groupId)
                            selectedTab = 1
                        } else {
                            print("Error: Group ID is missing.")
                        }
                    }) {
                        Text("Show Map Pins")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .padding(.top)

                    Text("Members")
                        .font(.headline)
                        .padding(.top)

//                    ForEach(Array(memberNames.enumerated()), id: \.offset) { index, name in
//                        Text("\(index + 1). \(name)")
//                            .frame(maxWidth: .infinity, alignment: .leading)
//                    }
                    ForEach(Array(memberNames.enumerated()), id: \.offset) { index, member in
                        HStack {
                            if let profileImageURL = member.profileImageURL, let url = URL(string: profileImageURL) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .clipShape(Circle()) // To make the image circular
                                        .frame(width: 40, height: 40) // Adjust size as needed
                                } placeholder: {
                                    Color.gray
                                        .frame(width: 40, height: 40) // Placeholder if no image
                                        .clipShape(Circle())
                                }
                            } else {
                                // Placeholder for missing profile image
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: 40, height: 40)
                            }

                            Text("\(index + 1). \(member.name)")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding()
            }

            Button(action: {
                activeAlert = .leaveGroup
            }) {
                Text("Leave Group")
                    .foregroundColor(.red)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor.systemBackground))
            }
        }
        .navigationBarTitle("", displayMode: .inline)
        .navigationBarItems(trailing:
            Button(action: {
                showEditView = true
            }) {
                Text("Edit")
            }
        )
        .sheet(isPresented: $showEditView) {
            NavigationView {
                EditGroupView(group: group) { updatedGroup in
                    // Update the group with the new details
                    self.group = updatedGroup
                }
            }
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .error(let message):
                return Alert(
                    title: Text("Error"),
                    message: Text(message),
                    dismissButton: .default(Text("OK")) {
                        self.errorMessage = ""
                    }
                )
            case .leaveGroup:
                return Alert(
                    title: Text("Leave Group"),
                    message: Text("Are you sure you want to leave this group? You will lose access to all group pins."),
                    primaryButton: .destructive(Text("Leave")) {
                        leaveGroup()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .onAppear(perform: fetchMemberNames)
        .sheet(isPresented: $showMapView) {
            MapsView()
                .environmentObject(mapViewModel)
                .onAppear {
                    // Fetch pins for the group
                    if let groupId = group.id {
                        mapViewModel.fetchPins(for: groupId)
                    } else {
                        print("Error: Group ID is missing.")
                    }
                }
        }
    }

    private func fetchMemberNames() {
        let db = Firestore.firestore()
        let usersCollection = db.collection("users")

        //var names: [String] = []
        var members: [(name: String, profileImageURL: String?)] = []
        let dispatchGroup = DispatchGroup()

        for memberID in group.members {
            dispatchGroup.enter()
            usersCollection.document(memberID).getDocument { document, error in
                defer {
                    dispatchGroup.leave()
                }

                if let error = error {
                    print("Error fetching user \(memberID): \(error.localizedDescription)")
                    return
                }

                if let document = document, document.exists, let data = document.data() {
                    let name = data["name"] as? String ?? "Unknown"
                    //names.append(name)
                    let profileImageURL = data["profileImageURL"] as? String
                    members.append((name: name, profileImageURL: profileImageURL))
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            self.memberNames = members
        }
    }

    private func leaveGroup() {
        guard let userID = authViewModel.user?.uid else {
            self.errorMessage = "User not authenticated."
            self.activeAlert = .error(errorMessage)
            return
        }

        let db = Firestore.firestore()
        guard let groupId = group.id else {
            print("Error: Group ID is nil.")
            self.errorMessage = "Unable to process the group. Please try again later."
            self.activeAlert = .error(errorMessage)
            return
        }

        let groupRef = db.collection("groups").document(groupId)
        let userRef = db.collection("users").document(userID)

        let batch = db.batch()

        // Remove userID from group's members array
        batch.updateData([
            "members": FieldValue.arrayRemove([userID])
        ], forDocument: groupRef)

        // Remove groupID from user's groupIDs array
        batch.updateData([
            "groupIDs": FieldValue.arrayRemove([groupId])
        ], forDocument: userRef)

        batch.commit { error in
            if let error = error {
                self.errorMessage = "Failed to leave group: \(error.localizedDescription)"
                self.activeAlert = .error(errorMessage)
            } else {
                self.presentationMode.wrappedValue.dismiss()
                self.onLeaveGroup()
            }
        }
    }

    @Environment(\.presentationMode) var presentationMode
}

struct CollapsibleHeader: View {
    let group: Group

    var body: some View {
        ZStack(alignment: .center) {
            // Background Image
            if let imageURL = group.imageURL, !imageURL.isEmpty {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .overlay(
                            Color.black.opacity(0.3)
                        )
                        .clipped()
                } placeholder: {
                    Color.gray
                        .frame(height: 200)
                }
                .id(imageURL) // Force reload when imageURL changes
            } else {
                Color.gray
                    .frame(height: 200)
            }

            // Title Text
            Text(group.name)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding()
                .multilineTextAlignment(.center)
        }
    }
}
