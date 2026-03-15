//
//  ArtifactDetailSheet.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 3/10/26.
//

import Foundation
import SwiftUI

struct ArtifactDetailSheet: View {
    let item: ArtifactMapItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color("MintGreen").opacity(0.16))
                        .frame(width: 38, height: 38)
                    Image(systemName: item.systemImageName)
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color("MintGreen").opacity(0.92))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.custom("Poppins-Bold", size: 18))
                        .foregroundColor(Color.white.opacity(0.92))
                    Text("\(item.artifactTypeLabel) • \(item.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.custom("Poppins-Regular", size: 12))
                        .foregroundColor(Color.white.opacity(0.60))
                        .lineLimit(1)
                }

                Spacer()
            }

            VStack(spacing: 8) {
                row("Approximate location", item.readableCoordinate)
                row("Scene", item.sceneId.isEmpty ? "Unknown" : item.sceneId)
            }
            .padding(12)
            .background(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .cornerRadius(14)

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Color.black.ignoresSafeArea())
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.custom("Poppins-Regular", size: 13))
                .foregroundColor(Color.white.opacity(0.70))
            Spacer()
            Text(value)
                .font(.custom("Poppins-SemiBold", size: 13))
                .foregroundColor(Color.white.opacity(0.90))
        }
    }
}
