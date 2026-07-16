//
//  DatabaseWindowController.swift
//  PicFerry
//

import AppKit
import SwiftUI

final class DatabaseWindowController: NSWindowController {
    static func make() -> DatabaseWindowController {
        let hostingController = NSHostingController(rootView: HistoryView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        let controller = DatabaseWindowController(window: window)
        controller.configure(window)
        return controller
    }

    private func configure(_ window: NSWindow) {
        window.title = "Upload History".localized
        window.setAccessibilityLabel("Upload History".localized)
        window.toolbarStyle = .unified
        window.minSize = NSSize(width: 760, height: 480)
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("PicFerry.HistoryWindow")
        window.delegate = self
        if !window.setFrameUsingName("PicFerry.HistoryWindow") {
            window.center()
        }
    }

    override func showWindow(_ sender: Any?) {
        if NSApp.activationPolicy() == .accessory {
            NSApp.setActivationPolicy(.regular)
        }
        super.showWindow(sender)
    }
}

extension DatabaseWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
