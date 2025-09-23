//
//  RootBarView.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 9/22/25.
//

import SwiftUI

struct RootTabView: View {
    
    enum Tab: Hashable { case profile, home, friends }
    @State private var selected: Tab = .home // def tab is home
    
    var body: some View {
        TabView(selection: $selected) {
            
            
            
            // ProfileView Tab
            NavigationStack{
                ProfileView()
            }
            .tabItem{
                Label("Profile", systemImage: "person")
            }
            .tag(Tab.profile)
            
            // HomeARView Tab
            NavigationStack{
                HomeARView()
            }
            .tabItem{
                Label("Home", systemImage: "arkit")
            }
            .tag(Tab.home)
            
            // FriendsTab 
            NavigationStack{
                FriendsView()
            }
            .tabItem{
                Label("Friends", systemImage: "person.two")
            }
            .tag(Tab.friends)
            
        } // end of navigation stack
    }
}

#Preview {
    RootTabView()
}
