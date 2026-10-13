// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import SwiftUI

/// Mute button and volume slider.
struct VolumeControl: View {
    @Environment(Player.self) private var player
    @Environment(ChromeController.self) private var chrome

    var body: some View {
        HStack(spacing: 4) {
            Button(player.isMuted ? "Unmute" : "Mute", systemImage: player.volumeSymbol, action: player.toggleMute)
                .font(.system(size: 13))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 20)
                .buttonStyle(ChromeButtonStyle())
                .help(player.isMuted ? "Unmute" : "Mute")

            SlimSlider(value: player.isMuted ? 0 : player.volume, onDrag: setVolume)
                .frame(width: 84)
                .accessibilityLabel("Volume")
        }
    }

    private func setVolume(_ value: Double?) {
        if let value {
            player.isMuted = false
            player.volume = value
        }
        chrome.poke()
    }
}
