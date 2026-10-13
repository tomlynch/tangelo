// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import SwiftUI
import UniformTypeIdentifiers

@main
struct TangeloApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var player: Player
    @State private var chrome: ChromeController

    init() {
        // Must run before Player reads its saved volume.
        LegacySettings.migrate()
        _player = State(initialValue: Player.shared)
        _chrome = State(initialValue: ChromeController.shared)
    }

    var body: some Scene {
        Window("Tangelo", id: "player") {
            PlayerWindow()
                .environment(player)
                .environment(chrome)
                .frame(minWidth: chrome.isMini ? 240 : 480, minHeight: chrome.isMini ? 135 : 270)
        }
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .defaultSize(width: 960, height: 540)
        .commands { PlayerCommands(player: player, chrome: chrome) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        MainActor.assumeIsolated { Player.shared.open(urls) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { Player.shared.stop() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            KeyboardShortcuts.install()
            DialogHandler.install()
            TrackpadGestures.shared.install()
            SystemIntegration.shared.install()
            // Lets screenshots and CI open a file without going through Finder: `Tangelo --open <path>`.
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "--open"), args.indices.contains(i + 1) {
                Player.shared.open([URL(filePath: args[i + 1])])
            }
            // Also for screenshots: `--network` opens the network browser, `--mini` starts in the mini player.
            if args.contains("--network") { ChromeController.shared.showingNetwork = true }
            if args.contains("--mini") {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.5))
                    ChromeController.shared.enterMini()
                }
            }
        }
    }
}

enum OpenPanel {
    static let mediaTypes: [UTType] = [.movie, .audio, .audiovisualContent, .playlist] +
        ["mkv", "webm", "flv", "ogv", "ts", "m2ts", "vob", "opus", "flac"].compactMap { UTType(filenameExtension: $0) }

    @MainActor
    static func chooseMedia() {
        if let urls = runMediaPanel() { Player.shared.open(urls) }
    }

    @MainActor
    static func chooseMediaToQueue() {
        if let urls = runMediaPanel() { Player.shared.open(urls, replacing: false) }
    }

    @MainActor
    private static func runMediaPanel() -> [URL]? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = mediaTypes
        return panel.runModal() == .OK ? panel.urls : nil
    }

    @MainActor
    static func chooseSubtitles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ["srt", "ass", "ssa", "vtt", "sub", "idx", "smi"].compactMap { UTType(filenameExtension: $0) }
        if panel.runModal() == .OK, let url = panel.url { Player.shared.addSubtitleFile(url) }
    }
}

/// The app was called Marquee (bundle net.tomlynch.marquee) during early development.
/// Carries recents, resume points and preferences over to the new bundle's defaults once.
enum LegacySettings {
    private static let keys = ["volume", "recentURLs", "resumePoints.v2", "showRemainingTime"]

    static func migrate() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "migratedFromMarquee"),
              let old = UserDefaults(suiteName: "net.tomlynch.marquee") else { return }
        for key in keys where defaults.object(forKey: key) == nil {
            if let value = old.object(forKey: key) { defaults.set(value, forKey: key) }
        }
        defaults.set(true, forKey: "migratedFromMarquee")
    }
}
