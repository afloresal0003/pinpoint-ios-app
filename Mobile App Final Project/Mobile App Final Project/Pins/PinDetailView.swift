// PinDetailView.swift
import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct PinDetailView: View {
    var pin: Pin
    @ObservedObject var viewModel: MapViewModel
    @Binding var isPresented: Pin?
    
    // State Variables for Managing Reviews and Groups
    @State private var showAddReviewView = false
    @State private var showReviewsView = false // New state variable
    @State private var showAddReviewAfterAddPin: Bool = false
    @State private var groupNames: [String: String] = [:]
    @State private var averageRatings: [String: Double] = [:]
    
    // State Variables for Adding a New Pin (Details Entry)
    @State private var isUpdatingPin: Bool = false
    @State private var updatePinError: String = ""
    @State private var updatePinSuccess: String = ""
    @State private var pinName: String = ""
    @State private var selectedGroupIDs: Set<String> = []
    @State private var availableGroups: [Group] = []
    
    // State Variables for Alerts
    @State private var showSuccessAlert: Bool = false
    @State private var showErrorAlert: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {
            if !(pin.isAdded ?? true) {
                // Prompt for Pin Details
                VStack(spacing: 16) {
                    Text("Add Pin Details")
                        .font(.headline)
                    
                    // TextField for Pin Name
                    TextField("Enter Pin Name", text: $pinName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding([.leading, .trailing], 16)
                    
                    // List of Groups with Toggles
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select Groups:")
                            .font(.headline)
                            .padding([.leading, .trailing], 16)
                        
                        List(availableGroups.filter { $0.id != nil }, id: \.id) { group in
                            if let groupId = group.id {
                                Toggle(isOn: Binding(
                                    get: { selectedGroupIDs.contains(groupId) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedGroupIDs.insert(groupId)
                                        } else {
                                            selectedGroupIDs.remove(groupId)
                                        }
                                    }
                                )) {
                                    Text(group.name)
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                        .frame(height: 200) // Adjust height as needed
                    }
                    .padding([.leading, .trailing], 16)
                    
                    // "Save Details" Button
                    Button(action: {
                        updatePinDetails()
                    }) {
                        if isUpdatingPin {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(8)
                        } else {
                            Text("Save Details")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                    .disabled(isUpdatingPin || pinName.trimmingCharacters(in: .whitespaces).isEmpty || selectedGroupIDs.isEmpty)
                    .padding([.leading, .trailing], 16)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 10)
                .alert(isPresented: $showSuccessAlert) {
                    Alert(
                        title: Text("Success"),
                        message: Text(updatePinSuccess),
                        dismissButton: .default(Text("OK")) {
                            updatePinSuccess = ""
                            isPresented = nil // Dismiss the popup after success
                        }
                    )
                }
                .alert(isPresented: $showErrorAlert) {
                    Alert(
                        title: Text("Error"),
                        message: Text(updatePinError),
                        dismissButton: .default(Text("OK")) {
                            updatePinError = ""
                        }
                    )
                }
                .onAppear {
                    fetchAvailableGroups()
                }
            } else {
                // Display Pin Details
                VStack(alignment: .leading, spacing: 8) {
                    Text("Address:")
                        .font(.headline)
                    Text(pin.address)
                        .font(.body)

                    Text("Name:")
                        .font(.headline)
                    Text(pin.name)
                        .font(.body)

                    // Add this block to display the pricing level
                    if let pricingLevel = pin.pricingLevel {
                        Text("Pricing:")
                            .font(.headline)
                        Text(String(repeating: "$", count: pricingLevel))
                            .font(.body)
                    }

                    Divider()

                    Text("Reviews:")
                        .font(.headline)

                    if averageRatings.isEmpty {
                        Text("No reviews yet.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    } else {
                        ForEach(averageRatings.keys.sorted(), id: \.self) { groupID in
                            HStack {
                                Text(groupNames[groupID] ?? "Unknown Group")
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.1f", averageRatings[groupID]!))
                                    .font(.subheadline)
                                    .foregroundColor(.yellow)
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                }
                .padding([.leading, .trailing], 16)
                
                // "View Reviews" Button
                Button(action: {
                    showReviewsView = true // Present ReviewsView
                }) {
                    Text("View Reviews")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .cornerRadius(8)
                }
                .disabled(averageRatings.isEmpty)
                .padding([.leading, .trailing], 16)
                .sheet(isPresented: $showReviewsView) {
                    ReviewsView(pin: pin)
                        .environmentObject(viewModel)
                }
                
                // "Add Review" Button for Existing Pins
                Button(action: {
                    showAddReviewView = true
                }) {
                    Text("Add a Review")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .cornerRadius(8)
                }
                .sheet(isPresented: $showAddReviewView) {
                    AddReviewView(pin: pin)
                        .environmentObject(viewModel)
                }
                .padding([.leading, .trailing], 16)
            }
            
            // "Close" Button
            Button(action: {
                isPresented = nil
            }) {
                Text("Close")
                    .foregroundColor(.blue)
            }
            .padding()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 10)
        .onAppear {
            if pin.isAdded ?? true {
                fetchGroupNames()
                fetchAverageRatings()
                fetchReviews()
            }
        }
        .sheet(isPresented: $showAddReviewAfterAddPin) {
            AddReviewView(pin: pin)
                .environmentObject(viewModel)
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(title: Text("Error"), message: Text(updatePinError), dismissButton: .default(Text("OK")))
        }
        .alert(isPresented: $showSuccessAlert) {
            Alert(title: Text("Success"), message: Text(updatePinSuccess), dismissButton: .default(Text("OK")) {
                updatePinSuccess = ""
                isPresented = nil // Dismiss the popup after success
            })
        }
    }
    
    // MARK: - Fetch Available Groups for Selection
    private func fetchAvailableGroups() {
        viewModel.fetchAvailableGroups()
        DispatchQueue.main.async {
            self.availableGroups = self.viewModel.availableGroups
        }
    }
    
    // MARK: - Fetch Group Names
    private func fetchGroupNames() {
        let db = Firestore.firestore()
        let groupIDs = pin.groupIDs
        groupNames = [:] // Reset the dictionary
        let dispatchGroup = DispatchGroup()
        
        for groupID in groupIDs {
            dispatchGroup.enter()
            db.collection("groups").document(groupID).getDocument { document, error in
                if let document = document, document.exists {
                    let groupName = document.data()?["name"] as? String ?? "Unknown Group"
                    self.groupNames[groupID] = groupName
                } else {
                    print("Error fetching group \(groupID): \(String(describing: error))")
                    self.groupNames[groupID] = "Unknown Group" // Assign a default name in case of error
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            // Group names are fetched
        }
    }
    
    // MARK: - Fetch Average Ratings per Group
    private func fetchAverageRatings() {
        let db = Firestore.firestore()
        let groupIDs = pin.groupIDs
        averageRatings = [:]
        
        let dispatchGroup = DispatchGroup()
        
        for groupID in groupIDs {
            dispatchGroup.enter()
            db.collection("reviews")
                .whereField("pinID", isEqualTo: pin.id ?? "")
                .whereField("groupIDs", arrayContains: groupID)
                .getDocuments { snapshot, error in
                    if let snapshot = snapshot {
                        let reviews = snapshot.documents.compactMap { document -> Review? in
                            try? document.data(as: Review.self)
                        }
                        let average = reviews.isEmpty ? 0.0 : reviews.map { Double($0.overallRating) }.reduce(0, +) / Double(reviews.count)
                        self.averageRatings[groupID] = average
                    }
                    dispatchGroup.leave()
                }
        }
        
        dispatchGroup.notify(queue: .main) {
            // Average ratings are fetched
        }
    }
    
    // MARK: - Fetch Reviews Count and Average
    private func fetchReviews() {
        let db = Firestore.firestore()
        guard let pinID = pin.id else {
            self.updatePinError = "Invalid Pin ID."
            self.showErrorAlert = true
            return
        }
        
        db.collection("reviews")
            .whereField("pinID", isEqualTo: pinID)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching reviews: \(error)")
                    self.updatePinError = "Failed to load reviews."
                    self.showErrorAlert = true
                } else {
                    let reviews = snapshot?.documents.compactMap { document in
                        try? document.data(as: Review.self)
                    } ?? []
                    
                    // Calculate average ratings per group
                    var ratingsDict: [String: [Int]] = [:]
                    
                    for review in reviews {
                        for groupID in review.groupIDs {
                            ratingsDict[groupID, default: []].append(review.overallRating)
                        }
                    }
                    
                    for (groupID, ratings) in ratingsDict {
                        let average = ratings.map { Double($0) }.reduce(0, +) / Double(ratings.count)
                        averageRatings[groupID] = average
                    }
                }
            }
    }
    
    // MARK: - Update Pin Details Functionality
    private func updatePinDetails() {
        isUpdatingPin = true
        updatePinError = ""
        updatePinSuccess = ""
        
        // Validate Inputs
        let trimmedPinName = pinName.trimmingCharacters(in: .whitespaces)
        guard !trimmedPinName.isEmpty else {
            updatePinError = "Pin name cannot be empty."
            showErrorAlert = true
            isUpdatingPin = false
            return
        }
        
        guard !selectedGroupIDs.isEmpty else {
            updatePinError = "Please select at least one group."
            showErrorAlert = true
            isUpdatingPin = false
            return
        }
        
        // Prepare Pin Data
        var updatedPin = pin
        updatedPin.name = trimmedPinName
        updatedPin.groupIDs = Array(selectedGroupIDs)
        updatedPin.isAdded = true // Mark as added
        
        // Update the pin in Firestore
        viewModel.addPin(pin: updatedPin) { success in
            DispatchQueue.main.async {
                isUpdatingPin = false
                if success {
                    updatePinSuccess = "Pin details updated successfully."
                    showSuccessAlert = true
                } else {
                    updatePinError = "Failed to update pin details."
                    showErrorAlert = true
                }
            }
        }
    }
}
