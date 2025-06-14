//
//  SignInView.swift
//  Mobile App Final Project
//
//  Created by Ahmed Mahmud on 11/23/24.
//


import SwiftUI

struct SignInView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showForgotPasswordView: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Sign In")
                .font(.largeTitle)
                .bold()

            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)

            SecureField("Password", text: $password)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)

            if !authViewModel.errorMessage.isEmpty {
                Text(authViewModel.errorMessage)
                    .foregroundColor(.red)
            }

            Button(action: {
                authViewModel.signIn(email: email, password: password) { success in
                    if success {
                        self.presentationMode.wrappedValue.dismiss()
                    }
                }
            }) {
                Text("Sign In")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
            }

            Button(action: {
                showForgotPasswordView = true
            }) {
                Text("Forgot Password?")
                    .foregroundColor(.blue)
            }
            .sheet(isPresented: $showForgotPasswordView) {
                ForgotPasswordView()
                    .environmentObject(authViewModel)
            }

            Spacer()
        }
        .padding()
    }
}
