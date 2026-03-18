//
//  AnnotationToolbarView.swift
//  Artifacts
//
//  Created by Codex on 3/18/26.
//

import SwiftUI

struct AnnotationToolbarView: View {
    @EnvironmentObject var sceneManager: SceneManager

    private let palette: [UIColor] = [
        UIColor.mintGreen,
        .white,
        .systemYellow,
        .systemOrange,
        .systemRed,
        .systemPink,
        .systemPurple,
        .systemBlue,
        .systemCyan,
        .black,
    ]

    var body: some View {
        guard sceneManager.activeAnnotationEditingId != nil else {
            return AnyView(EmptyView())
        }

        return AnyView(
            HStack(spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(palette, id: \.self) { uiColor in
                            AnnotationColorSwatch(
                                uiColor: uiColor,
                                isSelected: uiColor.cgColor == sceneManager.activeAnnotationColor.cgColor
                            ) {
                                sceneManager.updateActiveAnnotationColor(uiColor)
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }

                AnnotationToolbarButton(icon: "checkmark", label: "Done", accent: true) {
                    NotificationCenter.default.post(name: .finishAnnotationEditing, object: nil)
                }
            }
            .padding(18)
            .frame(maxWidth: 500)
            .background(Color.black.opacity(0.36))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 18)
            .padding(.top, 36)
        )
    }
}

private struct AnnotationColorSwatch: View {
    let uiColor: UIColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(uiColor))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle().stroke(Color.black.opacity(0.15), lineWidth: 1)
                    )
                Circle()
                    .stroke(Color.white.opacity(isSelected ? 0.95 : 0), lineWidth: 2)
                    .frame(width: 32, height: 32)
            }
            .frame(width: 34, height: 34)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

private struct AnnotationToolbarButton: View {
    let icon: String
    let label: String
    var accent: Bool = false
    let action: () -> Void

    private var bg: Color { accent ? Color("MintGreen") : Color.white.opacity(0.06) }
    private var fg: Color { accent ? Color.black.opacity(0.9) : Color.white.opacity(0.9) }
    private var border: Color { Color("MintGreen").opacity(accent ? 0.25 : 0.14) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(label)
                    .font(.custom("Poppins-SemiBold", size: 13))
            }
            .foregroundColor(fg)
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(bg)
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
    }
}

extension Notification.Name {
    static let finishAnnotationEditing = Notification.Name("FinishAnnotationEditing")
    static let annotationColorChanged = Notification.Name("AnnotationColorChanged")
}
