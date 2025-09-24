import SwiftUI

struct HomeARView: View {
    var body: some View {
        ZStack {
            ARViewContainer()
                .ignoresSafeArea()
        }
    }
}

#Preview {
    HomeARView()
}
