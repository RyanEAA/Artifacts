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

struct AnnotationToolButton: View {
    @EnvironmentObject var placementSettings: PlacementSettings
    @Binding var showBrowse: Bool
    
    var body: some View {
        VStack(alignment: .leading) {

            Spacer()

            Text("Tools")
                .font(.title2).bold()
                .padding(.leading, 22)

            Button(action: {
                placementSettings.selectedTool = .annotation
                showBrowse = false
            }) {
                HStack {
                    Image(systemName: "text.bubble.fill")
                        .font(.largeTitle)

                    Text("Annotation")
                        .font(.headline)
                }
                .padding()
//                .background(Color.secondarySystemFill)
                .cornerRadius(10)
            }
            .padding(.horizontal, 22)
        }
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
                            model.asyncLoadModelEntity { completed, _ in
                                if completed {
//                                    self.placementSettings.selectedModel = model
                                    self.placementSettings.selectedTool = .model(model)
                                }
                            }
                            print("BrowseView: selected \(model.name) for placement")
                            self.showBrowse = false
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
