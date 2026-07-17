//
//  PreferencesWindowController.swift
//  PicFerry
//
//  Created by Svend Jin on 2019/6/11.
//  Copyright © 2019 Svend Jin. All rights reserved.
//

import Cocoa
import SwiftUI

final class PreferencesWindowController: NSWindowController {

    private let hostPreferencesModel: HostPreferencesModel
    private let navigationModel: PreferencesNavigationModel
    private var allowsDiscardingHostChanges = false

    static func make() -> PreferencesWindowController {
        PreferencesWindowController(
            hostPreferencesModel: HostPreferencesModel(),
            navigationModel: PreferencesNavigationModel()
        )
    }

    private init(
        hostPreferencesModel: HostPreferencesModel,
        navigationModel: PreferencesNavigationModel
    ) {
        self.hostPreferencesModel = hostPreferencesModel
        self.navigationModel = navigationModel

        let rootView = ModernPreferencesView(
            hostModel: hostPreferencesModel,
            navigationModel: navigationModel
        )
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1040, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController

        super.init(window: window)
        configure(window)
    }

    required init?(coder: NSCoder) {
        self.hostPreferencesModel = HostPreferencesModel()
        self.navigationModel = PreferencesNavigationModel()
        super.init(coder: coder)
    }

    override func showWindow(_ sender: Any?) {
        if NSApp.activationPolicy() == .accessory {
            NSApp.setActivationPolicy(.regular)
        }
        super.showWindow(sender)
    }

    func show(_ destination: PreferencesDestination? = nil) {
        if let destination {
            navigationModel.selection = destination
        }
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func configure(_ window: NSWindow) {
        window.title = ""
        window.setAccessibilityLabel("Preferences".localized)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.toolbarStyle = .unified
        window.backgroundColor = .windowBackgroundColor
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 720, height: 480)
        window.setContentSize(NSSize(width: 1040, height: 680))
        window.setFrameAutosaveName("PicFerry.PreferencesWindow.HostWorkspaceV3")
        window.delegate = self

        if !window.setFrameUsingName("PicFerry.PreferencesWindow.HostWorkspaceV3") {
            window.center()
        }

        // Avoid auto-focusing an inner control (e.g. a shortcut recorder),
        // which would make the scroll view jump away from the top on open.
        window.initialFirstResponder = window.contentView
    }
}

extension PreferencesWindowController: NSWindowDelegate {

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard hostPreferencesModel.hasChanges,
              !allowsDiscardingHostChanges else {
            return true
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Warning".localized
        alert.informativeText = "Continuing will lose unsaved data. Do you want to continue?".localized
        alert.addButton(withTitle: "Continue".localized)
        alert.addButton(withTitle: "Cancel".localized)
        alert.beginSheetModal(for: sender) { [weak self, weak sender] response in
            guard let self, let sender,
                  response == .alertFirstButtonReturn else {
                return
            }

            self.hostPreferencesModel.reload()
            self.allowsDiscardingHostChanges = true
            sender.close()
            self.allowsDiscardingHostChanges = false
        }
        return false
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
