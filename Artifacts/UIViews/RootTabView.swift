//
//  RootView.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 9/22/25.
//

import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var session: SessionManager
    @State private var showProfile = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Home view (main screen)
            HomeARView()
                .ignoresSafeArea()
            
            // Profile button (top-left)
            Button {
                withAnimation(.easeInOut) {
                    showProfile = true
                }
            } label: {
                if let urlString = session.userData?["profilePictureURL"] as? String,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 44, height: 44)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(Color.white.opacity(0.9), lineWidth: 2)
                                )
                        case .failure(_):
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 44)
                                .foregroundColor(.white)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .foregroundColor(.white)
                }
            }
            .padding(.top, 60)
            .padding(.leading, 20)
            .shadow(radius: 3)


        }
    }
}

#Preview {
    RootTabView()
        .environmentObject(SessionManager())
}
