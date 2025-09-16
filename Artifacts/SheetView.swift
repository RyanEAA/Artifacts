//
//  SheetView.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 9/9/25.
//

import SwiftUI

import SwiftUI

struct SheetView: View {
    @Binding var isPresented: Bool

    @State private var modelName: String = "toy_biplane_realistic"
    @State private var touchLocation: CGPoint? = nil
    @State private var placeRequested: Bool = false

    var body: some View {
        ZStack {
            // Pass bindings to the representable
            ARViewContainer(modelName: $modelName,
                            touchLocation: $touchLocation,
                            placeRequested: $placeRequested)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            touchLocation = value.location
                        }
                        .onEnded { _ in
                            // keep last location so reticle stays visible
                        }
                )
                .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button {
                        isPresented.toggle()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.primary)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(16)
                }
                Spacer()
                Button("Place Object") {
                    placeRequested = true
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.bottom, 50)
            }
        }
    }
}

#Preview {
    SheetView(isPresented: .constant(true))
}
