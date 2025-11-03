//
//  BrowseView.swift
//  ARTutorial
//
//  Created by Ryan Aparicio on 10/8/25.
//

import SwiftUI

struct BrowseView: View{
    @Binding var showBrowse: Bool
    
    var body: some View{
        NavigationView {
            ScrollView(showsIndicators: false){
                // gridviews for thumbnails
                RecentsGrid(showBrowse: $showBrowse)
                ModelsByCategoryGrid(showBrowse: $showBrowse)
            }
            .navigationBarTitle(Text("Browse"), displayMode: .large)
            .navigationBarItems(trailing:
                    Button(action: {
                self.showBrowse.toggle()
            }){
                Text("Done").bold()
            })
                
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
        VStack {
            ForEach(ModelCategory.allCases, id: \.self){ category in
                // only display if category contains items
                let modelsByCategory = modelsViewModel.models.filter{ $0.category == category  }
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
        VStack(alignment: .leading) {
            Seperator()
            Text(title)
                .font(.title2).bold()
                .padding(.leading, 22)
                .padding(.top, 10)
            ScrollView(.horizontal, showsIndicators: false){
                LazyHGrid(rows: gridItemLayout, spacing: 20){
                    ForEach(0..<items.count, id: \.self){ index in
                        let model = items[index]
                        
                        ItemButton(model: model){
                            model.asyncLoadModelEntity { completed, error in
                                if completed {
                                    self.placementSettings.selectedModel = model

                                }
                            }
                            //TODO: select model for placement
                            print("BrowseView: selected \(model.name) for placecement")
                            self.showBrowse = false
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
            }
        }
    }
}

struct ItemButton: View {
    @ObservedObject var model: Model
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            self.action()
        }){
            Image(uiImage: self.model.thumbnail)
                .resizable()
                .frame(height: 150)
                .aspectRatio(1/1, contentMode: .fit)
                .background(Color(UIColor.secondarySystemFill))
                .cornerRadius(8)
        }
        
    }
}

struct Seperator: View {
    var body: some View {
        Divider()
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

    }
}

