// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import SwiftUI

/// Speed, audio and subtitles, Play On, playlist, mini player and full screen.
struct PlaybackOptions: View {
    @Environment(Player.self) private var player
    @Environment(ChromeController.self) private var chrome

    var body: some View {
        @Bindable var player = player

        HStack(spacing: 2) {
            Menu {
                Picker("Speed", selection: $player.playbackRate) {
                    ForEach(Player.playbackRates, id: \.self) { rate in
                        Text(rate == 1 ? "Normal" : Player.rateLabel(rate)).tag(rate)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                Text(Player.rateLabel(player.rate))
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
            }
            .chromeMenu()
            .help("Playback speed")
            .accessibilityLabel("Playback Speed")

            Menu {
                if !player.audioTracks.isEmpty {
                    Section("Audio") {
                        Picker("Audio", selection: $player.audioTrack) {
                            ForEach(player.audioTracks) { Text($0.name).tag($0.id) }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }
                Section("Subtitles") {
                    if !player.subtitleTracks.isEmpty {
                        Picker("Subtitles", selection: $player.subtitleTrack) {
                            ForEach(player.subtitleTracks) { Text($0.name).tag($0.id) }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                    Button("Add Subtitle File…", action: OpenPanel.chooseSubtitles)
                }
            } label: {
                Label("Audio and Subtitles",
                      systemImage: player.selectedSubtitleTrack >= 0 ? "captions.bubble.fill" : "captions.bubble")
                    .font(.system(size: 14))
            }
            .chromeMenu()
            .help("Audio and subtitles")

            PlayOnButton()

            Button("Playlist", systemImage: "list.bullet", action: togglePlaylist)
                .font(.system(size: 14, weight: .medium))
                .buttonStyle(ChromeButtonStyle())
                .help("Playlist")

            Button("Mini Player", systemImage: "pip.enter", action: chrome.enterMini)
                .font(.system(size: 14, weight: .medium))
                .buttonStyle(ChromeButtonStyle())
                .help("Mini Player")

            Button("Full Screen", systemImage: "arrow.up.left.and.arrow.down.right", action: chrome.toggleFullScreen)
                .font(.system(size: 13, weight: .medium))
                .buttonStyle(ChromeButtonStyle())
                .help("Full Screen")
        }
    }

    private func togglePlaylist() {
        withAnimation(.snappy) { chrome.showingPlaylist.toggle() }
    }
}
