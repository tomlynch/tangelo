// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import SwiftUI

/// The floating control bar. It reads no player state itself: each cluster is its own view, so time ticks
/// update only `TimelineRow` instead of rebuilding every button and menu several times a second.
struct ControlBar: View {
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                VolumeControl()
                    .frame(width: 212, alignment: .leading)
                Spacer(minLength: 8)
                TransportControls()
                Spacer(minLength: 8)
                PlaybackOptions()
                    .frame(width: 212, alignment: .trailing)
            }

            TimelineRow()
                .zIndex(1) // the seek preview pops up over the buttons row
        }
        .labelStyle(.iconOnly)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .frame(maxWidth: 720)
        // Glass as a background layer, so the seek preview can rise above the bar without being drawn inside it.
        .background { Color.clear.glassPanel(in: RoundedRectangle(cornerRadius: 24, style: .continuous)) }
    }
}
