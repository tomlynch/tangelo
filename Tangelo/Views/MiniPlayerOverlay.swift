// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import SwiftUI

/// Hover controls for the mini player: transport in the middle, close and expand in the corners,
/// and a thin progress bar along the bottom.
struct MiniPlayerOverlay: View {
    @Environment(Player.self) private var player
    @Environment(ChromeController.self) private var chrome

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0.15), .black.opacity(0.6)],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)

            HStack(spacing: 14) {
                Button { player.skip(by: -10) } label: {
                    Image(systemName: "gobackward.10").font(.system(size: 17, weight: .medium))
                }
                .buttonStyle(ChromeButtonStyle(size: 36))
                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 26))
                        .contentTransition(.symbolEffect(.replace.downUp))
                }
                .buttonStyle(ChromeButtonStyle(size: 48))
                Button { player.skip(by: 10) } label: {
                    Image(systemName: "goforward.10").font(.system(size: 17, weight: .medium))
                }
                .buttonStyle(ChromeButtonStyle(size: 36))
            }

            VStack {
                HStack {
                    Button { player.stop() } label: {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(ChromeButtonStyle(size: 26))
                    .help("Stop")
                    Spacer()
                    Button { chrome.exitMini() } label: {
                        Image(systemName: "pip.exit").font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(ChromeButtonStyle(size: 26))
                    .help("Back to Full Window")
                }
                Spacer()
                SlimSlider(
                    value: player.position,
                    onDrag: { player.scrubPosition = $0; chrome.poke() },
                    onCommit: { player.seek(to: $0) }
                )
                .disabled(player.duration == 0)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
    }
}

/// Stands in for the video while it plays on a Chromecast or AirPlay device.
struct RemotePlaybackView: View {
    @Environment(Player.self) private var player
    @Environment(ChromeController.self) private var chrome

    private var deviceName: String { player.castingTo ?? "AirPlay" }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.24, green: 0.10, blue: 0.04), Color(red: 0.04, green: 0.035, blue: 0.03)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: chrome.isMini ? 6 : 14) {
                Image(systemName: player.castingTo == nil ? "airplayvideo" : "tv")
                    .font(.system(size: chrome.isMini ? 28 : 54, weight: .light))
                    .foregroundStyle(.tint)
                    .symbolEffect(.pulse, isActive: player.isPlaying)
                if !chrome.isMini {
                    Text(player.title)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }
                Text("Playing on \(deviceName)")
                    .font(.system(size: chrome.isMini ? 11 : 13))
                    .foregroundStyle(.white.opacity(0.6))
                if player.castingTo != nil, !chrome.isMini {
                    Button("Play on This Mac") { Casting.shared.cast(to: nil) }
                        .glassButton()
                        .padding(.top, 6)
                }
            }
            .offset(y: chrome.isMini ? 0 : -30)
        }
    }
}
