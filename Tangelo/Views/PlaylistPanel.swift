// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import SwiftUI

struct PlaylistPanel: View {
    @Environment(Player.self) private var player
    @Environment(ChromeController.self) private var chrome

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Playlist").font(.system(size: 15, weight: .semibold))
                    Text(player.queue.count == 1 ? "1 item" : "\(player.queue.count) items")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Button { OpenPanel.chooseMediaToQueue() } label: {
                    Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(ChromeButtonStyle(size: 28))
                .help("Add to playlist")
                .accessibilityLabel("Add to Playlist")
                Button { withAnimation(.snappy) { chrome.showingPlaylist = false } } label: {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(ChromeButtonStyle(size: 28))
                .help("Close")
                .accessibilityLabel("Close Playlist")
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if player.queue.isEmpty {
                ContentUnavailableView {
                    Label("Nothing queued", systemImage: "list.bullet")
                } description: {
                    Text("Drop files here while the playlist is open to add them.")
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(player.queue.enumerated()), id: \.element.id) { index, item in
                        PlaylistRow(item: item, index: index, isCurrent: index == player.currentIndex, isPlaying: player.isPlaying)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { player.play(at: index) }
                            .contextMenu {
                                Button("Play") { player.play(at: index) }
                                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
                                    .disabled(!item.url.isFileURL)
                                Divider()
                                Button("Remove", role: .destructive) { player.remove(at: [index]) }
                            }
                    }
                    .onMove { player.move(from: $0, to: $1) }
                    .onDelete { player.remove(at: $0) }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(width: 300)
        .glassPanel(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onHover { chrome.pointerOverPanel = $0 }
        .onDisappear { chrome.pointerOverPanel = false }
    }
}

private struct PlaylistRow: View {
    let item: MediaItem
    let index: Int
    let isCurrent: Bool
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if isCurrent {
                    Image(systemName: "waveform")
                        .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                        .foregroundStyle(.tint)
                } else {
                    Text("\(index + 1)")
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .font(.system(size: 12, weight: .semibold).monospacedDigit())
            .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                    .font(.system(size: 13, weight: isCurrent ? .semibold : .regular))
                    .lineLimit(1)
                Text(item.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .background(isCurrent ? Color.white.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
