// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import SwiftUI

struct OpenURLSheet: View {
    @Environment(Player.self) private var player
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    private static let schemes: Set<String> = ["http", "https", "rtsp", "rtmp", "rtp", "udp", "mms", "ftp", "smb", "sftp", "nfs"]

    private var url: URL? {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), Self.schemes.contains(scheme) else { return nil }
        return url
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Open a Network Stream")
                .font(.headline)
            TextField("https://, rtsp://, smb:// …", text: $text)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                .onSubmit(open)
            Text("Works with direct media links, HLS and DASH playlists, RTSP cameras, and network shares.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Open", action: open)
                    .keyboardShortcut(.defaultAction)
                    .disabled(url == nil)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear {
            if let pasted = NSPasteboard.general.string(forType: .string),
               let candidate = URL(string: pasted.trimmingCharacters(in: .whitespacesAndNewlines)),
               let scheme = candidate.scheme?.lowercased(), Self.schemes.contains(scheme) {
                text = candidate.absoluteString
            }
        }
    }

    private func open() {
        guard let url else { return }
        player.open([url])
        dismiss()
    }
}
