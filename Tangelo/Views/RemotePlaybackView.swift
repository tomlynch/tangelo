// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import SwiftUI

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
                    Button("Play on This Mac", action: playHere)
                        .glassButton()
                        .padding(.top, 6)
                }
            }
            .offset(y: chrome.isMini ? 0 : -30)
        }
    }

    private func playHere() { Casting.shared.cast(to: nil) }
}
