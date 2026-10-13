// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import SwiftUI

/// Previous, back 10, play/pause, forward 10, next.
struct TransportControls: View {
    @Environment(Player.self) private var player

    var body: some View {
        HStack(spacing: 6) {
            Button("Previous", systemImage: "backward.end.fill", action: player.previous)
                .font(.system(size: 13))
                .buttonStyle(ChromeButtonStyle())
                .opacity(player.queue.count > 1 ? 1 : 0)
                .help("Previous")

            Button("Back 10 Seconds", systemImage: "gobackward.10", action: skipBack)
                .font(.system(size: 17, weight: .medium))
                .buttonStyle(ChromeButtonStyle(size: 36))
                .help("Back 10 seconds")

            Button(player.isPlaying ? "Pause" : "Play",
                   systemImage: player.isPlaying ? "pause.fill" : "play.fill",
                   action: player.togglePlayPause)
                .font(.system(size: 24))
                .contentTransition(.symbolEffect(.replace.downUp))
                .buttonStyle(ChromeButtonStyle(size: 46))
                .help(player.isPlaying ? "Pause" : "Play")

            Button("Forward 10 Seconds", systemImage: "goforward.10", action: skipForward)
                .font(.system(size: 17, weight: .medium))
                .buttonStyle(ChromeButtonStyle(size: 36))
                .help("Forward 10 seconds")

            Button("Next", systemImage: "forward.end.fill", action: player.next)
                .font(.system(size: 13))
                .buttonStyle(ChromeButtonStyle())
                .opacity(player.queue.count > 1 ? 1 : 0)
                .disabled(!player.hasNext)
                .help("Next")
        }
    }

    private func skipBack() { player.skip(by: -10) }
    private func skipForward() { player.skip(by: 10) }
}
