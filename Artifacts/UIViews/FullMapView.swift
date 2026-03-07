//
//  FullMapView.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 11/4/25.
//

import SwiftUI
import MapKit
import UIKit

struct FullMapView: View {
    @Environment(\.dismiss) private var dismiss

    @State var region: MKCoordinateRegion
    let artifacts: [ArtifactMapItem]
    let ownerAvatarURLs: [String: String]
    var onDismiss: (MKCoordinateRegion) -> Void

    @State private var selectedClusterID: String?
    @State private var selectedArtifact: ArtifactMapItem?

    private var clusters: [ArtifactCluster] {
        ArtifactMapClusterer.makeClusters(items: artifacts)
    }

    var body: some View {
        ZStack {
            Map(coordinateRegion: $region, annotationItems: clusters) { cluster in
                MapAnnotation(coordinate: cluster.coordinate) {
                    ArtifactMarkerView(
                        owners: markerOwners(for: cluster),
                        isSelected: selectedClusterID == cluster.id
                    )
                    .onTapGesture {
                        DispatchQueue.main.async {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedClusterID = cluster.id
                            handleClusterTap(cluster)
                        }
                    }
                    .onLongPressGesture {
                        DispatchQueue.main.async {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            selectedClusterID = cluster.id
                            selectedArtifact = cluster.items.first
                            withAnimation(.easeInOut(duration: 0.35)) {
                                region.center = cluster.coordinate
                            }
                        }
                    }
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    Button {
                        onDismiss(region)
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Done")
                                .font(.custom("Poppins-SemiBold", size: 15))
                        }
                        .foregroundColor(Color.black.opacity(0.92))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(Color("MintGreen"))
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 8)
                    }

                    Spacer()

                    if !artifacts.isEmpty {
                        Text("\(artifacts.count) artifacts")
                            .font(.custom("Poppins-SemiBold", size: 13))
                            .foregroundColor(Color.white.opacity(0.86))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 14)
                .padding(.horizontal, 14)

                Spacer()

                if let selectedArtifact {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selectedArtifact.title)
                            .font(.custom("Poppins-Bold", size: 16))
                            .foregroundColor(Color.white.opacity(0.92))
                            .lineLimit(1)

                        Text("Lat \(String(format: "%.5f", selectedArtifact.coordinate.latitude))  Lon \(String(format: "%.5f", selectedArtifact.coordinate.longitude))")
                            .font(.custom("Poppins-Regular", size: 12))
                            .foregroundColor(Color.white.opacity(0.70))
                            .lineLimit(1)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.60))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color("MintGreen").opacity(0.18), lineWidth: 1)
                    )
                    .cornerRadius(14)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            if let first = artifacts.first {
                region.center = first.coordinate
            }
        }
    }

    private func openAppleMapsForArtifact(_ item: ArtifactMapItem) {
        let placemark = MKPlacemark(coordinate: item.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = item.title

        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving,
            MKLaunchOptionsShowsTrafficKey: true
        ]

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            MKMapItem.openMaps(with: [mapItem], launchOptions: launchOptions)
        }
    }

    private func handleClusterTap(_ cluster: ArtifactCluster) {
        withAnimation(.easeInOut(duration: 0.35)) {
            region.center = cluster.coordinate
        }

        if let item = cluster.items.first {
            selectedArtifact = item
            openAppleMapsForArtifact(item)
        }
    }

    private func markerOwners(for cluster: ArtifactCluster) -> [ArtifactMarkerOwner] {
        cluster.ownerArtifactCounts.map { bucket in
            ArtifactMarkerOwner(
                ownerUid: bucket.ownerUid,
                imageURL: ownerAvatarURLs[bucket.ownerUid],
                count: bucket.count
            )
        }
    }
}

#Preview {
    FullMapView(
        region: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431),
            span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
        ),
        artifacts: [],
        ownerAvatarURLs: [:],
        onDismiss: { _ in }
    )
}
