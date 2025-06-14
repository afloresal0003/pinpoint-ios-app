//
//  LaunchScreen.swift
//  Mobile App Final Project
//
//  Created by Gift G on 11/27/24.
//

import SwiftUI

struct LaunchScreen: View {
    var body: some View {
        Spacer()
        Text("Welcome!")
            .fontWeight(.bold)
        Image("app_logo")
            .resizable()
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
        ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
        Spacer()
        Spacer()
        Text("for COMS 4995 (iOS) Final")
            .foregroundColor(Color(red: 227/255, green: 227/255, blue: 227/255))
            .padding(.bottom)
    }
}

#Preview {
    LaunchScreen()
}
