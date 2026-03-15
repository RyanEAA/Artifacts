//
//  ArtifactMapMarkers.swift
//  Artifacts
//

import SwiftUI
import CoreLocation

struct ArtifactCluster: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let items: [ArtifactMapItem]

    var count: Int { items.count }
    var representative: ArtifactMapItem { items[0] }
    var ownerUid: String { representative.ownerUid }
    var ownerUIDs: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for item in items {
            if !seen.contains(item.ownerUid) {
                seen.insert(item.ownerUid)
                ordered.append(item.ownerUid)
            }
        }
        return ordered
    }
    var ownerArtifactCounts: [(ownerUid: String, count: Int)] {
        var counts: [String: Int] = [:]
        for item in items {
            counts[item.ownerUid, default: 0] += 1
        }
        return ownerUIDs.map { ($0, counts[$0] ?? 0) }
    }
}

struct ArtifactMarkerOwner: Identifiable {
    let ownerUid: String
    let imageURL: String?
    let count: Int

    var id: String { ownerUid }
}

enum ArtifactMapClusterer {
    static func makeClusters(items: [ArtifactMapItem], cellMeters: Double = 12) -> [ArtifactCluster] {
        guard !items.isEmpty else { return [] }

        var buckets: [String: [ArtifactMapItem]] = [:]
        buckets.reserveCapacity(items.count)

        for item in items {
            let key = keyFor(item.coordinate, cellMeters: cellMeters)
            buckets[key, default: []].append(item)
        }

        return buckets.map { (key, groupedItems) in
            let center = averageCoordinate(for: groupedItems)
            return ArtifactCluster(
                id: key,
                coordinate: center,
                items: groupedItems.sorted { $0.createdAt > $1.createdAt }
            )
        }
        .sorted { $0.representative.createdAt > $1.representative.createdAt }
    }

    private static func keyFor(_ coordinate: CLLocationCoordinate2D, cellMeters: Double) -> String {
        let metersPerLat = 111_320.0
        let metersPerLon = max(10.0, 111_320.0 * cos(coordinate.latitude * .pi / 180.0))

        let latIndex = Int((coordinate.latitude * metersPerLat) / cellMeters)
        let lonIndex = Int((coordinate.longitude * metersPerLon) / cellMeters)

        return "\(latIndex):\(lonIndex)"
    }

    private static func averageCoordinate(for items: [ArtifactMapItem]) -> CLLocationCoordinate2D {
        let total = items.reduce((lat: 0.0, lon: 0.0)) { partial, item in
            (lat: partial.lat + item.coordinate.latitude, lon: partial.lon + item.coordinate.longitude)
        }
        let count = Double(items.count)
        return CLLocationCoordinate2D(
            latitude: total.lat / count,
            longitude: total.lon / count
        )
    }
}

struct ArtifactMarkerView: View {
    let owners: [ArtifactMarkerOwner]
    let isSelected: Bool

    var body: some View {
        let displayedOwners = Array(owners.prefix(3))

        return HStack(spacing: 6) {
            ForEach(displayedOwners) { owner in
                singleOwnerMarker(owner)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }

    private func singleOwnerMarker(_ owner: ArtifactMarkerOwner) -> some View {
        let outerSize: CGFloat = isSelected ? 42 : 34
        let innerSize: CGFloat = isSelected ? 34 : 28

        return ZStack {
            Circle()
                .fill(Color.black.opacity(0.80))
                .frame(width: outerSize, height: outerSize)
                .overlay(
                    Circle()
                        .stroke(
                            Color("MintGreen").opacity(isSelected ? 0.92 : 0.55),
                            lineWidth: isSelected ? 2 : 1
                        )
                )

            avatarBubble(urlString: owner.imageURL, size: innerSize)
        }
        .overlay(alignment: .topTrailing) {
            if owner.count > 1 {
                countBadge(owner.count)
                    .offset(x: 6, y: -6)
            }
        }
    }

    @ViewBuilder
    private func avatarBubble(urlString: String?, size: CGFloat) -> some View {
        if let urlString, let url = URL(string: urlString) {
            CachedRemoteImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ProgressView()
                    .tint(Color("MintGreen"))
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
        } else {
            fallbackAvatar
                .frame(width: size, height: size)
        }
    }

    private var fallbackAvatar: some View {
        Image(systemName: "person.fill")
            .font(.system(size: isSelected ? 14 : 12, weight: .bold))
            .foregroundColor(Color("MintGreen").opacity(0.92))
    }

    private func countBadge(_ count: Int) -> some View {
        let display = count > 99 ? "99+" : "\(count)"
        return Text(display)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.black.opacity(0.95))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .fixedSize(horizontal: true, vertical: true)
            .background(Color("MintGreen"))
            .clipShape(Capsule())
    }
}
