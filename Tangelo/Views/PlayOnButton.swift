// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import AVKit
import SwiftUI

/// Control bar button that picks where playback happens: this Mac, AirPlay, or a Chromecast.
struct PlayOnButton: View {
    @Environment(Player.self) private var player
    @State private var showing = false
    private let casting = Casting.shared
    private let airPlay = AirPlay.shared

    private var symbol: String {
        if airPlay.isActive { return "airplayvideo" }
        if casting.active != nil { return "tv.fill" }
        return "tv"
    }

    var body: some View {
        Button {
            casting.startDiscovery()
            showing.toggle()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(player.isRemote ? AnyShapeStyle(.tint) : AnyShapeStyle(.white))
        }
        .buttonStyle(ChromeButtonStyle())
        .help("Play on another device")
        .popover(isPresented: $showing, arrowEdge: .top) {
            PlayOnMenu { showing = false }
        }
    }
}

private struct PlayOnMenu: View {
    @Environment(Player.self) private var player
    let dismiss: () -> Void
    private let casting = Casting.shared
    private let airPlay = AirPlay.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Play On")
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.bottom, 2)

            DeviceRow(symbol: "macbook", name: "This Mac", selected: !player.isRemote) {
                casting.cast(to: nil)
                dismiss()
            }

            Divider().padding(.vertical, 4)

            if airPlay.supported {
                HStack(spacing: 10) {
                    RoutePicker()
                        .frame(width: 22, height: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("AirPlay").font(.system(size: 13))
                        Text(airPlay.isActive ? "Playing on an AirPlay device" : "Choose an Apple TV or AirPlay display")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "airplayvideo").frame(width: 22).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("AirPlay").font(.system(size: 13)).foregroundStyle(.secondary)
                        Text("Works with MP4, MOV and M4V files. Use Chromecast for others.")
                            .font(.system(size: 11)).foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
            }

            Divider().padding(.vertical, 4)

            Text("Chromecast")
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)

            if casting.devices.isEmpty {
                HStack(spacing: 8) {
                    if casting.searching { ProgressView().controlSize(.small) }
                    Text(casting.searching ? "Looking for devices…" : "No Chromecasts found")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            } else {
                ForEach(casting.devices) { device in
                    DeviceRow(symbol: device.playsVideo ? "tv" : "hifispeaker", name: device.name,
                              selected: casting.active == device) {
                        casting.cast(to: device)
                        dismiss()
                    }
                }
            }
        }
        .padding(10)
        .frame(width: 290)
    }
}

private struct DeviceRow: View {
    let symbol: String
    let name: String
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).frame(width: 22)
                Text(name).font(.system(size: 13)).lineLimit(1)
                Spacer()
                if selected { Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold)).foregroundStyle(.tint) }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.primary.opacity(hovering ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// The system AirPlay route menu, bound to the AVPlayer that takes over during AirPlay.
private struct RoutePicker: NSViewRepresentable {
    func makeNSView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.player = AirPlay.shared.avPlayer
        view.isRoutePickerButtonBordered = false
        return view
    }

    func updateNSView(_ nsView: AVRoutePickerView, context: Context) {}
}
