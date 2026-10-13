// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import SwiftUI

struct PlayerCommands: Commands {
    @Bindable var player: Player
    let chrome: ChromeController

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open…", action: OpenPanel.chooseMedia)
                .keyboardShortcut("o")
            Button("Open URL…") { chrome.showingOpenURL = true }
                .keyboardShortcut("l")
            Button("Browse Network") { withAnimation(.snappy) { chrome.showingNetwork.toggle() } }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Menu("Open Recent") {
                ForEach(RecentItems.shared.urls, id: \.self) { url in
                    Button(url.isFileURL ? url.lastPathComponent : url.absoluteString) { player.open([url]) }
                }
                Divider()
                Button("Clear Menu") { RecentItems.shared.clear() }
                    .disabled(RecentItems.shared.urls.isEmpty)
            }
            Divider()
            Button("Add Subtitle File…", action: OpenPanel.chooseSubtitles)
                .disabled(!player.hasMedia)
        }

        CommandMenu("Playback") {
            Button(player.isPlaying ? "Pause" : "Play", action: player.togglePlayPause)
                .keyboardShortcut("p", modifiers: [.command, .option])
                .disabled(!player.hasMedia)
            Divider()
            Button("Jump Forward 10s") { player.skip(by: 10) }
                .keyboardShortcut(.rightArrow)
            Button("Jump Back 10s") { player.skip(by: -10) }
                .keyboardShortcut(.leftArrow)
            Divider()
            Button("Next", action: player.next)
                .keyboardShortcut(.rightArrow, modifiers: [.command, .shift])
                .disabled(!player.hasNext)
            Button("Previous", action: player.previous)
                .keyboardShortcut(.leftArrow, modifiers: [.command, .shift])
                .disabled(!player.hasMedia)
            Divider()
            Picker("Speed", selection: $player.playbackRate) {
                ForEach(Player.playbackRates, id: \.self) { rate in
                    Text(rate == 1 ? "Normal" : Player.rateLabel(rate)).tag(rate)
                }
            }
            Button("Faster") { player.setRate(player.rate + 0.25) }
                .keyboardShortcut("]")
            Button("Slower") { player.setRate(player.rate - 0.25) }
                .keyboardShortcut("[")
            Divider()
            Button("Stop", action: player.stop)
                .keyboardShortcut(".")
                .disabled(!player.hasMedia)
        }

        CommandMenu("Audio") {
            Button("Volume Up") { player.nudgeVolume(by: 0.05) }
                .keyboardShortcut(.upArrow)
            Button("Volume Down") { player.nudgeVolume(by: -0.05) }
                .keyboardShortcut(.downArrow)
            Button(player.isMuted ? "Unmute" : "Mute", action: player.toggleMute)
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
            if !player.audioTracks.isEmpty {
                Divider()
                Picker("Audio Track", selection: $player.audioTrack) {
                    ForEach(player.audioTracks) { Text($0.name).tag($0.id) }
                }
            }
        }

        CommandMenu("Subtitles") {
            Button("Add Subtitle File…", action: OpenPanel.chooseSubtitles)
                .disabled(!player.hasMedia)
            if !player.subtitleTracks.isEmpty {
                Divider()
                Picker("Subtitle Track", selection: $player.subtitleTrack) {
                    ForEach(player.subtitleTracks) { Text($0.name).tag($0.id) }
                }
            }
        }

        CommandGroup(after: .sidebar) {
            Button(chrome.showingPlaylist ? "Hide Playlist" : "Show Playlist") {
                withAnimation(.snappy) { chrome.showingPlaylist.toggle() }
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            Button(chrome.isMini ? "Exit Mini Player" : "Mini Player") { chrome.toggleMini() }
                .keyboardShortcut("m", modifiers: [.command, .option])
                .disabled(!player.hasMedia)
            Button("Float on Top") { chrome.floatOnTop.toggle() }
                .keyboardShortcut("t", modifiers: [.command, .option])
        }
    }
}
