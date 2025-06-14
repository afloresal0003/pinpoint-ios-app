// Mobile_App_Final_ProjectApp.swift
import SwiftUI
import Firebase

@main
struct Mobile_App_Final_ProjectApp: App {
    @StateObject var authViewModel: AuthViewModel
    @StateObject var mapViewModel: MapViewModel
    @State private var selectedTab = 1

    init() {
        // Initialize Firebase
        FirebaseApp.configure()
        
        // Initialize AuthViewModel
        let authVM = AuthViewModel()
        _authViewModel = StateObject(wrappedValue: authVM)
        
        // Initialize MapViewModel with the AuthViewModel
        _mapViewModel = StateObject(wrappedValue: MapViewModel(authViewModel: authVM))
    }

    var body: some Scene {
        WindowGroup {
            if authViewModel.isAuthenticated {
                // User is authenticated, show the main content
                MainTabView(selectedTab: $selectedTab)
                    .environmentObject(authViewModel)
                    .environmentObject(mapViewModel)
            } else {
                // User is not authenticated, show sign-up view
                SignUpView()
                    .environmentObject(authViewModel)
            }
        }
    }
}
