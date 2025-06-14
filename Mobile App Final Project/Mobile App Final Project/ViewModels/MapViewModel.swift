// MapViewModel.swift
import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import MapKit
import Combine

// MARK: - CLPlacemark Extension for Formatted Address
extension CLPlacemark {
    var formattedAddress: String {
        let addressLines = [
            subThoroughfare,      // Street number
            thoroughfare,         // Street name
            locality,             // City
            administrativeArea,   // State
            postalCode,           // ZIP code
            country               // Country
        ]
        return addressLines.compactMap { $0 }.joined(separator: ", ")
    }
}

// MARK: - LocationManager for User Location Handling
class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    @Published var lastKnownLocation: CLLocationCoordinate2D?
    private var manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        checkLocationAuthorization()
    }

    func checkLocationAuthorization() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            print("Location restricted or denied.")
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        @unknown default:
            print("Unknown location authorization status.")
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            lastKnownLocation = location.coordinate
        }
    }
}

class MapViewModel: ObservableObject {
    @Published var region: MKCoordinateRegion?
    @Published var pins: [Pin] = []
    @Published var annotations: [PinAnnotation] = []
    @Published var availableGroups: [Group] = []
    @Published var selectedPin: Pin? = nil // Tracks the currently selected pin
    @Published var locationManager = LocationManager() // Added LocationManager

    var authViewModel: AuthViewModel? // Injected AuthViewModel

    private var userGroupIDs: [String] = []
    private var cancellables = Set<AnyCancellable>()

    // Initializer
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        fetchAvailableGroups()
        fetchPins()
    }

    // New function to set the region for the map to show a specific pin from activity tab
    func setRegionForPin(_ coordinate: CLLocationCoordinate2D) {
        self.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 10000,
            longitudinalMeters: 10000
        )
    }

    // New function to add a pin at the user's current location
    func addPinAtCurrentLocation(completion: @escaping (Bool) -> Void) {
        guard let coordinate = locationManager.lastKnownLocation else {
            print("Current location is not available.")
            completion(false)
            return
        }
        addPin(coordinate: coordinate, completion: completion)
    }

    // Fetch user's group IDs
    func fetchUserGroupIDs(completion: @escaping () -> Void) {
        guard let userID = authViewModel?.user?.uid else {
            completion()
            return
        }

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userID)
        userRef.getDocument { [weak self] document, error in
            if let document = document, document.exists, let data = document.data() {
                self?.userGroupIDs = data["groupIDs"] as? [String] ?? []
            } else {
                print("Error fetching user groups: \(String(describing: error))")
            }
            completion()
        }
    }

    // Fetch available groups for the user
    func fetchAvailableGroups() {
        guard let userID = authViewModel?.user?.uid else { return }
        let db = Firestore.firestore()
        db.collection("groups")
            .whereField("members", arrayContains: userID)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching groups: \(error.localizedDescription)")
                    return
                }

                if let documents = snapshot?.documents {
                    self.availableGroups = documents.compactMap { try? $0.data(as: Group.self) }
                }
            }
    }

    // Fetch pins based on user's groups or specific group
    func fetchPins(for groupID: String? = nil) {
        fetchUserGroupIDs { [weak self] in
            guard let self = self else { return }
            let db = Firestore.firestore()
            var query: Query = db.collection("pins")

            if let groupID = groupID {
                query = query.whereField("groupIDs", arrayContains: groupID)
            } else {
                if self.userGroupIDs.isEmpty {
                    // If user belongs to no groups, fetch no pins
                    self.pins = []
                    self.annotations = []
                    return
                }
                query = query.whereField("groupIDs", arrayContainsAny: self.userGroupIDs)
            }

            query.getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching pins: \(error)")
                } else {
                    self.pins = snapshot?.documents.compactMap { try? $0.data(as: Pin.self) } ?? []

                    // Convert Pin instances to PinAnnotation
                    self.annotations = self.pins.map { PinAnnotation(pin: $0) }
                }
            }
        }
    }

    // Perform search using MKLocalSearch
    func performSearch(query: String, completion: @escaping ([Pin]) -> Void) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region ?? MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060), // Default to NYC
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )

        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            guard let self = self else { return }
            guard let response = response, let item = response.mapItems.first else {
                print("No results found or an error occurred: \(String(describing: error))")
                completion([])
                return
            }
            
            // Convert `MKMapItem` results to `Pin` objects
            let pins = response.mapItems.map { item -> Pin in
                Pin(
                    id: UUID().uuidString,
                    name: item.name ?? "Unknown",
                    address: item.placemark.formattedAddress,
                    location: GeoPoint(latitude: item.placemark.coordinate.latitude, longitude: item.placemark.coordinate.longitude),
                    groupIDs: [],
                    createdAt: Timestamp(date: Date()),
                    isAdded: false // Common locations start as not user-added
                )
            }

            completion(pins)

            DispatchQueue.main.async {
                self.region = MKCoordinateRegion(
                    center: item.placemark.coordinate,
                    latitudinalMeters: 10000,
                    longitudinalMeters: 10000
                )

                let newPinID = UUID().uuidString // Generate a unique ID
                let newPin = Pin(
                    id: newPinID, // Assign the generated ID
                    name: "New Pin", // Initially marked as not added
                    address: item.placemark.formattedAddress,
                    location: GeoPoint(latitude: item.placemark.coordinate.latitude, longitude: item.placemark.coordinate.longitude),
                    groupIDs: [], // Will be updated by the user
                    createdAt: Timestamp(date: Date()),
                    isAdded: false
                )

                self.pins.append(newPin)
                let annotation = PinAnnotation(pin: newPin)
                self.annotations.append(annotation)
                self.selectedPin = newPin // Automatically select the new pin to show detail view

                // Save the new pin to Firestore
                self.addPin(pin: newPin) { success in
                    if success {
                        // PinDetailView will be presented automatically via selectedPin binding
                        print("New pin added successfully.")
                    } else {
                        print("Failed to add new pin.")
                    }
                }
            }
        }
    }

    // Add a new pin to Firestore
    func addPin(pin: Pin, completion: @escaping (Bool) -> Void) {
        guard let pinID = pin.id else {
            print("Pin ID is nil.")
            completion(false)
            return
        }

        let db = Firestore.firestore()
        let pinRef = db.collection("pins").document(pinID)

        // Manually create the data dictionary excluding the 'id' field
        let pinData: [String: Any] = [
            "name": pin.name,
            "address": pin.address,
            "location": pin.location,
            "groupIDs": pin.groupIDs,
            "createdAt": pin.createdAt,
            "isAdded": pin.isAdded ?? false
        ]

        pinRef.setData(pinData) { error in
            if let error = error {
                print("Error adding pin to Firestore: \(error)")
                completion(false)
            } else {
                DispatchQueue.main.async {
                    if let index = self.pins.firstIndex(where: { $0.id == pinID }) {
                        self.pins[index] = pin
                        // Update the corresponding annotation
                        if index < self.annotations.count {
                            self.annotations[index] = PinAnnotation(pin: pin)
                        }
                    } else {
                        self.pins.append(pin)
                        self.annotations.append(PinAnnotation(pin: pin))
                    }
                    self.selectedPin = pin // Automatically select the new pin
                }

                // Create a post document for pin creation
                self.createPost(for: .pinCreated, pin: pin, groupIDs: pin.groupIDs, reviewSummary: "")
                completion(true)
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
        guard let userID = authViewModel?.user?.uid else { return }
        guard let userName = authViewModel?.userData?["name"] as? String else { return }

        let db = Firestore.firestore()
        let postsCollection = db.collection("posts")
        let postID = postsCollection.document().documentID

        for groupID in groupIDs {
            // Fetch group name
            db.collection("groups").document(groupID).getDocument { groupDoc, error in
                let groupName = groupDoc?.data()?["name"] as? String ?? "Unknown Group"

                // Prepare details map using PostDetails
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

    // MARK: - New Function to Add Pin via Coordinate

    func addPin(coordinate: CLLocationCoordinate2D, completion: @escaping (Bool) -> Void) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else {
                completion(false)
                return
            }

            if let error = error {
                print("Reverse geocoding failed: \(error.localizedDescription)")
                completion(false)
                return
            }

            guard let placemark = placemarks?.first else {
                print("No placemark found.")
                completion(false)
                return
            }

            let address = placemark.formattedAddress

            let newPinID = UUID().uuidString
            let newPin = Pin(
                id: newPinID,
                name: placemark.name ?? "New Pin",
                address: address,
                location: GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude),
                groupIDs: [], // Will be updated by the user
                createdAt: Timestamp(date: Date()),
                isAdded: false
            )

            self.addPin(pin: newPin) { success in
                completion(success)
            }
        }
    }
}
