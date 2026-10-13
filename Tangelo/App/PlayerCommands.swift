// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import SwiftUI

struct PlayerCommands: Commands {
    let player: Player
    let chrome: ChromeController

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open…") { OpenPanel.chooseMedia() }
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
            Button("Add Subtitle File…") { OpenPanel.chooseSubtitles() }
                .disabled(!player.hasMedia)
        }

        CommandMenu("Playback") {
            Button(player.isPlaying ? "Pause" : "Play") { player.togglePlayPause() }
                .keyboardShortcut("p", modifiers: [.command, .option])
                .disabled(!player.hasMedia)
            Divider()
            Button("Jump Forward 10s") { player.skip(by: 10) }
                .keyboardShortcut(.rightArrow)
            Button("Jump Back 10s") { player.skip(by: -10) }
                .keyboardShortcut(.leftArrow)
            Divider()
            Button("Next") { player.next() }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .shift])
                .disabled(!player.hasNext)
            Button("Previous") { player.previous() }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .shift])
                .disabled(!player.hasMedia)
            Divider()
            Menu("Speed") {
                ForEach([0.5, 0.75, 1, 1.25, 1.5, 2] as [Float], id: \.self) { rate in
                    Toggle(rate == 1 ? "Normal" : String(format: "%.2g×", rate),
                           isOn: Binding(get: { player.rate == rate }, set: { _ in player.setRate(rate) }))
                }
            }
            Button("Faster") { player.setRate(player.rate + 0.25) }
                .keyboardShortcut("]")
            Button("Slower") { player.setRate(player.rate - 0.25) }
                .keyboardShortcut("[")
            Divider()
            Button("Stop") { player.stop() }
                .keyboardShortcut(".")
                .disabled(!player.hasMedia)
        }

        CommandMenu("Audio") {
            Button("Volume Up") { player.nudgeVolume(by: 0.05) }
                .keyboardShortcut(.upArrow)
            Button("Volume Down") { player.nudgeVolume(by: -0.05) }
                .keyboardShortcut(.downArrow)
            Button(player.isMuted ? "Unmute" : "Mute") { player.toggleMute() }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
            if !player.audioTracks.isEmpty {
                Divider()
                Picker("Audio Track", selection: Binding(get: { player.selectedAudioTrack }, set: player.selectAudioTrack)) {
                    ForEach(player.audioTracks) { Text($0.name).tag($0.id) }
                }
            }
        }

        CommandMenu("Subtitles") {
            Button("Add Subtitle File…") { OpenPanel.chooseSubtitles() }
                .disabled(!player.hasMedia)
            if !player.subtitleTracks.isEmpty {
                Divider()
                Picker("Subtitle Track", selection: Binding(get: { player.selectedSubtitleTrack }, set: player.selectSubtitleTrack)) {
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
