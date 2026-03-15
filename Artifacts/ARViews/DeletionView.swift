//
//  DeletionView.swift
//  ARTutorial
//
//  Created by Ryan Aparicio on 10/27/25.
//

import SwiftUI
import RealityKit

struct DeletionView: View {
    @EnvironmentObject var sceneManager: SceneManager
    @EnvironmentObject var modelDeletionManager: ModelDeletionManager
    
    var body: some View {
        HStack(spacing: 14) {
            DeleteActionButton(kind: .cancel) {
                print("Cancel Deletion button Pressed")
                self.modelDeletionManager.entitySelectedForDeletion = nil
            }

            Spacer(minLength: 0)

            DeleteActionButton(kind: .delete) {
                print("Confirm Deletion button Pressed")

                guard let entity = self.modelDeletionManager.entitySelectedForDeletion,
                      let anchor = entity.anchor else { return }
                let modelName = anchor.name.hasPrefix(anchorNamePrefix)
                    ? String(anchor.name.dropFirst(anchorNamePrefix.count))
                    : entity.name

                let anchoringIdentifier = anchor.anchorIdentifier
                if let index = self.sceneManager.anchorEntities.firstIndex(where: { $0.anchorIdentifier == anchoringIdentifier }) {
                    self.sceneManager.anchorEntities.remove(at: index)
                }

                anchor.removeFromParent()
                self.modelDeletionManager.entitySelectedForDeletion = nil

                if let sceneId = self.sceneManager.selectedCloudSceneId, !sceneId.isEmpty {
                    Task {
                        try? await ArtifactsService.shared.deleteMyDraftModelArtifact(
                            sceneId: sceneId,
                            modelName: modelName,
                            transform: anchor.transformMatrix(relativeTo: nil)
                        )
                    }
                }
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
    }
}

private enum DeleteActionKind {
    case cancel
    case delete
}

private struct DeleteActionButton: View {
    let kind: DeleteActionKind
    let action: () -> Void

    private var icon: String {
        switch kind {
        case .cancel: return "xmark"
        case .delete: return "trash"
        }
    }

    private var title: String {
        switch kind {
        case .cancel: return "Cancel"
        case .delete: return "Delete"
        }
    }

    private var bg: Color {
        switch kind {
        case .cancel: return Color.white.opacity(0.06)
        case .delete: return Color.red.opacity(0.26)
        }
    }

    private var fg: Color {
        switch kind {
        case .cancel: return Color.white.opacity(0.92)
        case .delete: return Color.white.opacity(0.92)
        }
    }

    private var stroke: Color {
        switch kind {
        case .cancel: return Color("MintGreen").opacity(0.16)
        case .delete: return Color.red.opacity(0.35)
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
