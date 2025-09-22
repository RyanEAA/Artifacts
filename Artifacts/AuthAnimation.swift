//
//  AuthAnimation.swift
//  Artifacts
//
//  Created by Swapnil Puri on 9/21/25.
//

import SwiftUI

struct HappyFace: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        path.addEllipse(in: rect)
        
        path.addEllipse(in: CGRect(x: rect.midX - rect.width * 0.25,
                                   y: rect.midY - rect.height * 0.25,
                                   width: rect.width * 0.1,
                                   height: rect.height * 0.1))
        
        path.addEllipse(in: CGRect(x: rect.midX + rect.width * 0.15,
                                   y: rect.midY - rect.height * 0.25,
                                   width: rect.width * 0.1,
                                   height: rect.height * 0.1))
        
        path.addArc(center: CGPoint(x: center.x, y: center.y + rect.height * 0.15),
                    radius: rect.width * 0.25,
                    startAngle: .degrees(20),
                    endAngle: .degrees(160),
                    clockwise: false)
        return path
    }
}

struct Car: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        let bodyHeight = h * 0.35
        let bodyRect = CGRect(x: rect.minX + w * 0.1,
                              y: rect.maxY - bodyHeight,
                              width: w * 0.8,
                              height: bodyHeight)
        path.addRect(bodyRect)
        
        let roofHeight = h * 0.25
        let roofY = bodyRect.minY - roofHeight
        let roofStart = CGPoint(x: bodyRect.minX + w * 0.15, y: bodyRect.minY)
        let roofEnd = CGPoint(x: bodyRect.maxX - w * 0.15, y: bodyRect.minY)
        path.move(to: roofStart)
        path.addLine(to: CGPoint(x: roofStart.x + w * 0.1, y: roofY))
        path.addLine(to: CGPoint(x: roofEnd.x - w * 0.1, y: roofY))
        path.addLine(to: roofEnd)
        path.addLine(to: roofStart)
        
        let wheelRadius = h * 0.12
        let leftWheelCenter = CGPoint(x: bodyRect.minX + w * 0.2,
                                      y: bodyRect.maxY)
        let rightWheelCenter = CGPoint(x: bodyRect.maxX - w * 0.2,
                                       y: bodyRect.maxY)
        
        path.move(to: CGPoint(x: leftWheelCenter.x + wheelRadius,
                              y: leftWheelCenter.y))
        path.addArc(center: leftWheelCenter,
                    radius: wheelRadius,
                    startAngle: .degrees(0),
                    endAngle: .degrees(180),
                    clockwise: false)
        
        path.addArc(center: rightWheelCenter,
                    radius: wheelRadius,
                    startAngle: .degrees(0),
                    endAngle: .degrees(180),
                    clockwise: false)
        
        return path
    }
}

struct StickFigure: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        path.addEllipse(in: CGRect(x: center.x - rect.width * 0.15,
                                   y: rect.minY,
                                   width: rect.width * 0.3,
                                   height: rect.width * 0.3))
        
        path.move(to: CGPoint(x: center.x, y: rect.minY + rect.width * 0.3))
        path.addLine(to: CGPoint(x: center.x, y: rect.maxY - rect.height * 0.25))
        
        path.move(to: CGPoint(x: center.x - rect.width * 0.25,
                              y: rect.minY + rect.height * 0.4))
        path.addLine(to: CGPoint(x: center.x + rect.width * 0.25,
                                 y: rect.minY + rect.height * 0.4))
        
        path.move(to: CGPoint(x: center.x, y: rect.maxY - rect.height * 0.25))
        path.addLine(to: CGPoint(x: center.x - rect.width * 0.2,
                                 y: rect.maxY))
        path.move(to: CGPoint(x: center.x, y: rect.maxY - rect.height * 0.25))
        path.addLine(to: CGPoint(x: center.x + rect.width * 0.2,
                                 y: rect.maxY))
        
        return path
    }
}

struct Heart: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        path.move(to: CGPoint(x: width / 2, y: height))
        
        path.addCurve(to: CGPoint(x: 0, y: height / 4),
                      control1: CGPoint(x: width / 2, y: height * 0.75),
                      control2: CGPoint(x: 0, y: height / 2))
        
        path.addArc(center: CGPoint(x: width * 0.25, y: height / 4),
                    radius: width * 0.25,
                    startAngle: .degrees(180),
                    endAngle: .degrees(0),
                    clockwise: false)
        
        path.addArc(center: CGPoint(x: width * 0.75, y: height / 4),
                    radius: width * 0.25,
                    startAngle: .degrees(180),
                    endAngle: .degrees(0),
                    clockwise: false)
        
        path.addCurve(to: CGPoint(x: width / 2, y: height),
                      control1: CGPoint(x: width, y: height / 2),
                      control2: CGPoint(x: width / 2, y: height * 0.75))
        
        return path
    }
}

struct LineDrawAnimation<S: Shape>: View {
    var shape: S
    var color: Color
    var drawDuration: Double = 2
    var eraseDuration: Double = 1.2
    var pause: Double = 1.0
    var delay: Double = 0.0
    var onComplete: (() -> Void)? = nil
    
    @State private var progress: CGFloat = 0
    @State private var drawingForward = true
    
    var body: some View {
        shape
            .trim(from: 0, to: progress)
            .stroke(color, lineWidth: 3)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    animate()
                }
            }
    }
    
    private func animate() {
        let duration = drawingForward ? drawDuration : eraseDuration
        withAnimation(.linear(duration: duration)) {
            progress = drawingForward ? 1 : 0
        }
        
        let totalDelay = drawingForward ? (duration + pause) : duration
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
            if drawingForward {
                drawingForward = false
                animate()
            } else {
                drawingForward = true
                onComplete?()
            }
        }
    }
}

struct WaveRow<S: Shape>: View {
    var shape: S
    var color: Color
    var count: Int = 5
    var spacing: CGFloat = 24
    var onComplete: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<count, id: \.self) { i in
                LineDrawAnimation(
                    shape: shape,
                    color: color,
                    drawDuration: 1.8,
                    eraseDuration: 0.8,
                    pause: 1.0,
                    delay: Double(i) * 0.3,
                    onComplete: i == count - 1 ? onComplete : nil
                )
                .frame(width: 60, height: 60)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct SymbolCycler: View {
    @State private var index = 0
    
    var body: some View {
        Group {
            if index == 0 {
                WaveRow(shape: HappyFace(), color: Color("MintGreen")) { next() }
            } else if index == 1 {
                WaveRow(shape: Car(), color: Color("MintGreen")) { next() }
            } else if index == 2 {
                WaveRow(shape: StickFigure(), color: Color("MintGreen")) { next() }
            } else if index == 3 {
                WaveRow(shape: Heart(), color: Color("MintGreen")) { next() }
            }
        }
    }
    
    private func next() {
        index = (index + 1) % 4
    }
}
