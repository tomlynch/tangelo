// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import Foundation

/// A brief overlay message (volume, seek, speed) shown over the video.
struct HUDMessage: Equatable {
    let id = UUID()
    let symbol: String
    let text: String
}
