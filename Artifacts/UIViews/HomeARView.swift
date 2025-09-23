//
//  SheetView.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 9/9/25.
//

import SwiftUI

import SwiftUI

struct HomeARView: View {
//    @State private var modelName: String = "toy_biplane_realistic"
    @State private var modelName: String = "minecraft_sign"
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
                        .onEnded { value in
                            touchLocation = value.location
                            placeRequested = true
                        }

                )
                .ignoresSafeArea()

        }
    }
}

#Preview {
    HomeARView()
}
