//
//  MyArtifactsView.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 3/8/26.
//

import Foundation
import SwiftUI

struct MyArtifactsView: View {
    
    let artifacts: [ArtifactMapItem]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(artifacts) { artifact in
                    VStack(alignment: .leading, spacing: 4) {

                        Text(artifact.title)
                            .font(.system(size: 16, weight: .semibold))

                        Text("Lat \(artifact.coordinate.latitude), Lon \(artifact.coordinate.longitude)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .onDelete(perform: deleteArtifacts)
            }
            .navigationTitle("My Artifacts")
        }
    }

    private func deleteArtifacts(at offsets: IndexSet) {

        for index in offsets {
            let artifact = artifacts[index]

            ArtifactsService.shared.deleteArtifact(artifactId: artifact.id)
        }
    }
}
