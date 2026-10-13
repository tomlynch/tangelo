// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import SwiftUI

/// Elapsed time, seek bar and remaining time. The only part of the control bar that follows the clock.
struct TimelineRow: View {
    @Environment(Player.self) private var player
    @Environment(ChromeController.self) private var chrome
    @AppStorage("showRemainingTime") private var showRemaining = true

    var body: some View {
        HStack(spacing: 12) {
            Text(Player.format(player.position * player.duration))
                .frame(minWidth: 44, alignment: .trailing)

            SlimSlider(
                value: player.position,
                onDrag: scrub,
                onCommit: player.seek(to:),
                tooltip: { Player.format($0 * player.duration) },
                preview: { SeekPreviews.shared.image(near: $0) },
                onHover: prioritizePreview
            )
            .disabled(player.duration == 0)

            Button(action: toggleTimeDisplay) {
                Text(showRemaining
                     ? "−\(Player.format(max(player.duration - player.position * player.duration, 0)))"
                     : Player.format(player.duration))
                    .frame(minWidth: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .help(showRemaining ? "Show total duration" : "Show remaining time")
        }
        .font(.system(size: 11.5, weight: .medium).monospacedDigit())
        .foregroundStyle(.white.opacity(0.8))
    }

    private func scrub(to fraction: Double?) {
        player.scrubPosition = fraction
        chrome.poke()
    }

    private func prioritizePreview(at fraction: Double?) {
        if let fraction { SeekPreviews.shared.request(near: fraction) }
    }

    private func toggleTimeDisplay() {
        showRemaining.toggle()
    }
}
