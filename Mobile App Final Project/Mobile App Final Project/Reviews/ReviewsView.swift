// ReviewsView.swift
import SwiftUI
import Firebase
import FirebaseFirestore

struct ReviewsView: View {
    var pin: Pin
    @EnvironmentObject var viewModel: MapViewModel
    @State private var reviews: [Review] = []
    @State private var isLoading: Bool = true
    @State private var showAddReviewView = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading Reviews...")
                        .padding()
                } else if reviews.isEmpty {
                    Text("Be the first to add a review!")
                        .padding()
                } else {
                    List(reviews) { review in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Overall Rating:")
                                    .font(.subheadline)
                                ForEach(0..<review.overallRating, id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                }
                                // Add pricing level next to stars
                                if let pinPricingLevel = pin.pricingLevel {
                                    Text("(\(String(repeating: "$", count: pinPricingLevel)))")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                }
                            }
                            HStack {
                                Text("Price Rating:")
                                    .font(.subheadline)
                                ForEach(0..<review.priceRating, id: \.self) { _ in
                                    Image(systemName: "dollarsign.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            Text(review.notes)
                                .font(.body)
                            
                            // Display images if available
                            if !review.imageURLs.isEmpty {
                                ScrollView(.horizontal) {
                                    HStack {
                                        ForEach(review.imageURLs, id: \.self) { url in
                                            AsyncImage(url: URL(string: url)) { image in
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 100, height: 100)
                                                    .clipped()
                                            } placeholder: {
                                                Color.gray
                                                    .frame(width: 100, height: 100)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(pin.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button(action: {
                showAddReviewView = true
            }) {
                Image(systemName: "plus")
            })
            .sheet(isPresented: $showAddReviewView) {
                AddReviewView(pin: pin)
                    .environmentObject(viewModel)
            }
            .onAppear {
                fetchReviews()
            }
            .alert(isPresented: Binding<Bool>(
                get: { !errorMessage.isEmpty },
                set: { _ in errorMessage = "" }
            )) {
                Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    private func fetchReviews() {
        guard let pinID = pin.id else {
            self.errorMessage = "Invalid Pin ID."
            self.isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        db.collection("reviews")
            .whereField("pinID", isEqualTo: pinID)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching reviews: \(error)")
                    self.errorMessage = "Failed to load reviews."
                } else {
                    self.reviews = snapshot?.documents.compactMap { document in
                        try? document.data(as: Review.self)
                    } ?? []
                }
                self.isLoading = false
            }
    }
}
