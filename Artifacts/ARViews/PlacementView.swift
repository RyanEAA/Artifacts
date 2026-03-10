//
//  PlacementView.swift
//  ARTutorial
//
//  Created by Ryan Aparicio on 10/10/25.
//

import SwiftUI

struct PlacementView: View {
    @EnvironmentObject var placementSettings: PlacementSettings

    var body: some View {
        // Only render when a 3D model tool is active
        guard case .model(let model) = placementSettings.selectedTool else {
            return AnyView(EmptyView())
        }

        return AnyView(
            HStack(spacing: 14) {
                PlacementActionButton(kind: .cancel) {
                    print("Cancel Placement Button Pressed")
                    placementSettings.previewEntity?.removeFromParent()
                    placementSettings.previewEntity = nil
                    placementSettings.selectedTool = .none
                }

                Spacer(minLength: 0)

                // Model name in the middle
                
                Text(model.name)
                    .font(.custom("Poppins-SemiBold", size: 13))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)

                Spacer(minLength: 0)

                PlacementActionButton(kind: .confirm) {
                    print("Confirm Placement Button Pressed")
                    if model.modelEntity == nil {
                        model.asyncLoadModelEntity { success, error in
                            if success {
                                placeModel(model)
                            }
                        }
                    } else {
                        placeModel(model)
                    }
//                    let modelAnchor = ModelAnchor(model: model, anchor: nil)
//                    placementSettings.modelsConfirmedForPlacement.append(modelAnchor)
//                    placementSettings.selectedTool = .none
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.38))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        )
    }
    func placeModel(_ model: Model) {
        let modelAnchor = ModelAnchor(model: model, anchor: nil)
        placementSettings.modelsConfirmedForPlacement.append(modelAnchor)
        placementSettings.selectedTool = .none
    }
}

// MARK: - Action Button

private enum PlacementActionKind {
    case cancel
    case confirm
}

private struct PlacementActionButton: View {
    let kind: PlacementActionKind
    let action: () -> Void

    private var icon: String {
        switch kind {
        case .cancel:  return "xmark"
        case .confirm: return "checkmark"
        }
    }

    private var title: String {
        switch kind {
        case .cancel:  return "Cancel"
        case .confirm: return "Place"
        }
    }

    private var bg: Color {
        switch kind {
        case .cancel:  return Color.white.opacity(0.06)
        case .confirm: return Color("MintGreen")
        }
    }

    private var fg: Color {
        switch kind {
        case .cancel:  return Color.white.opacity(0.92)
        case .confirm: return Color.black.opacity(0.92)
        }
    }

    private var stroke: Color {
        switch kind {
        case .cancel:  return Color("MintGreen").opacity(0.16)
        case .confirm: return Color("MintGreen").opacity(0.25)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(.custom("Poppins-SemiBold", size: 14))
            }
            .foregroundColor(fg)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bg)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(stroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
