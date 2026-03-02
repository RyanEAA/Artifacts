//
//  DrawingToolbarView.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 2/26/26.
//

import SwiftUI

struct DrawingToolbarView: View {
    @EnvironmentObject var placementSettings: PlacementSettings
    @EnvironmentObject var sceneManager: SceneManager

    private var dm: DrawingManager { sceneManager.drawingManager }

    private let palette: [UIColor] = [
        .white,
        UIColor.mintGreen,
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
        guard case .draw = placementSettings.selectedTool else {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(spacing: 10) {

                // ── Row 1: Draw mode toggle + brush size ──────────────
                HStack(spacing: 12) {
                    DrawModeToggle(dm: dm)

                    Spacer()

                    // Brush size slider with tiny/large dot icons
                    HStack(spacing: 6) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 7))
                            .foregroundColor(.white.opacity(0.5))
                        Slider(
                            value: Binding(
                                get: { Double(dm.brushSize * 1000) },
                                set: { dm.brushSize = Float($0) / 1000 }
                            ),
                            in: 2...14
                        )
                        .tint(Color("MintGreen"))
                        .frame(maxWidth: 130)
                        Image(systemName: "circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                // ── Row 2: Colour palette ─────────────────────────────
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(palette, id: \.self) { uiColor in
                            ColorSwatch(
                                uiColor: uiColor,
                                isSelected: uiColor.cgColor == dm.brushColor.cgColor
                            ) {
                                dm.brushColor = uiColor
                            }
                        }
                    }
                }

                // ── Row 3: Action buttons ─────────────────────────────
                HStack(spacing: 10) {
                    // Undo
                    DrawToolbarButton(icon: "arrow.uturn.backward",
                                      label: "Undo",
                                      disabled: !dm.canUndo) {
                        NotificationCenter.default.post(name: .undoLastDrawingStroke, object: nil)
                    }

                    Spacer()

                    // Clear all
                    DrawToolbarButton(icon: "trash", label: "Clear") {
                        NotificationCenter.default.post(name: .clearAllDrawingStrokes, object: nil)
                    }

                    Spacer()

                    // Done
                    DrawToolbarButton(icon: "checkmark", label: "Done", accent: true) {
                        placementSettings.selectedTool = .none
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.40))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        )
    }
}

// MARK: - Draw Mode Toggle

private struct DrawModeToggle: View {
    @ObservedObject var dm: DrawingManager

    var body: some View {
        HStack(spacing: 0) {
            ModeButton(
                icon: "wind",
                label: "Air",
                selected: dm.drawMode == .air
            ) { dm.drawMode = .air }

            ModeButton(
                icon: "square.3.layers.3d.down.right",
                label: "Surface",
                selected: dm.drawMode == .surface
            ) { dm.drawMode = .surface }
        }
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color("MintGreen").opacity(0.18), lineWidth: 1)
        )
    }
}

private struct ModeButton: View {
    let icon: String
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.custom("Poppins-SemiBold", size: 10))
            }
            .foregroundColor(selected ? Color.black.opacity(0.9) : Color.white.opacity(0.6))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(selected ? Color("MintGreen") : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .animation(.easeInOut(duration: 0.15), value: selected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Colour Swatch

private struct ColorSwatch: View {
    let uiColor: UIColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(uiColor))
                .frame(width: 28, height: 28)
                .overlay(Circle().stroke(Color.white.opacity(isSelected ? 0.9 : 0.0), lineWidth: 2.5))
                .overlay(
                    // Dark ring so white swatch is visible
                    Circle().stroke(Color.black.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color(uiColor).opacity(isSelected ? 0.7 : 0), radius: 6)
                .scaleEffect(isSelected ? 1.18 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Toolbar Action Button

private struct DrawToolbarButton: View {
    let icon: String
    let label: String
    var disabled: Bool = false
    var accent: Bool   = false
    let action: () -> Void

    private var bg:     Color { accent ? Color("MintGreen") : Color.white.opacity(0.06) }
    private var fg:     Color { accent ? Color.black.opacity(0.9) : Color.white.opacity(disabled ? 0.28 : 0.9) }
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
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(bg)
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let undoLastDrawingStroke  = Notification.Name("UndoLastDrawingStroke")
    static let clearAllDrawingStrokes = Notification.Name("ClearAllDrawingStrokes")
}
