//
//  ArtifactPresentation.swift
//  Artifacts
//

import Foundation
import CoreLocation

@MainActor
final class ArtifactAddressBook: ObservableObject {
    @Published private var cachedAddresses: [String: String] = [:]

    private var requestedIDs: Set<String> = []

    func address(for artifact: ArtifactMapItem) -> String? {
        cachedAddresses[artifact.id]
    }

    func resolveAddress(for artifact: ArtifactMapItem) async {
        guard cachedAddresses[artifact.id] == nil, !requestedIDs.contains(artifact.id) else { return }
        requestedIDs.insert(artifact.id)

        let location = CLLocation(
            latitude: artifact.coordinate.latitude,
            longitude: artifact.coordinate.longitude
        )

        do {
            let geocoder = CLGeocoder()
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return }

            let parts = [
                placemark.name,
                placemark.locality,
                placemark.administrativeArea
            ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

            if !parts.isEmpty {
                cachedAddresses[artifact.id] = Array(parts.prefix(2)).joined(separator: ", ")
            }
        } catch {
            // Keep coordinate fallback when reverse geocoding fails or the device is offline.
        }
    }
}

extension ArtifactMapItem {
    var systemImageName: String {
        switch type {
        case "model":
            return "cube.transparent"
        case "annotation":
            return "text.bubble"
        case "drawing":
            return "pencil.and.scribble"
        default:
            return "mappin.and.ellipse"
        }
    }

    var artifactTypeLabel: String {
        switch type {
        case "model":
            return "3D model"
        case "annotation":
            return "Note"
        case "drawing":
            return "Drawing"
        default:
            return "Artifact"
        }
    }

    var readableCoordinate: String {
        let lat = abs(coordinate.latitude)
        let lon = abs(coordinate.longitude)
        let latDirection = coordinate.latitude >= 0 ? "N" : "S"
        let lonDirection = coordinate.longitude >= 0 ? "E" : "W"
        return String(format: "%.3f°%@, %.3f°%@", lat, latDirection, lon, lonDirection)
    }

    var metaLine: String {
        let timestamp = createdAt.formatted(date: .abbreviated, time: .shortened)
        return "\(artifactTypeLabel)  •  \(timestamp)"
    }
}
