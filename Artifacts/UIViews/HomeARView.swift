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
                    VStack(spacing: 10) {
                        optionRow(icon: "textformat", title: "Place Textbox") {
                            placingMode = .text
                            showOptions = false
                        }

                        optionRow(icon: "cube", title: "Place Model") {
                            placingMode = .model
                            showOptions = false
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .artifactsPanel(cornerRadius: 22)
                    .padding(.horizontal, 18)
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
        return fabBase(icon: icon, primary: primary)
    }
    
    private func fabCamera(primary: Bool) -> some View {
        fabBase(icon: "camera", primary: primary)
    }

    private func optionRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color("MintGreen"))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color("MintGreen").opacity(0.18), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(title)
                    .font(.custom("Poppins-SemiBold", size: 15))
                    .foregroundColor(Color.white.opacity(0.92))

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.45))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func fabBase(icon: String, primary: Bool) -> some View {
        let size: CGFloat = primary ? 58 : 52
        let bg = primary ? Color("MintGreen") : Color.black.opacity(0.46)
        let fg = primary ? Color.black.opacity(0.92) : Color.white.opacity(0.92)

        return Image(systemName: icon)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(fg)
            .frame(width: size, height: size)
            .background(bg)
            .overlay(
                Circle().stroke(primary ? Color("MintGreen").opacity(0.30) : Color("MintGreen").opacity(0.18), lineWidth: 1)
            )
            .clipShape(Circle())
            .shadow(color: Color.black.opacity(primary ? 0.45 : 0.28), radius: primary ? 18 : 10, x: 0, y: primary ? 12 : 8)
            .scaleEffect(primary ? 1.0 : 0.88)
            .opacity(primary ? 1.0 : 0.72)
    }
}
#Preview {
    HomeARView()
}
