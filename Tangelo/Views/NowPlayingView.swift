// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import SwiftUI

/// Shown for audio-only media: the artwork, large, over a blurred copy of itself.
struct NowPlayingView: View {
    @Environment(Player.self) private var player

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width * 0.42, geo.size.height * 0.5, 320)
            ZStack {
                if let artwork = player.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: 60)
                        .overlay(Color.black.opacity(0.45))
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [Color(red: 0.26, green: 0.11, blue: 0.04), Color(red: 0.05, green: 0.04, blue: 0.035)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }

                VStack(spacing: 18) {
                    Group {
                        if let artwork = player.artwork {
                            Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fill)
                        } else {
                            ZStack {
                                Color.white.opacity(0.06)
                                Image(systemName: "music.note")
                                    .font(.system(size: side * 0.32, weight: .light))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.5), radius: 30, y: 14)

                    Text(player.title)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: max(side * 1.4, 240))
                }
                .offset(y: -40)
            }
        }
        .animation(.easeOut(duration: 0.4), value: player.artwork != nil)
    }
}
