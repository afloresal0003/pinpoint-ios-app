import SwiftUI
import MapKit
import FirebaseFirestore

struct MapsView: View {
    @EnvironmentObject var viewModel: MapViewModel
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var searchQuery = ""
    @State private var filteredPins: [Pin] = [] // Combined results
    @State private var commonLocations: [Pin] = [] // Dynamic locations from MapKit
    @State private var selectedPin: Pin? = nil
    @State private var profileImage: UIImage? = nil

    
    var body: some View {
        ZStack {
            // Map View
            MapView(viewModel: viewModel, selectedPin: $selectedPin)
                .edgesIgnoringSafeArea(.all)
        
            VStack(spacing: 0) {
                ZStack {
                    // Background for the entire search bar and buttons
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemGray6))
                        .frame(height: 40)
                        .padding(.horizontal, 16)

                    HStack {
                        // Left Button (Plus)
                        Button(action: {
                            addPinAtCurrentLocation()
                        }) {
                            Image(systemName: "plus")
                                .foregroundColor(.blue)
                                .padding(10)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(radius: 5) // Shadow for button
                        }
                        .frame(width: 40, height: 40)
                        .padding(.leading, 8)

                        // Search Bar
                        TextField("Search", text: $searchQuery)
                            .onChange(of: searchQuery) { newQuery in
                                performSearch(query: newQuery)
                            }
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)

                        // Right Button (Profile)
                        NavigationLink(destination: SettingsView().environmentObject(authViewModel)) {
                            if let profileImage = profileImage {
                                Image(uiImage: profileImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 35, height: 35)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .foregroundColor(.blue)
                                    .frame(width: 35, height: 35)
                            }
                        }
                        .frame(width: 35, height: 35)
                        .padding(.trailing, 8)
                    }
                    .padding(.horizontal, 8) //Buttons and search bar
                }
                .padding(.horizontal, 16) 


                // Combined Search Results
                if !filteredPins.isEmpty || !commonLocations.isEmpty {
                    List {
                        // User-Added Pins
                        Section(header: Text("Your Pins")) {
                            ForEach(filteredPins, id: \.id) { pin in
                                PinRow(pin: pin, isCommon: false, onSelect: selectPin)
                            }
                        }

                        // Common Locations
                        Section(header: Text("Common Locations")) {
                            ForEach(commonLocations, id: \.id) { pin in
                                PinRow(pin: pin, isCommon: true, onSelect: selectPin)
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                    .background(Color.white)
                    .cornerRadius(8)
                    .shadow(radius: 5)
                    .padding(.horizontal)
                }

                Spacer()
            }

            // Pin Detail Popup
            if let pin = selectedPin {
                PinDetailView(pin: pin, viewModel: viewModel, isPresented: $selectedPin)
                    .transition(.move(edge: .bottom))
                    .animation(.easeInOut)
            }
        }
        .onAppear {
            viewModel.fetchPins()
            fetchUserProfileImage()
        }
    }

    /// Perform search for user pins and common locations
    private func performSearch(query: String) {
        // Filter user-added pins
        filteredPins = viewModel.pins.filter { pin in
            pin.name.lowercased().contains(query.lowercased()) ||
            pin.address.lowercased().contains(query.lowercased())
        }

        // Search for common locations using MapKit
        viewModel.performSearch(query: query) { locations in
            commonLocations = locations
        }
    }
    
    private func fetchUserProfileImage() {
        let db = Firestore.firestore()
        guard let userID = authViewModel.user?.uid else {
            print("User ID not found.")
            return
        }

        let usersCollection = db.collection("users")

        usersCollection.document(userID).getDocument { document, error in
            if let error = error {
                print("Error fetching user profile image: \(error.localizedDescription)")
                return
            }

            if let document = document, document.exists, let data = document.data() {
                if let profileImageURL = data["profileImageURL"] as? String {
                    fetchImage(from: profileImageURL) { image in
                        DispatchQueue.main.async {
                            self.profileImage = image
                        }
                    }
                }
            }
        }
    }

    private func fetchImage(from url: String, completion: @escaping (UIImage?) -> Void) {
        guard let imageURL = URL(string: url) else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: imageURL) { data, response, error in
            if let error = error {
                print("Error fetching image: \(error.localizedDescription)")
                completion(nil)
                return
            }

            if let data = data, let image = UIImage(data: data) {
                completion(image)
            } else {
                completion(nil)
            }
        }.resume()
    }


    /// Handle pin selection
    private func selectPin(_ pin: Pin) {
        selectedPin = pin
        viewModel.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: pin.location.latitude,
                longitude: pin.location.longitude
            ),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        searchQuery = ""
        filteredPins = []
        commonLocations = []
    }

    /// Add a pin at the user's current location
    private func addPinAtCurrentLocation() {
        guard let currentLocation = viewModel.locationManager.lastKnownLocation else {
            print("Current location is not available.")
            return
        }

        viewModel.addPin(coordinate: currentLocation) { success in
            if success {
                print("Pin added successfully at the current location.")
            } else {
                print("Failed to add pin at the current location.")
            }
        }
    }
}
