// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import SwiftUI

/// Slow-moving dark ember mesh gradient behind the welcome screen.
struct AmbientBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // The drift is slow, so 20 fps is indistinguishable from 30 and costs a third less. Reduce Motion holds it still.
        TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { context in
            let t = Float(context.date.timeIntervalSinceReferenceDate)
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.5 + 0.12 * sin(t * 0.21), 0.5 + 0.1 * cos(t * 0.17)], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1],
                ],
                colors: [
                    Color(red: 0.06, green: 0.045, blue: 0.04), Color(red: 0.17, green: 0.075, blue: 0.04), Color(red: 0.05, green: 0.04, blue: 0.035),
                    Color(red: 0.11, green: 0.06, blue: 0.04), Color(red: 0.34, green: 0.13, blue: 0.04), Color(red: 0.12, green: 0.06, blue: 0.04),
                    Color(red: 0.035, green: 0.03, blue: 0.03), Color(red: 0.10, green: 0.05, blue: 0.035), Color(red: 0.03, green: 0.03, blue: 0.03),
                ]
            )
        }
        .ignoresSafeArea()
    }
}
