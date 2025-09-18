//
//  ProfileView.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 9/17/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var session: SessionManager
    @State var isPresented: Bool = false


    var body: some View {
        VStack(spacing: 20) {
            // welcome user
            if let user = session.user {
                Text("Welcome, \(user.email ?? "User")!")
                    .font(.title)
            }
            
//            Enter AR Mode
            Image("toyplane_img")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.tint)
                .clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 20)))
                .padding(24)
            
            Button {
                isPresented.toggle()
            } label: {
                Label("View in AR", systemImage: "arkit")
            }.buttonStyle(BorderedProminentButtonStyle())
                .padding(24)
            
            
            // sign out button
            Button("Sign Out") {
                session.signOut()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .fullScreenCover(isPresented: $isPresented, content: {
           SheetView(isPresented: $isPresented)
        })
    }
}
#Preview {
    ProfileView()
}
