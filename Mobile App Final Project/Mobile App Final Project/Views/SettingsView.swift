// SettingsView.swift

import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var profileImage: UIImage? = nil
    @State private var showImagePicker: Bool = false
    @State private var isSaving: Bool = false
    @State private var errorMessage: String = ""
    @State private var successMessage: String = ""
    @State private var isEditing: Bool = false
    @State private var activeAlert: ActiveAlert?

    enum ActiveAlert: Identifiable {
        case signOut, saveChanges, discardChanges, passwordReset(String)

        var id: String {
            switch self {
            case .signOut:
                return "signOut"
            case .saveChanges:
                return "saveChanges"
            case .discardChanges:
                return "discardChanges"
            case .passwordReset(let message):
                return "passwordReset-\(message)"
            }
        }
    }

    var body: some View {
        Form {
            Section(header: Text("Profile Picture")) {
                HStack {
                    Spacer()
                    Button(action: {
                        if isEditing {
                            self.showImagePicker = true
                        }
                    }) {
                        if let profileImage = profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                        } else {
                            Image(systemName: "person.crop.circle.fill.badge.plus")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .foregroundColor(.gray)
                        }
                    }
                    .disabled(!isEditing)
                    Spacer()
                }
                .padding(.vertical, 10) // Adjusted vertical padding
            }

            Section(header: Text("Name")) {
                if isEditing {
                    TextField("Name", text: $name)
                        .disableAutocorrection(true)
                } else {
                    Text(name)
                        .font(.body)
                }
            }

            Section(header: Text("Email")) {
                if isEditing {
                    TextField("Email", text: $email)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                } else {
                    Text(email)
                        .font(.body)
                }
            }

            Section {
                Button(action: {
                    sendPasswordReset()
                }) {
                    Text("Change Password")
                }
                .disabled(isEditing)
            }

            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }

            if !successMessage.isEmpty {
                Section {
                    Text(successMessage)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                }
            }

            Section {
                Button(action: {
                    activeAlert = .signOut
                }) {
                    Text("Sign Out")
                        .foregroundColor(.red)
                }
                .disabled(isEditing)
            }
        }
        .navigationBarItems(
            leading: isEditing ? Button("Cancel") { activeAlert = .discardChanges } : nil,
            trailing: Button(isEditing ? "Save" : "Edit") {
                if isEditing {
                    activeAlert = .saveChanges
                } else {
                    isEditing = true
                }
            }
            .disabled(isSaving)
        )
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $profileImage)
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .signOut:
                return Alert(
                    title: Text("Sign Out"),
                    message: Text("Are you sure you want to sign out?"),
                    primaryButton: .destructive(Text("Sign Out")) {
                        authViewModel.signOut()
                    },
                    secondaryButton: .cancel()
                )
            case .saveChanges:
                return Alert(
                    title: Text("Save Changes?"),
                    message: Text("Are you sure you want to save your changes?"),
                    primaryButton: .default(Text("Save")) {
                        saveChanges()
                    },
                    secondaryButton: .cancel()
                )
            case .discardChanges:
                return Alert(
                    title: Text("Discard Changes?"),
                    message: Text("Are you sure you want to discard your changes?"),
                    primaryButton: .destructive(Text("Discard")) {
                        isEditing = false
                        loadUserData()
                    },
                    secondaryButton: .cancel()
                )
            case .passwordReset(let message):
                return Alert(
                    title: Text("Reset Password"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .onAppear(perform: loadUserData)
    }

    private func loadUserData() {
        authViewModel.fetchUserData { success in
            if success, let userData = authViewModel.userData {
                DispatchQueue.main.async {
                    self.name = userData["name"] as? String ?? ""
                    self.email = userData["email"] as? String ?? ""
                    self.profileImage = authViewModel.profileImage
                }
            } else {
                self.errorMessage = authViewModel.errorMessage
            }
        }
    }

    private func saveChanges() {
        isSaving = true
        errorMessage = ""
        successMessage = ""

        authViewModel.updateUserProfile(name: name, email: email, profileImage: profileImage) { result in
            DispatchQueue.main.async {
                self.isSaving = false
                self.isEditing = false
                switch result {
                case .success:
                    self.successMessage = "Profile updated successfully."
                    // Update the profile image in the AuthViewModel
                    authViewModel.profileImage = self.profileImage
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func sendPasswordReset() {
        if let email = authViewModel.user?.email {
            authViewModel.sendPasswordResetEmail(email: email) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self.activeAlert = .passwordReset("Password reset email sent.")
                    case .failure(let error):
                        self.activeAlert = .passwordReset("Failed to send password reset email: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            self.errorMessage = "Email not available."
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AuthViewModel()) // Provide AuthViewModel
    }
}
