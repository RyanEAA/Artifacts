//
//  ControlVisibilityToggleButton.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 3/22/26.
//
import SwiftUI

struct ControlVisibilityToggleButton: View{
    @Binding var isControlsVisible: Bool
    var body: some View{
        HStack{
            Spacer()

            Button(action: {
                print("Control Visibility Toggle Button Pressed")
                self.isControlsVisible.toggle()
            }) {
                Image(systemName: self.isControlsVisible ? "rectangle" : "slider.horizontal.below.rectangle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color("MintGreen").opacity(0.92))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color("MintGreen").opacity(0.18), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 45)
        .padding(.trailing, 20)
    }
}
