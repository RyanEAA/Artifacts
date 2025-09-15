//
//  ContentView.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 9/9/25.
//

import SwiftUI

struct ContentView: View {
    
    @State var isPresented: Bool = false
    
    var body: some View {
        VStack {
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
        }
        .padding()
        
        .fullScreenCover(isPresented: $isPresented, content: {
           SheetView(isPresented: $isPresented)
        })
    }
}

#Preview {
    ContentView()
}
