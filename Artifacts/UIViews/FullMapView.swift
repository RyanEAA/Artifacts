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
    var onDismiss: (MKCoordinateRegion) -> Void

    @State private var selected: ArtifactMapItem?

    var body: some View {
        ZStack {
            Map(coordinateRegion: $region, annotationItems: artifacts) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.78))
                            .frame(width: selected?.id == item.id ? 40 : 32, height: selected?.id == item.id ? 40 : 32)
                            .overlay(
                                Circle()
                                    .stroke(Color("MintGreen").opacity(selected?.id == item.id ? 0.85 : 0.55), lineWidth: selected?.id == item.id ? 2 : 1)
                            )

                        Image(systemName: "sparkles")
                            .font(.system(size: selected?.id == item.id ? 15 : 13, weight: .bold))
                            .foregroundColor(Color("MintGreen").opacity(0.92))
                    }
                    .shadow(color: Color.black.opacity(0.45), radius: 8, x: 0, y: 6)
                    .animation(.easeInOut(duration: 0.18), value: selected?.id == item.id)
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selected = item
                        withAnimation(.easeInOut(duration: 0.35)) {
                            region.center = item.coordinate
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

                if let selected {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selected.title)
                            .font(.custom("Poppins-Bold", size: 16))
                            .foregroundColor(Color.white.opacity(0.92))
                            .lineLimit(1)

                        Text("Lat \(String(format: "%.5f", selected.coordinate.latitude))  Lon \(String(format: "%.5f", selected.coordinate.longitude))")
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
}

#Preview {
    FullMapView(
        region: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431),
            span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
        ),
        artifacts: [],
        onDismiss: { _ in }
    )
}
