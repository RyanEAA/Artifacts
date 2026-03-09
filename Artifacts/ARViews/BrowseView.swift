//
//  BrowseView.swift
//  ARTutorial
//
//  Created by Ryan Aparicio on 10/8/25.
//

import SwiftUI

struct BrowseView: View {
    @Binding var showBrowse: Bool

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                AnnotationToolButton(showBrowse: $showBrowse)
                VStack(spacing: 18) {
                    RecentsGrid(showBrowse: $showBrowse)
                    ModelsByCategoryGrid(showBrowse: $showBrowse)
                }
                .padding(.top, 10)
                .padding(.bottom, 18)
            }
            .artifactsSheetBackground()
            .navigationTitle("Browse")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showBrowse.toggle()
                    } label: {
                        Text("Done")
                            .font(.custom("Poppins-SemiBold", size: 15))
                            .foregroundColor(Color("MintGreen").opacity(0.92))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color("MintGreen").opacity(0.18), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .tint(Color("MintGreen"))
    }
}

// MARK: - Tool definitions
// To add a new tool (e.g. Draw), append an ARTool entry to arTools below.

private struct ARTool {
    let title: String
    let icon: String        // SF Symbol name
    let accentColor: Color
    let tool: PlacementTool
}

private let arTools: [ARTool] = [
    ARTool(
        title: "Annotate",
        icon: "text.bubble.fill",
        accentColor: Color("MintGreen"),
        tool: .annotation
    ),
    ARTool(
        title: "Draw",
        icon: "scribble.variable",
        accentColor: Color("MintGreen"),
        tool: .draw
    ),
]

struct AnnotationToolButton: View {
    @EnvironmentObject var placementSettings: PlacementSettings
    @Binding var showBrowse: Bool

    private let gridLayout = [GridItem(.fixed(150))]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tools")
                .font(.custom("Poppins-SemiBold", size: 18))
                .foregroundColor(Color.white.opacity(0.92))
                .padding(.horizontal, 18)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: gridLayout, spacing: 14) {
                    ForEach(arTools, id: \.title) { arTool in
                        ToolCard(tool: arTool) {
                            placementSettings.selectedTool = arTool.tool
                            showBrowse = false
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
            }
        }
        .padding(.top, 4)
    }
}

/// Matches the exact look of ItemButton — 150x150 card with icon, gradient, and label.
private struct ToolCard: View {
    let tool: ARTool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                // Background: dark glass with subtle accent tint
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(tool.accentColor.opacity(0.08))
                    )
                    .frame(width: 150, height: 150)

                // Large centred icon
                Image(systemName: tool.icon)
                    .font(.system(size: 52, weight: .medium))
                    .foregroundColor(tool.accentColor.opacity(0.88))
                    .frame(width: 150, height: 150)

                // Bottom gradient + label — identical to ItemButton
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.65),
                        Color.black.opacity(0.00)
                    ]),
                    startPoint: .bottom,
                    endPoint: .center
                )
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(tool.title)
                    .font(.custom("Poppins-SemiBold", size: 12))
                    .foregroundColor(Color.white.opacity(0.92))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }
            .frame(width: 150, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(tool.accentColor.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.40), radius: 14, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }
}

struct RecentsGrid: View {
    @EnvironmentObject var placeSettings: PlacementSettings
    @Binding var showBrowse: Bool

    var body: some View {
        if !self.placeSettings.recentlyPlaced.isEmpty {
            HorizontalGrid(showBrowse: $showBrowse, title: "Recents", items: getRecentsUniqueOrdered())
        }
    }

    func getRecentsUniqueOrdered() -> [Model] {
        var recentUniqueOrderedArray: [Model] = []
        var modelNameSet: Set<String> = []

        for model in self.placeSettings.recentlyPlaced.reversed() {
            if !modelNameSet.contains(model.name) {
                recentUniqueOrderedArray.append(model)
                modelNameSet.insert(model.name)
            }
        }
        return recentUniqueOrderedArray
    }
}

struct ModelsByCategoryGrid: View {
    @EnvironmentObject private var modelsViewModel: ModelsViewModel
    @Binding var showBrowse: Bool

    var body: some View {
        VStack(spacing: 18) {
            ForEach(ModelCategory.allCases, id: \.self) { category in
                let modelsByCategory = modelsViewModel.models.filter { $0.category == category }
                if !modelsByCategory.isEmpty {
                    HorizontalGrid(showBrowse: $showBrowse, title: category.label, items: modelsByCategory)
                }
            }
        }
    }
}

struct HorizontalGrid: View {
    @EnvironmentObject var placementSettings: PlacementSettings
    @Binding var showBrowse: Bool
    var title: String
    var items: [Model]

    private let gridItemLayout = [GridItem(.fixed(150))]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.custom("Poppins-SemiBold", size: 18))
                    .foregroundColor(Color.white.opacity(0.92))
                Spacer()
            }
            .padding(.horizontal, 18)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: gridItemLayout, spacing: 14) {
                    ForEach(0..<items.count, id: \.self) { index in
                        let model = items[index]
                        ItemButton(model: model) {
                            placementSettings.isModelLoadInProgress = true
                            placementSettings.modelLoadMessage = "Loading \(model.name)..."
                            self.showBrowse = false

                            model.asyncLoadModelEntity { completed, _ in
                                DispatchQueue.main.async {
                                    placementSettings.isModelLoadInProgress = false
                                    placementSettings.modelLoadMessage = ""
                                    if completed {
                                        self.placementSettings.selectedTool = .model(model)
                                    }
                                }
                            }
                            print("BrowseView: selected \(model.name) for placement")
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
            }
        }
        .padding(.top, 4)
    }
}

struct ItemButton: View {
    @ObservedObject var model: Model
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                Image(uiImage: self.model.thumbnail)
                    .resizable()
                    .frame(width: 150, height: 150)
                    .aspectRatio(1/1, contentMode: .fill)
                    .clipped()

                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.65),
                        Color.black.opacity(0.00)
                    ]),
                    startPoint: .bottom,
                    endPoint: .center
                )

                Text(model.name)
                    .font(.custom("Poppins-SemiBold", size: 12))
                    .foregroundColor(Color.white.opacity(0.92))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.40), radius: 14, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }
}
