// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import AppKit

/// Single-key player shortcuts (space, arrows, F, M). These can't be menu key equivalents
/// because the menu would swallow them while typing in a text field.
enum KeyboardShortcuts {
    @MainActor
    static func install() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Local monitors run on the main thread; NSEvent just isn't marked Sendable.
            nonisolated(unsafe) let event = event
            let handled = MainActor.assumeIsolated { handle(event) }
            return handled ? nil : event
        }
    }

    @MainActor
    private static func handle(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control])
        guard modifiers.isEmpty else { return false }
        guard let window = event.window, window == ChromeController.shared.window else { return false }
        if window.firstResponder is NSText { return false }

        let player = Player.shared
        let chrome = ChromeController.shared
        let shift = event.modifierFlags.contains(.shift)

        switch event.keyCode {
        case 49: player.togglePlayPause()                       // space
        case 123: player.skip(by: shift ? -30 : -5)              // left
        case 124: player.skip(by: shift ? 30 : 5)                // right
        case 126: player.nudgeVolume(by: 0.05)                   // up
        case 125: player.nudgeVolume(by: -0.05)                  // down
        case 53:                                                 // escape
            if chrome.isMini { chrome.exitMini() }
            else if window.styleMask.contains(.fullScreen) { chrome.toggleFullScreen() }
            else { return false }
        default:
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "f": chrome.toggleFullScreen()
            case "m": player.toggleMute()
            case "n": player.next()
            default: return false
            }
        }
        chrome.poke()
        return true
    }
}
