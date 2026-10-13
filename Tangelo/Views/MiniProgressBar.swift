// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import SwiftUI

/// The mini player's seek bar. Separate so time ticks don't re-render the whole overlay.
struct MiniProgressBar: View {
    @Environment(Player.self) private var player
    @Environment(ChromeController.self) private var chrome

    var body: some View {
        SlimSlider(value: player.position, onDrag: scrub, onCommit: player.seek(to:))
            .disabled(player.duration == 0)
            .accessibilityLabel("Playback Position")
    }

    private func scrub(to fraction: Double?) {
        player.scrubPosition = fraction
        chrome.poke()
    }
}
