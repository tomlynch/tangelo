// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import Foundation

extension URL {
    /// Title to show for a media URL: the file name without extension, or the stream's last path component or host.
    var mediaDisplayName: String {
        if isFileURL { return deletingPathExtension().lastPathComponent }
        return lastPathComponent.isEmpty ? (host() ?? absoluteString) : lastPathComponent
    }

    /// Secondary line: the containing folder for files, the host for streams.
    var mediaDetail: String {
        isFileURL ? deletingLastPathComponent().lastPathComponent : (host() ?? "Stream")
    }
}
