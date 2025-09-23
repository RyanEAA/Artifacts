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
    @Binding var showBricks: Bool

    var body: some View {
        GeometryReader { fullGeo in
            let totalW = fullGeo.size.width
            let totalH = headerHeight
            let wallW = min(totalW * 0.56, 420)
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

                Image(hiddenImages[currentImageIndex])
                    .resizable()
                    .scaledToFit()
                    .frame(width: wallW * 0.88, height: wallH * 0.7)
                    .position(x: cx, y: cy)
                    .compositingGroup()
                    .mask(
                        RoundedRectangle(cornerRadius: 10)
                            .frame(width: phoneWidth * 0.86, height: phoneHeight * 0.76)
                            .position(x: animatePhone ? endX : startX, y: cy)
                    )

                PhoneView()
                    .frame(width: phoneWidth, height: phoneHeight)
                    .position(x: animatePhone ? endX : startX, y: cy)
            }
            .frame(width: fullGeo.size.width, height: totalH)
            .onAppear {
                animatePhoneLoop()
            }
        }
        .frame(height: headerHeight)
    }

    func animatePhoneLoop() {
        withAnimation(.easeInOut(duration: phoneTravelDuration)) {
            animatePhone.toggle()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + phoneTravelDuration) {
            currentImageIndex = (currentImageIndex + 1) % hiddenImages.count
            animatePhoneLoop()
        }
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
                        .fill(Color.white)
                        .frame(width: brickW, height: brickH)
                        .position(x: x, y: y)
                        .opacity(showBricks ? 1 : 0)
                }
            }
        }
        .frame(width: width, height: height)
        .cornerRadius(4)
    }
}

struct PhoneView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color("DarkGray"))
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
                    .foregroundColor(Color("DarkGray"))
                    .padding(.top, 10)
                Spacer()
                Circle()
                    .frame(width: 6, height: 6)
                    .foregroundColor(Color("DarkGray"))
                    .padding(.bottom, 10)
            }
            .allowsHitTesting(false)
        }
    }
}
