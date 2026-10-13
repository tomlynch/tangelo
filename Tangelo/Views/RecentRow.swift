// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import SwiftUI

struct RecentRow: View {
    let url: URL
    let action: () -> Void
    @State private var hovering = false

    private var symbol: String {
        guard url.isFileURL else { return "globe" }
        let audio = ["mp3", "m4a", "flac", "wav", "aac", "ogg", "opus", "aiff", "alac"]
        return audio.contains(url.pathExtension.lowercased()) ? "music.note" : "film"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(url.mediaDisplayName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(url.mediaDetail)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if let resume = ResumePoints.shared.position(for: url) {
                    Text("Resume \(Player.format(resume))")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.white.opacity(hovering ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
