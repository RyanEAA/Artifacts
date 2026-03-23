//
//  TrackingStateView.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 3/22/26.
//

import SwiftUI
import ARKit

struct TrackingStateView: View {
    let trackingState: ARCamera.TrackingState

    var body: some View {
        if let content = contentForState {
            HStack(spacing: 12) {
                Image(systemName: content.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(content.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(content.title)
                        .font(.headline)

                    Text(content.message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .cornerRadius(14)
            .shadow(radius: 10)
            .padding(.horizontal)
            .padding(.top, 60)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.85, blendDuration: 0.2), value: stateKey)
        }
    }
}

private extension TrackingStateView {

    var contentForState: (icon: String, title: String, message: String, color: Color)? {
        switch trackingState {

        case .notAvailable:
            return nil

        case .normal:
            return nil

        case .limited(let reason):
            switch reason {

            case .initializing:
                return (
                    "iphone.gen3.radiowaves.left.and.right",
                    "Detecting World",
                    "Move your device slowly",
                    .blue
                )

            case .relocalizing:
                return (
                    "arrow.triangle.2.circlepath",
                    "Relocalizing",
                    "Returning to previous session",
                    .orange
                )

            case .excessiveMotion:
                return (
                    "exclamationmark.triangle",
                    "Too Much Movement",
                    "Move your device more slowly",
                    .yellow
                )

            case .insufficientFeatures:
                return (
                    "lightbulb",
                    "Not Enough Detail",
                    "Find a textured or well-lit area",
                    .orange
                )

            @unknown default:
                return nil
            }
        }
    }

    // Helps SwiftUI detect state changes for animation
    var stateKey: String {
        switch trackingState {
        case .normal: return "normal"
        case .notAvailable: return "notAvailable"
        case .limited(let reason): return "limited-\(reason)"
        }
    }
}
