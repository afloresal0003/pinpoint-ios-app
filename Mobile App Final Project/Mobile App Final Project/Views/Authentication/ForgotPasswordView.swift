//
//  ForgotPasswordView.swift
//  Mobile App Final Project
//
//  Created by Ahmed Mahmud on 11/26/24.
//

import SwiftUI
import FirebaseAuth

struct ForgotPasswordView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var email: String = ""
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Reset Password")
                    .font(.largeTitle)
                    .bold()

                TextField("Enter your email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                Button(action: {
                    sendPasswordReset()
                }) {
                    Text("Send Reset Email")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .disabled(email.isEmpty)

                Spacer()
            }
            .padding()
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Reset Password"),
                      message: Text(alertMessage),
                      dismissButton: .default(Text("OK"), action: {
                          presentationMode.wrappedValue.dismiss()
                      }))
            }
        }
    }

    private func sendPasswordReset() {
        authViewModel.sendPasswordResetEmail(email: email) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.alertMessage = "Password reset email sent."
                case .failure(let error):
                    self.alertMessage = error.localizedDescription
                }
                self.showAlert = true
            }
        }
    }
}
