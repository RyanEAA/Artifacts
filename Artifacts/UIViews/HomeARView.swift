import SwiftUI

enum PlacingMode { case text, model }
private enum PrimaryFAB { case plus, camera }

struct HomeARView: View {
    @State private var showOptions = false
    @State private var placingMode: PlacingMode = .model
    @State private var primary: PrimaryFAB = .plus
    @Namespace private var fabNS
    
    var body: some View {
        ZStack {
            ARViewContainer()
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Options appear above when plus is active
                if showOptions {
                    VStack(spacing: 12) {
                        Button {
                            placingMode = .text
                            showOptions = !showOptions // closes menu
                        } label: {
                            HStack { Image(systemName: "textformat"); Text("Place Textbox") }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        Button {
                            placingMode = .model
                            showOptions = !showOptions // closes menu
                        } label: {
                            HStack { Image(systemName: "cube"); Text("Place Model") }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // FAB row
                ZStack {
                    // Primary button in the center
                    if primary == .plus {
                        fabPlus(primary: true)
                            .matchedGeometryEffect(id: "FAB_PRIMARY", in: fabNS)
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    primary = .plus
                                    showOptions = true
                                }
                            }
                    } else {
                        fabCamera(primary: true)
                            .matchedGeometryEffect(id: "FAB_PRIMARY", in: fabNS)
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    primary = .camera
                                    showOptions = false
                                }
                                // trigger screenshot action here
                            }
                    }
                    
                    // Secondary button off to the right
                    HStack {
                        Spacer()
                        if primary == .plus {
                            fabCamera(primary: false)
                                .matchedGeometryEffect(id: "FAB_SECONDARY", in: fabNS)
                                .onTapGesture {
                                    withAnimation(.spring()) {
                                        primary = .camera
                                        showOptions = false
                                    }
                                    // trigger screenshot action here
                                }
                        } else {
                            fabPlus(primary: false)
                                .matchedGeometryEffect(id: "FAB_SECONDARY", in: fabNS)
                                .onTapGesture {
                                    withAnimation(.spring()) {
                                        primary = .plus
                                        showOptions = true
                                    }
                                }
                        }
                    }
                    .padding(.trailing, 20)
                }
                .padding(.bottom, 12)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
    
    // MARK: - Buttons
    
    private func fabPlus(primary: Bool) -> some View {
        // changes the bottom icon to be textformat or cube
        let icon = placingMode == .text ? "textformat" : "cube"
        return Image(systemName: icon)
                .font(.title2)
                .padding(20)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(radius: primary ? 8 : 2)
                .scaleEffect(primary ? 1.0 : 0.85)
                .opacity(primary ? 1.0 : 0.6) // dim secondary
    }
    
    private func fabCamera(primary: Bool) -> some View {
        Image(systemName: "camera")
            .font(.title2)
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .shadow(radius: primary ? 8 : 2)
            .scaleEffect(primary ? 1.0 : 0.85)
            .opacity(primary ? 1.0 : 0.6) // dim secondary
    }
}
#Preview {
    HomeARView()
}
