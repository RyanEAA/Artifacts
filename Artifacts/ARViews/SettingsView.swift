//
//  SettingsView.swift
//  ARTutorial
//
//  Created by Ryan Aparicio on 10/13/25.
//

import SwiftUI

enum Setting {
    case peopleOcclusion
    case objectOcclusion
    case lidarDebug
    case collaboration

    var label: String {
        switch self {
        case .peopleOcclusion, .objectOcclusion:
            return "Occlusion"
        case .lidarDebug:
            return "LiDar"
        case .collaboration:
            return "Collaboration"
        }
    }

    var systemIconName: String {
        switch self {
        case .peopleOcclusion:
            return "person"
        case .objectOcclusion:
            return "cube.box.fill"
        case .lidarDebug:
            return "light.min"
        case .collaboration:
            return "person.2"
        }
    }
}

struct SettingsView: View {
    @Binding var showSettings: Bool

    var body: some View {
        NavigationStack {
            SettingsGrid()
                .artifactsSheetBackground()
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showSettings.toggle()
                        } label: {
                            Text("Done")
                                .font(.custom("Poppins-SemiBold", size: 15))
                                .foregroundColor(Color("MintGreen").opacity(0.92))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color("MintGreen").opacity(0.18), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
        }
        .tint(Color("MintGreen"))
    }
}

struct SettingsGrid: View {
    @EnvironmentObject var sessionSettings: SessionSettings
    @EnvironmentObject var collaborationManager: CollaborationManager

    private var gridItemLayout = [GridItem(.adaptive(minimum: 110, maximum: 130), spacing: 14)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                LazyVGrid(columns: gridItemLayout, spacing: 14) {
                    SettingToggleTile(setting: .peopleOcclusion, isOn: $sessionSettings.isPeopleOcclusionEnabled, subtitle: "People")
                    SettingToggleTile(setting: .objectOcclusion, isOn: $sessionSettings.isObjectOcclusionEnabled, subtitle: "Objects")
                    SettingToggleTile(setting: .lidarDebug, isOn: $sessionSettings.isLidarDebugEnabled, subtitle: "Debug")
                    SettingToggleTile(setting: .collaboration, isOn: $sessionSettings.isCollaborationEnabled, subtitle: "Live")
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                collaborationSection
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 18)
        }
    }

    private var collaborationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Collaboration")
                .font(.custom("Poppins-SemiBold", size: 16))
                .foregroundColor(Color.white.opacity(0.92))

            Text("Host or join a live AR session with a friend.")
                .font(.custom("Poppins-Regular", size: 12))
                .foregroundColor(Color.white.opacity(0.65))

            HStack(spacing: 10) {
                Button {
                    sessionSettings.isCollaborationEnabled = true
                    collaborationManager.host()
                } label: {
                    Label("Host", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.custom("Poppins-SemiBold", size: 14))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .foregroundColor(Color.black.opacity(0.92))
                .background(Color("MintGreen"))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Button {
                    sessionSettings.isCollaborationEnabled = true
                    collaborationManager.join()
                } label: {
                    Label("Join", systemImage: "person.2.wave.2")
                        .font(.custom("Poppins-SemiBold", size: 14))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .foregroundColor(Color.white.opacity(0.92))
                .background(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color("MintGreen").opacity(0.18), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button {
                collaborationManager.stop()
            } label: {
                Label("Stop", systemImage: "xmark.circle")
                    .font(.custom("Poppins-SemiBold", size: 14))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .foregroundColor(Color.white.opacity(0.92))
            .background(Color.red.opacity(0.22))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.red.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))

            let connected = collaborationManager.multipeer.connectedPeers.count
            Text("Connected: \(connected)")
                .font(.custom("Poppins-Regular", size: 12))
                .foregroundColor(Color.white.opacity(0.65))
                .padding(.top, 2)
        }
        .padding(14)
        .artifactsPanel(cornerRadius: 18)
    }
}

private struct SettingToggleTile: View {
    let setting: Setting
    @Binding var isOn: Bool
    let subtitle: String

    var body: some View {
        Button {
            isOn.toggle()
            print("\(setting): \(isOn)")
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: setting.systemIconName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(isOn ? Color.black.opacity(0.92) : Color("MintGreen").opacity(0.92))
                        .frame(width: 34, height: 34)
                        .background(isOn ? Color("MintGreen") : Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isOn ? Color("MintGreen").opacity(0.25) : Color.white.opacity(0.10), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Spacer()

                    Circle()
                        .fill(isOn ? Color("MintGreen") : Color.white.opacity(0.14))
                        .frame(width: 10, height: 10)
                }

                Text(setting.label)
                    .font(.custom("Poppins-SemiBold", size: 14))
                    .foregroundColor(Color.white.opacity(0.92))

                Text(subtitle)
                    .font(.custom("Poppins-Regular", size: 12))
                    .foregroundColor(Color.white.opacity(0.62))
            }
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .padding(14)
            .background(Color.black.opacity(0.36))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isOn ? Color("MintGreen").opacity(0.25) : Color.white.opacity(0.10), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}
