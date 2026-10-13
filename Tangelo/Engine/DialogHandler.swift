// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import AppKit
import VLCKit

/// Shows libVLC's dialogs natively: logins for SMB shares and protected streams, questions such as
/// Chromecast transcoding warnings, and errors. Without this, libVLC silently fails those requests.
final class DialogHandler: NSObject, VLCCustomDialogRendererProtocol, @unchecked Sendable {
    @MainActor private static var provider: VLCDialogProvider?
    private static let handler = DialogHandler()

    @MainActor
    static func install() {
        provider = VLCDialogProvider(library: VLCLibrary.shared(), customUI: true)
        provider?.customRenderer = handler
    }

    // libVLC may call these from any thread; each hops to the main actor to show UI.

    func showError(withTitle error: String, message: String) {
        Task { @MainActor in
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = error
            alert.informativeText = message
            alert.runModal()
        }
    }

    func showLogin(withTitle title: String, message: String, defaultUsername username: String?,
                   askingForStorage: Bool, withReference reference: NSValue) {
        nonisolated(unsafe) let reference = reference
        Task { @MainActor in
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.addButton(withTitle: "Connect")
            alert.addButton(withTitle: "Cancel")

            let user = NSTextField(string: username ?? "")
            user.placeholderString = "Name"
            let password = NSSecureTextField(string: "")
            password.placeholderString = "Password"
            let remember = NSButton(checkboxWithTitle: "Remember in Keychain", target: nil, action: nil)
            remember.state = .on
            remember.isHidden = !askingForStorage
            let stack = NSStackView(views: [user, password, remember])
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = 8
            for field in [user, password] { field.widthAnchor.constraint(equalToConstant: 260).isActive = true }
            stack.frame = NSRect(x: 0, y: 0, width: 260, height: askingForStorage ? 84 : 58)
            alert.accessoryView = stack
            alert.window.initialFirstResponder = username?.isEmpty == false ? password : user

            if alert.runModal() == .alertFirstButtonReturn {
                Self.provider?.postUsername(user.stringValue, andPassword: password.stringValue,
                                            forDialogReference: reference, store: remember.state == .on)
            } else {
                Self.provider?.dismissDialog(withReference: reference)
            }
        }
    }

    func showQuestion(withTitle title: String, message: String, type questionType: VLCDialogQuestionType,
                      cancel cancelString: String?, action1String: String?, action2String: String?,
                      withReference reference: NSValue) {
        nonisolated(unsafe) let reference = reference
        Task { @MainActor in
            let alert = NSAlert()
            alert.alertStyle = questionType == .critical ? .critical : questionType == .warning ? .warning : .informational
            alert.messageText = title
            alert.informativeText = message
            let actions = [action1String, action2String].compactMap { $0 }
            actions.forEach { alert.addButton(withTitle: $0) }
            alert.addButton(withTitle: cancelString ?? "Cancel")

            let response = alert.runModal().rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
            if response < actions.count, let action = [action1String, action2String].firstIndex(of: actions[response]) {
                Self.provider?.postAction(Int32(action + 1), forDialogReference: reference)
            } else {
                Self.provider?.dismissDialog(withReference: reference)
            }
        }
    }

    func showProgress(withTitle title: String, message: String, isIndeterminate: Bool, position: Float,
                      cancel cancelString: String?, withReference reference: NSValue) {}

    func updateProgress(withReference reference: NSValue, message: String?, position: Float) {}

    func cancelDialog(withReference reference: NSValue) {}
}
