//
//  MyArtifactsView.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 3/8/26.
//

import Foundation
import SwiftUI

struct MyArtifactsView: View {
    @Environment(\.dismiss) private var dismiss

    let artifacts: [ArtifactMapItem]
    @StateObject private var addressBook = ArtifactAddressBook()
    @State private var search = ""
    @State private var selectedFilter: ArtifactFilter = .all
    @State private var isDateRangeEnabled = false
    @State private var customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEndDate = Date()
    @State private var pendingDeletion: ArtifactMapItem?

    private var sortedArtifacts: [ArtifactMapItem] {
        artifacts.sorted { $0.createdAt > $1.createdAt }
    }

    private var filteredArtifacts: [ArtifactMapItem] {
        sortedArtifacts.filter { artifact in
            let matchesFilter = selectedFilter.matches(artifact)
            let matchesDate = !isDateRangeEnabled || ArtifactDateFilter.custom.matches(
                artifact.createdAt,
                startDate: customStartDate,
                endDate: customEndDate
            )
            let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return matchesFilter && matchesDate }

            let lowercasedQuery = query.lowercased()
            let haystacks = [
                artifact.title.lowercased(),
                artifact.artifactTypeLabel.lowercased(),
                artifact.readableCoordinate.lowercased(),
                addressBook.address(for: artifact)?.lowercased() ?? ""
            ]
            return matchesFilter && matchesDate && haystacks.contains(where: { $0.contains(lowercasedQuery) })
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MyArtifactsSheetBackground()
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        topBar
                        MyArtifactsSearchField(text: $search)
                            .padding(.horizontal, 16)
                        filterRow
                            .padding(.horizontal, 16)

                        if isDateRangeEnabled {
                            customDateRangeRow
                                .padding(.horizontal, 16)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        sectionCard(title: "Artifacts", badge: filteredArtifacts.count) {
                            if filteredArtifacts.isEmpty {
                                MyArtifactsEmptyStateRow(
                                    systemImage: search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "shippingbox" : "magnifyingglass",
                                    title: search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No artifacts yet" : "No matching artifacts",
                                    message: search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? "Place artifacts and save a scene to see them here."
                                        : "Try a different name or filter."
                                )
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(filteredArtifacts) { artifact in
                                        ArtifactRow(
                                            artifact: artifact,
                                            addressLine: addressBook.address(for: artifact) ?? artifact.readableCoordinate,
                                            onDelete: { pendingDeletion = artifact }
                                        )
                                        .task {
                                            await addressBook.resolveAddress(for: artifact)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        Spacer(minLength: 12)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 18)
                }
            }
            .navigationBarHidden(true)
            .presentationBackground(.black)
        }
        .animation(.easeInOut(duration: 0.22), value: isDateRangeEnabled)
        .alert("Delete Artifact?", isPresented: deleteAlertBinding) {
            Button("Cancel", role: .cancel) {
                pendingDeletion = nil
            }
            Button("Delete", role: .destructive) {
                if let pendingDeletion {
                    deleteArtifact(pendingDeletion)
                }
                pendingDeletion = nil
            }
        } message: {
            Text("This will permanently remove this artifact.")
        }
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ArtifactFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.title)
                            .font(.custom("Poppins-SemiBold", size: 13))
                            .foregroundColor(filterForeground(for: filter))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(filterBackground(for: filter))
                            .overlay(
                                Capsule()
                                    .stroke(filterStroke(for: filter), lineWidth: 1)
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    isDateRangeEnabled.toggle()
                } label: {
                    Text("Date Range")
                        .font(.custom("Poppins-SemiBold", size: 13))
                        .foregroundColor(isDateRangeEnabled ? Color.black.opacity(0.92) : Color.white.opacity(0.90))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(isDateRangeEnabled ? Color("MintGreen") : Color.white.opacity(0.06))
                        .overlay(
                            Capsule()
                                .stroke(isDateRangeEnabled ? Color("MintGreen").opacity(0.20) : Color.white.opacity(0.10), lineWidth: 1)
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var customDateRangeRow: some View {
        VStack(spacing: 10) {
            DatePicker(
                "From",
                selection: $customStartDate,
                in: ...customEndDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .tint(Color("MintGreen"))

            DatePicker(
                "To",
                selection: $customEndDate,
                in: customStartDate...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .tint(Color("MintGreen"))
        }
        .font(.custom("Poppins-Regular", size: 13))
        .foregroundColor(Color.white.opacity(0.90))
        .environment(\.colorScheme, .dark)
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .cornerRadius(16)
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeletion = nil
                }
            }
        )
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Text("Artifacts")
                .font(.custom("Poppins-Bold", size: 22))
                .foregroundColor(Color.white.opacity(0.92))

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.88))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.06))
                    .overlay(
                        Circle().stroke(Color("MintGreen").opacity(0.18), lineWidth: 1)
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func sectionCard<Content: View>(
        title: String,
        badge: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.custom("Poppins-SemiBold", size: 15))
                    .foregroundColor(Color.white.opacity(0.90))

                MyArtifactsCountBadge(value: badge)

                Spacer()
            }

            content()
        }
        .padding(14)
        .background(MyArtifactsCardBackground())
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.50), radius: 18, x: 0, y: 12)
    }

    private func deleteArtifact(_ artifact: ArtifactMapItem) {
        let artifactIds = artifact.memberArtifactIds.isEmpty ? [artifact.id] : artifact.memberArtifactIds
        artifactIds.forEach { ArtifactsService.shared.deleteArtifact(artifactId: $0) }
    }

    private func filterForeground(for filter: ArtifactFilter) -> Color {
        selectedFilter == filter ? Color.black.opacity(0.92) : Color.white.opacity(0.90)
    }

    private func filterBackground(for filter: ArtifactFilter) -> Color {
        selectedFilter == filter ? Color("MintGreen") : Color.white.opacity(0.06)
    }

    private func filterStroke(for filter: ArtifactFilter) -> Color {
        selectedFilter == filter ? Color("MintGreen").opacity(0.20) : Color.white.opacity(0.10)
    }

}

private enum ArtifactFilter: String, CaseIterable, Identifiable {
    case all
    case model
    case annotation
    case drawing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .model: return "3D Models"
        case .annotation: return "Notes"
        case .drawing: return "Drawings"
        }
    }

    func matches(_ artifact: ArtifactMapItem) -> Bool {
        switch self {
        case .all:
            return true
        default:
            return artifact.type == rawValue
        }
    }
}

private enum ArtifactDateFilter {
    case custom

    func matches(_ date: Date, startDate: Date, endDate: Date) -> Bool {
        let calendar = Calendar.current
        let normalizedStart = calendar.startOfDay(for: startDate)
        let normalizedEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
        return date >= normalizedStart && date < normalizedEnd
    }
}

private struct ArtifactRow: View {
    let artifact: ArtifactMapItem
    let addressLine: String
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Circle().stroke(Color("MintGreen").opacity(0.18), lineWidth: 1)
                    )

                Image(systemName: artifactIcon)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color("MintGreen").opacity(0.92))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(artifact.title)
                    .font(.custom("Poppins-SemiBold", size: 15))
                    .foregroundColor(Color.white.opacity(0.92))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(artifact.metaLine)
                    .font(.custom("Poppins-Regular", size: 12))
                    .foregroundColor(Color.white.opacity(0.62))
                    .lineLimit(1)

                Text(addressLine)
                    .font(.custom("Poppins-Regular", size: 12))
                    .foregroundColor(Color.white.opacity(0.62))
                    .lineLimit(1)
            }
            .layoutPriority(10)

            Spacer(minLength: 8)

            MyArtifactsDangerButton(
                title: "Delete",
                onTap: onDelete
            )
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .cornerRadius(16)
    }

    private var artifactIcon: String { artifact.systemImageName }
}

private struct MyArtifactsSheetBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.black, location: 0.00),
                    .init(color: Color("DarkGray").opacity(0.98), location: 0.60),
                    .init(color: Color.black.opacity(0.96), location: 1.00)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                gradient: Gradient(colors: [
                    Color("MintGreen").opacity(0.08),
                    Color.clear
                ]),
                startPoint: .topTrailing,
                endPoint: .center
            )

            RadialGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.00),
                    Color.black.opacity(0.60)
                ]),
                center: .center,
                startRadius: 140,
                endRadius: 640
            )
        }
    }
}

private struct MyArtifactsCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color.black.opacity(0.46))
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.05))
            )
    }
}

private struct MyArtifactsCountBadge: View {
    let value: Int

    var body: some View {
        Text("\(value)")
            .font(.custom("Poppins-SemiBold", size: 12))
            .foregroundColor(Color.black.opacity(0.90))
            .frame(height: 20)
            .padding(.horizontal, 8)
            .background(Color("MintGreen"))
            .clipShape(Capsule())
    }
}

private struct MyArtifactsSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color("MintGreen").opacity(0.85))

            ZStack(alignment: .leading) {
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Search artifacts")
                        .font(.custom("Poppins-Regular", size: 15))
                        .foregroundColor(Color.white.opacity(0.38))
                }

                TextField("", text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .foregroundColor(Color.white.opacity(0.92))
                    .tint(Color("MintGreen"))
            }

            if !text.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { text = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.white.opacity(0.35))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color("MintGreen").opacity(0.14), lineWidth: 1)
        )
        .cornerRadius(16)
    }
}

private struct MyArtifactsEmptyStateRow: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color("MintGreen").opacity(0.14))
                    .frame(width: 38, height: 38)
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color("MintGreen").opacity(0.92))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.custom("Poppins-SemiBold", size: 14))
                    .foregroundColor(Color.white.opacity(0.90))

                Text(message)
                    .font(.custom("Poppins-Regular", size: 12))
                    .foregroundColor(Color.white.opacity(0.65))
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}

private struct MyArtifactsDangerButton: View {
    let title: String
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            Text(title)
                .font(.custom("Poppins-SemiBold", size: 13))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: 72)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .foregroundColor(Color.white.opacity(0.90))
                .background(Color.red.opacity(0.22))
                .overlay(
                    Capsule().stroke(Color.red.opacity(0.30), lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
