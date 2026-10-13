// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import Foundation
import Observation
import VLCKit

/// Chromecast discovery and casting through libVLC's renderer support. libVLC remuxes or transcodes
/// as needed, so anything Tangelo can play can be cast.
@MainActor
@Observable
final class Casting {
    static let shared = Casting()

    struct Device: Identifiable, Equatable {
        let id: String
        let name: String
        let playsVideo: Bool
        fileprivate let item: VLCRendererItem

        static func == (a: Device, b: Device) -> Bool { a.id == b.id }
    }

    private(set) var devices: [Device] = []
    private(set) var active: Device?
    private(set) var searching = false

    @ObservationIgnored private var discoverer: VLCRendererDiscoverer?
    @ObservationIgnored private let relay = DiscovererRelay()

    /// Starts looking for devices. Called when the cast menu opens, so the local network permission
    /// prompt appears in context rather than at launch.
    func startDiscovery() {
        guard discoverer == nil, let discoverer = VLCRendererDiscoverer(name: "Bonjour_renderer") else { return }
        relay.onChange = { Task { @MainActor in Casting.shared.refresh() } }
        discoverer.delegate = relay
        guard discoverer.start() else { return }
        self.discoverer = discoverer
        searching = true
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            self?.searching = false
        }
    }

    func cast(to device: Device?) {
        guard device != active else { return }
        active = device
        Player.shared.setRenderer(device?.item, name: device?.name)
    }

    private func refresh() {
        devices = (discoverer?.renderers ?? []).map { item in
            Device(id: "\(item.type):\(item.name)", name: item.name,
                   playsVideo: Int(item.flags) & VLCRendererPlay.playsVideo.rawValue != 0, item: item)
        }
        if let active, !devices.contains(active) {
            cast(to: nil)
        }
    }
}

/// libVLC calls the renderer delegate on its own thread; this hops back to the main actor.
private final class DiscovererRelay: NSObject, VLCRendererDiscovererDelegate, @unchecked Sendable {
    var onChange: (@Sendable () -> Void)?

    func rendererDiscovererItemAdded(_ rendererDiscoverer: VLCRendererDiscoverer, item: VLCRendererItem) { onChange?() }
    func rendererDiscovererItemDeleted(_ rendererDiscoverer: VLCRendererDiscoverer, item: VLCRendererItem) { onChange?() }
}
