// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import SwiftUI

/// Appears in the last 20 seconds of an episode when another one is queued.
struct UpNextCard: View {
    @Environment(Player.self) private var player
    let next: MediaItem
    let countdown: TimeInterval
    @State private var thumbnail: NSImage?

    private static let window: TimeInterval = 20

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if let thumbnail {
                    Image(nsImage: thumbnail).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color.white.opacity(0.08)
                    Image(systemName: "film").foregroundStyle(.white.opacity(0.4))
                }
            }
            .frame(width: 112, height: 63)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("Up Next")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.55))
                Text(next.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Button { player.next() } label: {
                        HStack(spacing: 6) {
                            ZStack {
                                Circle().stroke(.white.opacity(0.25), lineWidth: 2)
                                Circle()
                                    .trim(from: 0, to: 1 - countdown / Self.window)
                                    .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                    .animation(.linear(duration: 0.25), value: countdown)
                            }
                            .frame(width: 13, height: 13)
                            Text("Play in \(Int(countdown.rounded(.up)))s")
                                .monospacedDigit()
                        }
                    }
                    .prominentGlassButton()
                    Button("Cancel") { player.cancelUpNext() }
                        .glassButton()
                }
                .controlSize(.small)
                .padding(.top, 4)
            }
        }
        .padding(12)
        .frame(width: 340, alignment: .leading)
        .glassPanel(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .task(id: next.url) { thumbnail = await Thumbnails.shared.thumbnail(for: next.url, at: 0.1) }
    }
}
