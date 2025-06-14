// ActivityView.swift
import SwiftUI
import FirebaseFirestore
import MapKit

struct ActivityView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var selectedTab: Int // Binding to switch tabs
    @StateObject private var viewModel = ActivityViewModel()
    
    var body: some View {
        List {
            if viewModel.posts.isEmpty {
                if viewModel.errorMessage.isEmpty {
                    Text("No activity yet.")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    Text(viewModel.errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
            } else {
                ForEach(viewModel.posts) { post in
                    PostView(post: post, selectedTab: $selectedTab)
                        .environmentObject(viewModel) // Inject ViewModel
                }
            }
        }
        .listStyle(PlainListStyle())
        // Removed .navigationBarHidden(true) as NavigationView is managed by MainTabView
        .onAppear {
            // Additional setup if needed
        }
    }
}

struct PostView: View {
    var post: Post
    @Binding var selectedTab: Int // Binding for tab switching
    @EnvironmentObject var authViewModel: AuthViewModel // To access current user ID
    @EnvironmentObject var viewModel: ActivityViewModel // Access to ActivityViewModel
    @StateObject private var groupFetcher = GroupFetcher() // to get group for navigation from post clicks
    @State private var group: Group? = nil // State to hold the fetched group
    @EnvironmentObject var mapViewModel: MapViewModel // Add MapViewModel
    
    // Define the image URLs
    private let newPinImageURL = URL(string: "https://firebasestorage.googleapis.com/v0/b/woodpecker-dd7b8.firebasestorage.app/o/feedImages%2Fpngtree-pin-map-graphic-icon-design-template-png-image_316195.jpg?alt=media&token=3cdb6444-290a-4f4e-8785-c8d31cc84180")!
    private let newReviewImageURL = URL(string: "https://firebasestorage.googleapis.com/v0/b/woodpecker-dd7b8.firebasestorage.app/o/feedImages%2Fss-rating-review-stars-800x450.jpg?alt=media&token=e6ace7af-85ab-4a8b-b6f2-c810c37d4983")!
    private let newUserImageURL = URL(string: "https://firebasestorage.googleapis.com/v0/b/woodpecker-dd7b8.firebasestorage.app/o/feedImages%2Fuser.png?alt=media&token=6d91f2ba-77c9-4d56-8385-f6fb793a5d92")!
    private let defaultImageURL = URL(string: "https://cdn-icons-png.flaticon.com/512/8635/8635263.png")! // Fallback image
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image based on eventType
            AsyncImage(url: getImageURL(for: post.details.eventType)) { phase in
                switch phase {
                case .empty:
                    Color.gray
                        .frame(height: 200)
                        .cornerRadius(10)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 200)
                        .clipped()
                        .cornerRadius(10)
                case .failure:
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 200)
                        .foregroundColor(.gray)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(10)
                @unknown default:
                    EmptyView()
                }
            }
            
            // Like Button and Like Count
            HStack {
                Button(action: {
                    viewModel.toggleLike(for: post)
                }) {
                    Image(systemName: post.likedBy.contains(authViewModel.user?.uid ?? "") ? "heart.fill" : "heart")
                        .foregroundColor(post.likedBy.contains(authViewModel.user?.uid ?? "") ? .red : .gray)
                        .padding(.trailing, 4)
                }
                .buttonStyle(PlainButtonStyle())
                Text("\(post.likeCount)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.top, 4)
            
            // Description and NavigationLink in the same line
            HStack {
                getDescription()
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if post.details.eventType.lowercased() == "pin_created" || post.details.eventType.lowercased() == "review_added" {
                    Button(action: {
                        navigateToPin()
                    }) {
                        HStack {
                            Text("View Pin")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .opacity(0.0)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(width: 80)
                }
                
                if post.details.eventType.lowercased() == "group_joined" || post.details.eventType.lowercased() == "default" {
                    if let group = groupFetcher.group {
                        NavigationLink(
                            destination: GroupDetailView(group: group, selectedTab: $selectedTab)
                        ) {
                            Text("View Group") // Add a descriptive label
                                .font(.headline)
                                .foregroundColor(.blue)
                                .opacity(0.0) // Make the link invisible but still tappable
                        }
                        .frame(width: 80)
                    } else {
                        Text("Loading group details...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .frame(width: 80)
                    }
                }
            }
        }
        .onAppear() {
            if groupFetcher.group == nil {
                groupFetcher.fetchGroup(by: post.groupID)
            }
        }
    }
    
    // Function to navigate to the pin on the map
    private func navigateToPin() {
        if !post.pinID.isEmpty {
            // You have two options: use address or GeoPoint (we'll assume GeoPoint for now)
            if let pin = mapViewModel.pins.first(where: { $0.id == post.pinID }) {
                let location = pin.location
                let latitude = location.latitude
                let longitude = location.longitude
                let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                mapViewModel.setRegionForPin(coordinate)
                selectedTab = 1 // Switch to Map tab
            } else {
                // Handle the case where pin wasn't found
                print("Pin not found!")
            }
        }
    }
    
    // Function to map eventType to image URLs
    private func getImageURL(for eventType: String) -> URL {
        switch eventType.lowercased() {
        case "pin_created":
            return newPinImageURL
        case "review_added":
            return newReviewImageURL
        case "group_joined":
            return newUserImageURL
        default:
            return defaultImageURL
        }
    }
    
    // Function to generate the description text based on eventType
    private func getDescription() -> Text {
        let timeAgo = calculateTimeAgo()
        
        switch post.details.eventType.lowercased() {
        case "pin_created":
            return Text(post.details.userName)
                .bold()
                .foregroundColor(.primary) +
                Text(" (\(post.details.groupName)) created a new pin at \(post.details.placeName) \(timeAgo).")
                .foregroundColor(.gray)
        case "review_added":
            return Text(post.details.userName)
                .bold()
                .foregroundColor(.primary) +
                Text(" (\(post.details.groupName)) added a new review to \(post.details.placeName) \(timeAgo).")
                .foregroundColor(.gray)
        case "group_joined":
            return Text(post.details.userName)
                .bold()
                .foregroundColor(.primary) +
                Text(" joined (\(post.details.groupName)) \(timeAgo).")
                .foregroundColor(.gray)
        default:
            return Text(post.details.userName)
                .bold()
                .foregroundColor(.primary) +
                Text(" (\(post.details.groupName)) performed an action \(timeAgo).")
                .foregroundColor(.gray)
        }
    }
    
    // Function to calculate time ago in seconds, minutes, or hours
    private func calculateTimeAgo() -> String {
        let now = Date()
        let interval = now.timeIntervalSince(post.timestamp)
        
        if interval < 60 {
            let seconds = Int(interval)
            return "\(seconds) second\(seconds != 1 ? "s" : "") ago"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes != 1 ? "s" : "") ago"
        } else {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours != 1 ? "s" : "") ago"
        }
    }
}

struct ActivityView_Previews: PreviewProvider {
    @State static var selectedTab = 1 // Example starting tab
    static var previews: some View {
        ActivityView(selectedTab: $selectedTab)
            .environmentObject(AuthViewModel()) // Provide AuthViewModel
            .environmentObject(ActivityViewModel()) // Provide ActivityViewModel
    }
}
