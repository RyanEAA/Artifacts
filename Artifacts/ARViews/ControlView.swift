//
//  ControlView.swift
//  ARTutorial
//
//  Created by Ryan Aparicio on 10/7/25.
//

import SwiftUI
import UIKit
import RealityKit

enum ControlModes: String, CaseIterable {
    case browse, scene
}

struct BrowseButtons: View {
    @EnvironmentObject var placementSettings: PlacementSettings
    @Binding var showBrowse: Bool
    @Binding var showSettings: Bool
    @Binding var showProfile: Bool
    var body: some View {
        HStack {
            Spacer()

            MostRecentlyPlacedButton()
                .hidden(self.placementSettings.recentlyPlaced.isEmpty)

            Spacer()
            Spacer()

            ControlButton(systemIconName: "square.grid.2x2") {
                print("Browse Button Pressed...")
                self.showBrowse.toggle()
            }
            .sheet(isPresented: $showBrowse) {
                BrowseView(showBrowse: $showBrowse)
                    .environmentObject(placementSettings)
                    .preferredColorScheme(.dark)
                    .presentationBackground(.black)
            }

            Spacer()
            Spacer()

            ControlButton(systemIconName: "slider.horizontal.3") {
                print("Settings Button Pressed...")
                self.showSettings.toggle()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(showSettings: $showSettings)
                    .preferredColorScheme(.dark)
                    .presentationBackground(.black)
            }

            Spacer()
        }
    }
}

// ControlView.swift → SceneButtons
struct SceneButtons: View {
    @EnvironmentObject var sceneManager: SceneManager

    var body: some View {
        // SAVE (cloud)
        ControlButton(systemIconName: "icloud.and.arrow.up") {
            guard !sceneManager.isPersistenceInProgress else { return }
            print("Save Scene Button Pressed..")
            sceneManager.shouldSaveSceneToCloud = true
            sceneManager.beginPersistenceProgress("Saving scene...")
        }
        .hidden(!sceneManager.isPersistenceAvailable)
        .disabled(sceneManager.isPersistenceInProgress)

        Spacer()

        // LOAD (cloud)
        ControlButton(systemIconName: "icloud.and.arrow.down") {
            guard !sceneManager.isPersistenceInProgress else { return }
            print("Load Scene Button Pressed")
            sceneManager.beginPersistenceProgress("Finding latest scene...")

            CloudSceneStore.fetchMostRecentSceneMeta { result in
                switch result {
                case .success(let meta):
                    if let meta {
                        DispatchQueue.main.async {
                            self.sceneManager.selectedCloudSceneId = meta.id
                            print("Attemping to load scene with id: \(meta.id)")
                            self.sceneManager.updatePersistenceProgress("Loading scene...")
                            self.sceneManager.shouldLoadSceneFromCloud = true
                        }
                    } else {
                        print("No cloud scene found to load.")
                        self.sceneManager.endPersistenceProgress()
                        self.sceneManager.postPersistenceNotice(
                            "No saved scene found to load.",
                            style: .info
                        )
                    }
                case .failure(let e):
                    print("Failed to fetch latest scene meta on tap:", e)
                    self.sceneManager.endPersistenceProgress()
                    self.sceneManager.postPersistenceNotice(
                        "Failed to find a scene to load.",
                        style: .error
                    )
                }
            }
        }
        .hidden(sceneManager.selectedCloudSceneId == nil)
        .disabled(sceneManager.isPersistenceInProgress)

        .onAppear {
            CloudSceneStore.fetchMostRecentSceneMeta { result in
                switch result {
                case .success(let meta):
                    if let meta {
                        DispatchQueue.main.async {
                            self.sceneManager.selectedCloudSceneId = meta.id
                        }
                    }
                case .failure(let e):
                    print("Failed to fetch latest scene meta on appear:", e)
                }
            }
        }

        Spacer()

        ControlButton(systemIconName: "trash") {
            guard !sceneManager.isPersistenceInProgress else { return }
            print("clear scene button pressed")
            for anchorEntity in sceneManager.anchorEntities {
                print("Removing anchoEntity with id: \(String(describing: anchorEntity.anchorIdentifier)))")
                anchorEntity.removeFromParent()
            }
            sceneManager.anchorEntities.removeAll()

            for (_, tv) in sceneManager.annotationViews {
                tv.removeFromSuperview()
            }
            sceneManager.annotationViews.removeAll()
            sceneManager.isEditing.removeAll()
            sceneManager.hasBeenTapped.removeAll()

            NotificationCenter.default.post(name: .clearAllAnnotations, object: nil)
            NotificationCenter.default.post(name: .clearAllDrawingStrokes, object: nil)
        }
        .disabled(sceneManager.isPersistenceInProgress)
    }
}



struct ControlView: View {
    @Binding var selectedControlMode: Int
    @Binding var isControlsVisible: Bool
    @Binding var showBrowse: Bool
    @Binding var showSettings: Bool

    @State private var showProfile = false
    @State private var showCamera = false
    @State private var capturedPhoto: UIImage?

    @EnvironmentObject var sceneManager: SceneManager

    var body: some View {
        ZStack {

            // MARK: Controls Mode
            if isControlsVisible {
                VStack {

                    HStack {
                        ProfileViewButton(isProfileVisible: $showProfile)
                            .sheet(isPresented: $showProfile) {
                                QuickProfileView()
                                    .preferredColorScheme(.dark)
                                    .presentationBackground(.black)
                            }

                        Spacer()
                    }
                    .padding(.top, 10)
                    .padding(.leading, 20)

                    Spacer()

                    ControlModePicker(selectedControlMode: $selectedControlMode)

                    ControlButtonBar(
                        showBrowse: $showBrowse,
                        showSettings: $showSettings,
                        showProfile: $showProfile,
                        selectedControlMode: $selectedControlMode
                    )
                }
            }

            // MARK: Camera Mode
            else {
                VStack {
                    Spacer()

                    CameraButton(action: takeSnapshot)
                        .padding(.bottom, 40)
                }
            }

            // MARK: Visibility Toggle (ALWAYS VISIBLE)
            VStack {
                HStack {
                    Spacer()

                    ControlVisibilityToggleButton(isControlsVisible: $isControlsVisible)
                }
                .padding(.top, 10)
                .padding(.trailing, 20)

                Spacer()
            }

            if sceneManager.isPersistenceInProgress {
                PersistenceLoadingOverlay(text: sceneManager.persistenceProgressText)
            }

            if let notice = sceneManager.persistenceNotice {
                PersistenceCenteredNoticeOverlay(notice: notice)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isControlsVisible)
        .animation(.easeInOut(duration: 0.2), value: sceneManager.isPersistenceInProgress)
        .animation(.easeInOut(duration: 0.2), value: sceneManager.persistenceNotice?.id)
        .sheet(isPresented: $showCamera) {
            if let photo = capturedPhoto {
                PhotoPreviewView(image: photo, isPresented: $showCamera)
                    .preferredColorScheme(.dark)
                    .presentationBackground(.black)
            }
        }
    }
}

private extension ControlView {

    func takeSnapshot() {

        guard let arView = sceneManager.arView else { return }

        arView.snapshot(saveToHDR: false) { image in
            guard let image else { return }

            DispatchQueue.main.async {
                capturedPhoto = composeSnapshotWithAnnotations(baseImage: image, in: arView)
                showCamera = true
            }
        }
    }

    func composeSnapshotWithAnnotations(baseImage: UIImage, in arView: ARView) -> UIImage {
        let imageSize = CGSize(width: baseImage.size.width, height: baseImage.size.height)
        let viewSize = arView.bounds.size
        guard imageSize.width > 0, imageSize.height > 0, viewSize.width > 0, viewSize.height > 0 else {
            return baseImage
        }

        let scaleX = imageSize.width / viewSize.width
        let scaleY = imageSize.height / viewSize.height

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = baseImage.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: imageSize, format: format)
        return renderer.image { _ in
            baseImage.draw(in: CGRect(origin: .zero, size: imageSize))

            for tv in sceneManager.annotationViews.values {
                guard !tv.isHidden, tv.alpha > 0.01 else { continue }
                let frameInARView = tv.convert(tv.bounds, to: arView)
                guard frameInARView.intersects(arView.bounds) else { continue }

                let scaledFrame = CGRect(
                    x: frameInARView.origin.x * scaleX,
                    y: frameInARView.origin.y * scaleY,
                    width: frameInARView.size.width * scaleX,
                    height: frameInARView.size.height * scaleY
                )

                UIGraphicsGetCurrentContext()?.saveGState()
                UIGraphicsGetCurrentContext()?.translateBy(x: scaledFrame.origin.x, y: scaledFrame.origin.y)
                UIGraphicsGetCurrentContext()?.scaleBy(x: scaleX, y: scaleY)
                tv.layer.render(in: UIGraphicsGetCurrentContext()!)
                UIGraphicsGetCurrentContext()?.restoreGState()
            }
        }
    }
}



// MARK: - Camera Button

struct CameraButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "camera")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color("MintGreen").opacity(0.92))
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color("MintGreen").opacity(0.18), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.trailing, 10)
    }
}

// MARK: - Photo Preview Sheet

struct PhotoPreviewView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    @State private var showShareSheet = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(Color("MintGreen"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color("MintGreen").opacity(0.18), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("Photo")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    // Balance the back button width
                    Color.clear
                        .frame(width: 80, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Divider()
                    .background(Color.white.opacity(0.08))

                // Photo preview
                Spacer()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color("MintGreen").opacity(0.12), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 8)

                Spacer()

                // Share button
                Button(action: {
                    showShareSheet = true
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Share")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color("MintGreen"))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [image])
        }
    }
}

// MARK: - UIKit Share Sheet Bridge

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Existing views (unchanged below)

struct ControlVisibilityToggleButton: View{
    @Binding var isControlsVisible: Bool
    var body: some View{
        HStack{
            Spacer()

            Button(action: {
                print("Control Visibility Toggle Button Pressed")
                self.isControlsVisible.toggle()
            }) {
                Image(systemName: self.isControlsVisible ? "rectangle" : "slider.horizontal.below.rectangle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color("MintGreen").opacity(0.92))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color("MintGreen").opacity(0.18), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 45)
        .padding(.trailing, 20)
    }
}

struct ProfileViewButton: View{
    @Binding var isProfileVisible: Bool
    var body: some View{
        HStack{

            Button(action: {
                print("Profile Button Pressed")
                self.isProfileVisible.toggle()
            }) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color("MintGreen").opacity(0.92))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color("MintGreen").opacity(0.18), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 45)
        .padding(.leading, 20)
    }
}

struct ControlModePicker: View {
    @Binding var selectedControlMode: Int

    var body: some View {
        HStack(spacing: 0) {
            ModeTab(label: "BROWSE", index: 0, selectedControlMode: $selectedControlMode)
            ModeTab(label: "SCENE",  index: 1, selectedControlMode: $selectedControlMode)
        }
        .frame(maxWidth: 400)
        .padding(4)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color("MintGreen").opacity(0.14), lineWidth: 1)
        )
    }
}

private struct ModeTab: View {
    let label: String
    let index: Int
    @Binding var selectedControlMode: Int

    private var isSelected: Bool { selectedControlMode == index }

    var body: some View {
        Button {
            print("ControlModePicker: tapped \(label) → selectedControlMode = \(index)")
            selectedControlMode = index
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    isSelected ? Color("MintGreen") : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct ControlButtonBar: View{
    @Binding var showBrowse: Bool
    @Binding var showSettings: Bool
    @Binding var showProfile: Bool
    @Binding var selectedControlMode: Int
    
    var body: some View {
        HStack(alignment: .center) {
            if selectedControlMode == 1 {
                SceneButtons()
            } else {
                BrowseButtons(showBrowse: $showBrowse,
                              showSettings: $showSettings,
                              showProfile: $showProfile)
            }
        }
        .frame(maxWidth: 500)
        .padding(18)
        .background(Color.black.opacity(0.36))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .padding(.bottom, 18)
    }
}

struct ControlButton: View {
    let systemIconName: String
    let action: () -> Void
    var body: some View {
        Button(action: {
            self.action()
        }) {
            Image(systemName: self.systemIconName)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.white.opacity(0.92))
                .frame(width: 50, height: 50)
                .background(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color("MintGreen").opacity(0.16), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct MostRecentlyPlacedButton: View{
    @EnvironmentObject var placementSettings: PlacementSettings
    var body: some View{
        Button(action:{
            print("most recently placed button pressed")
            if let model = self.placementSettings.recentlyPlaced.last {
                self.placementSettings.selectedTool = .model(model)
            }
        }){
            if let mostRecentlyPlacedModel = self.placementSettings.recentlyPlaced.last {
                Image(uiImage: mostRecentlyPlacedModel.thumbnail)
                    .resizable()
                    .frame(width: 44, height: 44)
                    .aspectRatio(1/1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color("MintGreen").opacity(0.18), lineWidth: 1)
                    )
            } else {
                Image(systemName: "clock.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color("MintGreen").opacity(0.92))
            }
        }
        .frame(width: 50, height: 50)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color("MintGreen").opacity(0.16), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct PersistenceLoadingOverlay: View {
    let text: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.30)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color("MintGreen")))
                    .scaleEffect(1.2)

                Text(text.isEmpty ? "Working..." : text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 20)
            .background(Color.black.opacity(0.78))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color("MintGreen").opacity(0.26), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .allowsHitTesting(true)
    }
}

private struct PersistenceCenteredNoticeOverlay: View {
    let notice: PersistenceNotice

    private var accent: Color {
        switch notice.style {
        case .info:
            return Color("MintGreen")
        case .success:
            return Color("MintGreen")
        case .error:
            return Color.red
        }
    }

    private var icon: String {
        switch notice.style {
        case .info:
            return "info.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(accent.opacity(0.95))
                Text(notice.message)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 20)
            .background(Color.black.opacity(0.78))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(accent.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .allowsHitTesting(false)
    }
}
