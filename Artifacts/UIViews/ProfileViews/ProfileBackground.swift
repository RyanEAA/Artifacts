//
//  ProfileBackground.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 3/10/26.
//

import Foundation
import SwiftUI

struct ProfileBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.black, location: 0.00),
                    .init(color: Color("DarkGray").opacity(0.98), location: 0.55),
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
                    Color.black.opacity(0.55)
                ]),
                center: .center,
                startRadius: 140,
                endRadius: 620
            )
        }
    }
}

struct ProfileCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color.black.opacity(0.46))
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.05))
            )
    }
}
