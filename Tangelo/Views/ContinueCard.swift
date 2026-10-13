// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import SwiftUI

struct ContinueCard: View {
    @Environment(Player.self) private var player
    let url: URL
    let entry: ResumePoints.Entry
    @State private var thumbnail: NSImage?
    @State private var hovering = false

    private var remainingText: String {
        guard entry.remaining >= 60 else { return "Less than a minute left" }
        let units: Set<Duration.UnitsFormatStyle.Unit> = entry.remaining >= 3600 ? [.hours, .minutes] : [.minutes]
        return Duration.seconds(entry.remaining).formatted(.units(allowed: units, width: .abbreviated)) + " left"
    }

    var body: some View {
        Button { player.open([url]) } label: {
            VStack(alignment: .leading, spacing: 7) {
                ZStack(alignment: .bottom) {
                    ZStack {
                        if let thumbnail {
                            Image(nsImage: thumbnail).resizable().aspectRatio(contentMode: .fill)
                        } else {
                            LinearGradient(colors: [.white.opacity(0.1), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom)
                            Image(systemName: "film").font(.system(size: 22)).foregroundStyle(.white.opacity(0.35))
                        }
                    }
                    .frame(width: 200, height: 112.5)
                    .clipped()

                    LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 38))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.35))
                        .frame(maxHeight: .infinity)
                        .opacity(hovering ? 1 : 0)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.3))
                            Capsule().fill(.tint).frame(width: max(4, geo.size.width * entry.fraction))
                        }
                    }
                    .frame(height: 4)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 9)
                }
                .frame(width: 200, height: 112.5)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(hovering ? 0.35 : 0.08)))
                .scaleEffect(hovering ? 1.03 : 1)
                .shadow(color: .black.opacity(hovering ? 0.4 : 0.2), radius: hovering ? 14 : 6, y: 6)

                VStack(alignment: .leading, spacing: 1) {
                    Text(url.mediaDisplayName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(remainingText)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 2)
            }
            .frame(width: 200)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .contextMenu {
            Button("Play from Beginning") {
                ResumePoints.shared.clear(for: url)
                player.open([url])
            }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                .disabled(!url.isFileURL)
            Divider()
            Button("Remove from Continue Watching") {
                withAnimation(.snappy) { ResumePoints.shared.clear(for: url) }
            }
        }
        .task(id: Int(entry.fraction * 40)) {
            thumbnail = await Thumbnails.shared.thumbnail(for: url, at: entry.fraction)
        }
    }
}
