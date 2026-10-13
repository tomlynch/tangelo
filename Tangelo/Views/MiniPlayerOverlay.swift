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
                Button("Back 10 Seconds", systemImage: "gobackward.10", action: skipBack)
                    .font(.system(size: 17, weight: .medium))
                    .buttonStyle(ChromeButtonStyle(size: 36))
                Button(player.isPlaying ? "Pause" : "Play",
                       systemImage: player.isPlaying ? "pause.fill" : "play.fill",
                       action: player.togglePlayPause)
                    .font(.system(size: 26))
                    .contentTransition(.symbolEffect(.replace.downUp))
                    .buttonStyle(ChromeButtonStyle(size: 48))
                Button("Forward 10 Seconds", systemImage: "goforward.10", action: skipForward)
                    .font(.system(size: 17, weight: .medium))
                    .buttonStyle(ChromeButtonStyle(size: 36))
            }

            VStack {
                HStack {
                    Button("Stop", systemImage: "xmark", action: player.stop)
                        .font(.system(size: 11, weight: .bold))
                        .buttonStyle(ChromeButtonStyle(size: 26))
                        .help("Stop")
                    Spacer()
                    Button("Back to Full Window", systemImage: "pip.exit", action: chrome.exitMini)
                        .font(.system(size: 12, weight: .semibold))
                        .buttonStyle(ChromeButtonStyle(size: 26))
                        .help("Back to Full Window")
                }
                Spacer()
                MiniProgressBar()
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
        .labelStyle(.iconOnly)
    }

    private func skipBack() { player.skip(by: -10) }
    private func skipForward() { player.skip(by: 10) }
}
