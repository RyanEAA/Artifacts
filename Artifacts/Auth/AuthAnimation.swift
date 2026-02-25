//
//  AuthAnimation.swift
//  Artifacts
//
//  Created by Swapnil Puri on 9/21/25.
//

import SwiftUI

struct AnimatedRevealHeader: View {
    var hiddenImages: [String]
    var wallRows: Int = 5
    var wallCols: Int = 8
    
    var headerHeight: CGFloat = 160
    var phoneWidth: CGFloat = 92
    var phoneHeight: CGFloat = 140
    var phoneTravelDuration: Double = 4
    
    @State private var animatePhone = false
    @State private var currentImageIndex = 0
    @State private var loopTask: Task<Void, Never>?
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var showBricks: Bool
    
    var body: some View {
        GeometryReader { fullGeo in
            let totalH = headerHeight
            let wallW = min(fullGeo.size.width * 0.56, 420)
            let wallH = min(totalH * 0.85, 140)
            let cx = fullGeo.size.width / 2
            let cy = totalH / 2
            let startX = cx - wallW/2 - phoneWidth/2 - 10
            let endX   = cx + wallW/2 + phoneWidth/2 + 10
            
            ZStack {
                BrickWallView(
                    width: wallW,
                    height: wallH,
                    rows: wallRows,
                    cols: wallCols,
                    showBricks: $showBricks
                )
                .position(x: cx, y: cy)
                
                if let imageName = safeImageName {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: wallW * 0.88, height: wallH * 0.7)
                        .position(x: cx, y: cy)
                        .compositingGroup()
                        .mask(
                            RoundedRectangle(cornerRadius: 10)
                                .frame(width: phoneWidth * 0.86, height: phoneHeight * 0.76)
                                .position(x: reduceMotion ? cx : (animatePhone ? endX : startX), y: cy)
                        )
                        .accessibilityHidden(true)
                }
                
                PhoneView()
                    .frame(width: phoneWidth, height: phoneHeight)
                    .position(x: reduceMotion ? cx : (animatePhone ? endX : startX), y: cy)
                    .opacity(showBricks ? 1 : 0)
                    .animation(.easeOut(duration: 1), value: showBricks)
                    .shadow(color: Color.black.opacity(0.60), radius: 12, x: 0, y: 10)
                    .accessibilityHidden(true)
            }
            .frame(width: fullGeo.size.width, height: totalH)
            .onAppear { startLoopIfNeeded() }
            .onDisappear { stopLoop() }
        }
        .frame(height: headerHeight)
    }
    
    private var safeImageName: String? {
        guard !hiddenImages.isEmpty else { return nil }
        let idx = max(0, min(currentImageIndex, hiddenImages.count - 1))
        return hiddenImages[idx]
    }
    
    private func startLoopIfNeeded() {
        stopLoop()
        
        guard !reduceMotion, hiddenImages.count > 1 else {
            animatePhone = false
            currentImageIndex = 0
            return
        }
        
        loopTask = Task { @MainActor in
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: phoneTravelDuration)) {
                    animatePhone.toggle()
                }
                try? await Task.sleep(nanoseconds: UInt64(phoneTravelDuration * 1_000_000_000))
                
                if Task.isCancelled { break }
                currentImageIndex = (currentImageIndex + 1) % hiddenImages.count
            }
        }
    }
    
    private func stopLoop() {
        loopTask?.cancel()
        loopTask = nil
    }
}

struct BrickWallView: View {
    let width: CGFloat
    let height: CGFloat
    let rows: Int
    let cols: Int
    
    @Binding var showBricks: Bool
    
    var body: some View {
        GeometryReader { geo in
            let mortarSize: CGFloat = max(4, min(8, width / 80))
            let effectiveW = geo.size.width
            let effectiveH = geo.size.height
            
            let brickW = (effectiveW - CGFloat(cols + 2) * mortarSize) / CGFloat(Double(cols) + 0.1)
            let brickH = (effectiveH - CGFloat(rows + 1) * mortarSize) / CGFloat(rows)
            
            ForEach(0..<rows, id: \.self) { r in
                let colsForRow = (r % 2 == 1) ? cols + 1 : cols
                ForEach(0..<colsForRow, id: \.self) { c in
                    let xShift = (r % 2 == 1) ? (brickW / 2) : 0
                    let x = CGFloat(c) * (brickW + mortarSize) + mortarSize + xShift + brickW / 2
                    let y = CGFloat(r) * (brickH + mortarSize) + mortarSize + brickH / 2
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.14))
                        .frame(width: brickW, height: brickH)
                        .position(x: x, y: y)
                        .opacity(showBricks ? 1 : 0)
                        .animation(.easeOut(duration: 0.9), value: showBricks)
                }
            }
        }
        .frame(width: width, height: height)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color("MintGreen").opacity(0.18), lineWidth: 1)
        )
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.26))
        )
    }
}

struct PhoneView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color("MintGreen"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 7)
                        .blendMode(.destinationOut)
                )
                .compositingGroup()
            
            VStack {
                Capsule()
                    .frame(width: 36, height: 5)
                    .foregroundColor(Color("MintGreen"))
                    .padding(.top, 10)
                Spacer()
                Circle()
                    .frame(width: 6, height: 6)
                    .foregroundColor(Color("MintGreen"))
                    .padding(.bottom, 10)
            }
            .allowsHitTesting(false)
        }
    }
}
