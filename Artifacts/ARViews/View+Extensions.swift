//
//  View+Extensions.swift
//  ARTutorial
//
//  Created by Ryan Aparicio on 10/13/25.
//

import SwiftUI

extension View {
    
    @ViewBuilder func hidden(_ shouldHide: Bool) -> some View{
        switch shouldHide {
        case true: self.hidden()
        case false: self
        }
    }

    // MARK: - App styling helpers (Dark + Mint)

    func artifactsPanel(cornerRadius: CGFloat = 18) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.black.opacity(0.46))
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.white.opacity(0.05))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .cornerRadius(cornerRadius)
            .shadow(color: Color.black.opacity(0.45), radius: 16, x: 0, y: 10)
    }

    func artifactsSheetBackground() -> some View {
        self
            .background(
                ZStack {
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.black, location: 0.00),
                            .init(color: Color("DarkGray").opacity(0.98), location: 0.60),
                            .init(color: Color.black.opacity(0.96), location: 1.00)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color("MintGreen").opacity(0.08),
                            Color.clear
                        ]),
                        startPoint: .topTrailing,
                        endPoint: .center
                    )

                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.00),
                            Color.black.opacity(0.60)
                        ]),
                        center: .center,
                        startRadius: 140,
                        endRadius: 640
                    )
                }
                    .ignoresSafeArea()
            )
    }
}
