//
//  FullMapView.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 11/4/25.
//

import SwiftUI
import MapKit
import CoreLocation

struct FullMapView: View {
    @Environment(\.dismiss) private var dismiss
    @State var region: MKCoordinateRegion
    var onDismiss: (MKCoordinateRegion) -> Void

    var body: some View {
        ZStack {
            Map(coordinateRegion: $region)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button {
                        onDismiss(region)
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
}

#Preview {
    FullMapView(
        region: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        ),
        onDismiss: { _ in /* no-op for preview */ }
    )
}
