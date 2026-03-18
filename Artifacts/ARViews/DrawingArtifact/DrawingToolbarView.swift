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

    var body: some View {
        guard case .draw = placementSettings.selectedTool else {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    DrawModeToggle(dm: dm)
                        .frame(width: 178)

                    HStack(spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 7))
                            .foregroundColor(.white.opacity(0.45))
                        Slider(
                            value: Binding(
                                get: { Double(dm.brushSize * 1000) },
                                set: { dm.brushSize = Float($0) / 1000 }
                            ),
                            in: 2...14
                        )
                        .tint(Color("MintGreen"))
                        Image(systemName: "circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.72))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                HStack(spacing: 10) {
                    DrawingColorPicker(dm: dm)

                    DrawToolbarButton(icon: "arrow.uturn.backward",
                                      label: "Undo",
                                      disabled: !dm.canUndo) {
                        NotificationCenter.default.post(name: .undoLastDrawingStroke, object: nil)
                    }

                    DrawToolbarButton(icon: "trash",
                                      label: "Clear") {
                        NotificationCenter.default.post(name: .clearAllDrawingStrokes, object: nil)
                    }

                    DrawToolbarButton(icon: "checkmark",
                                      label: "Done",
                                      accent: true) {
                        placementSettings.selectedTool = .none
                    }
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
        .frame(height: 40)
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
            .frame(maxWidth: .infinity)
            .foregroundColor(selected ? Color.black.opacity(0.9) : Color.white.opacity(0.6))
            .padding(.vertical, 7)
            .background(selected ? Color("MintGreen") : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .animation(.easeInOut(duration: 0.15), value: selected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Colour Picker

private struct DrawingColorPicker: View {
    @ObservedObject var dm: DrawingManager

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Color")
                    .font(.custom("Poppins-SemiBold", size: 11))
                    .foregroundColor(Color.white.opacity(0.9))

                Text(hexString(for: dm.brushColor))
                    .font(.custom("Poppins-Regular", size: 10))
                    .foregroundColor(Color.white.opacity(0.55))
            }

            Spacer(minLength: 8)

            ColorPicker(
                "",
                selection: Binding(
                    get: { Color(uiColor: dm.brushColor) },
                    set: { dm.brushColor = UIColor($0) }
                ),
                supportsOpacity: false
            )
            .labelsHidden()
            .frame(width: 32, height: 32)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minWidth: 156)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func hexString(for color: UIColor) -> String {
        var red: CGFloat = 1
        var green: CGFloat = 1
        var blue: CGFloat = 1
        var alpha: CGFloat = 1
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "#%02X%02X%02X",
            Int(round(red * 255)),
            Int(round(green * 255)),
            Int(round(blue * 255))
        )
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
            .padding(.horizontal, 11)
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
