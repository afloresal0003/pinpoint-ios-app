//
//  SignUpView.swift
//  Mobile App Final Project
//
//  Created by Ahmed Mahmud on 11/23/24.
//


import SwiftUI
import PhotosUI

struct SignUpView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var name: String = "" // New State for name
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showSignInView: Bool = false

    // State for image picker
    @State private var selectedImageData: Data? = nil
    @State private var showImagePicker: Bool = false
    @State private var profileImage: UIImage? = nil
    
    @State private var isLoading = true // State variable to track loading

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                if isLoading {
                    LaunchScreen() // Your custom loading view
                } else {
                    // show sign up
                    
                    Text("Create Account")
                        .font(.largeTitle)
                        .bold()
                    
                    // Profile Image
                    Button(action: {
                        showImagePicker = true
                    }) {
                        if let profileImage = profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 100)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    
                    // Name Field
                    TextField("Name", text: $name)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                    
                    // Email Field
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .textContentType(.emailAddress)
                    
                    // Password Fields
                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .textContentType(.oneTimeCode)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .textContentType(.oneTimeCode)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    // Error Message
                    if !authViewModel.errorMessage.isEmpty {
                        Text(authViewModel.errorMessage)
                            .foregroundColor(.red)
                    }
                    
                    // Sign Up Button
                    Button(action: {
                        authViewModel.signUp(
                            name: name,
                            email: email,
                            password: password,
                            confirmPassword: confirmPassword,
                            profileImage: profileImage
                        ) { success in
                            if success {
                                // Handle successful sign-up if needed
                            }
                        }
                    }) {
                        Text("Sign Up")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .disabled(name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty)
                    
                    // Sign In Link
                    Button(action: {
                        self.showSignInView = true
                    }) {
                        Text("Already have an account? Sign In")
                            .foregroundColor(.blue)
                    }
                    .sheet(isPresented: $showSignInView) {
                        SignInView()
                            .environmentObject(authViewModel)
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .onAppear {
                // Simulate a delay for loading
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    isLoading = false // Dismiss the loading screen
                }
            }
            
        }
        
        // Image Picker Sheet
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $profileImage)
        }
    }
}
