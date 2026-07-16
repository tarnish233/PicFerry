//
//  ScreenshotAuthorizationHelpViewController.swift
//  PicFerry
//
//  Native SwiftUI screen-capture permission help.
//

import AppKit
import SwiftUI

struct ScreenshotAuthorizationHelpView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.inset.filled.and.person.filled")
                .font(.system(size: 64))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Allow Screen Recording".localized)
                    .font(.title)
                    .bold()
                Text("PicFerry uses the built-in macOS screenshot tool. Allow Screen Recording in System Settings, then try again.".localized)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            HStack {
                Button("Not Now".localized, action: onClose)
                Button("Open System Settings".localized, systemImage: "gear", action: openSettings)
                    .buttonStyle(.glassProminent)
            }
        }
        .padding(32)
        .frame(minWidth: 520, minHeight: 340)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func openSettings() {
        ScreenUtil.openPrivacyScreenCapture()
        onClose()
    }
}

final class ScreenshotAuthorizationHelpWindowController: NSWindowController {
    static func make() -> ScreenshotAuthorizationHelpWindowController {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 360),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = NSHostingController(
            rootView: ScreenshotAuthorizationHelpView { [weak window] in window?.close() }
        )
        window.title = "Screenshot Permission".localized
        window.setAccessibilityLabel("Screenshot Permission".localized)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        return ScreenshotAuthorizationHelpWindowController(window: window)
    }
}
