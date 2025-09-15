//
//  SheetView.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 9/9/25.
//

import SwiftUI

struct SheetView: View {
    @Binding var isPresented: Bool
    @State var modelName: String = "toy_biplane_realistic"
    
    
    var body: some View {
        ZStack{
            ARViewContainer(modelName: $modelName)
                .ignoresSafeArea(edges: .all)
            
            Button(){
                isPresented.toggle()
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.largeTitle)
                    .foregroundColor(.black)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .padding(24)
        }
    }
}

#Preview {
    SheetView(isPresented: .constant(true))
}
