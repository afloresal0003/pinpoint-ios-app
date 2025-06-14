//
//  MainTabView.swift
//  Mobile App Final Project
//
//  Created by Ahmed Mahmud on 11/23/24.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var mapViewModel: MapViewModel
    @Binding var selectedTab: Int

    var body: some View {
        TabView(selection: $selectedTab) {
            // Groups Tab
            NavigationView {
                GroupsView(selectedTab: $selectedTab)
                    .navigationBarTitle("Groups", displayMode: .inline)
            }
            .tabItem {
                Image(systemName: "person.3.fill")
                Text("Groups")
            }
            .tag(0)

            // Maps Tab
            NavigationView {
                MapsView()
                    .navigationBarTitle("Map", displayMode: .inline)
            }
            .tabItem {
                Image(systemName: "map.fill")
                Text("Map")
            }
            .tag(1)

            // Activity Tab
            NavigationView {
                ActivityView(selectedTab: $selectedTab)
                    .navigationBarTitle("Activity", displayMode: .inline)
            }
            .tabItem {
                Image(systemName: "bell.fill")
                Text("Activity")
            }
            .tag(2)

        }
        .onAppear {
            UITabBar.appearance().backgroundColor = UIColor.white
            authViewModel.fetchUserData()
        }
    }
}
