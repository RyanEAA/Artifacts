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
    
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        
        // Make it more visible but still translucent
         appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
         appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.25)
         
         // Apply to normal and scroll edge states
         UITabBar.appearance().standardAppearance = appearance
         UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $selected) {
            
            // ProfileView Tab
            NavigationStack{
                ProfileView()
            }
            .tabItem{
                //Image(systemName: "person")
                Label("Profile", systemImage: "person")
            }
            .tag(Tab.profile)
            
            // HomeARView Tab
            NavigationStack{
                HomeARView()
            }
            .tabItem{
                //Image(systemName: "arkit")
                Label("Home", systemImage: "arkit")
            }
            .tag(Tab.home)
            
            // FriendsTab 
            NavigationStack{
                FriendsView()
            }
            .tabItem{
                //Image(systemName: "person.2.fill")
                Label("Friends", systemImage: "person.2.fill")
            }
            .tag(Tab.friends)
            
        } // end of navigation stack
    }
}

#Preview {
    RootTabView()
}
