//
//  StatusMenuController.swift
//  PicFerry
//
//  Created by Svend Jin on 2019/6/11.
//  Copyright © 2019 Svend Jin. All rights reserved.
//

import AppKit
import KeyboardShortcuts

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    let menu = NSMenu()

    private unowned let appDelegate: AppDelegate
    private let cancelUploadMenuItem = NSMenuItem()
    private let cancelUploadSeparator = NSMenuItem.separator()
    private let uploadFromSelectFileMenuItem = NSMenuItem()
    private let uploadFromPasteboardMenuItem = NSMenuItem()
    private let uploadFromScreenshotMenuItem = NSMenuItem()
    private let hostMenuItem = NSMenuItem()
    private let outputFormatMenuItem = NSMenuItem()
    private let outputFormatEncodedMenuItem = NSMenuItem()
    private let compressFactorMenuItem = NSMenuItem()

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init()
        configureMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshMenu()
    }

    func refreshMenu() {
        let isUploading = appDelegate.uploading
        cancelUploadMenuItem.isHidden = !isUploading
        cancelUploadSeparator.isHidden = !isUploading
        uploadFromSelectFileMenuItem.isEnabled = !isUploading
        uploadFromPasteboardMenuItem.isEnabled = !isUploading
        uploadFromScreenshotMenuItem.isEnabled = !isUploading

        uploadFromSelectFileMenuItem.setShortcut(for: .selectFileShortcut)
        uploadFromPasteboardMenuItem.setShortcut(for: .pasteboardShortcut)
        uploadFromScreenshotMenuItem.setShortcut(for: .screenshotShortcut)

        rebuildHostMenu()
        rebuildOutputFormatMenu()
        refreshOutputEncodingMenu()
        rebuildCompressionMenu()
    }

    private func configureMenu() {
        menu.delegate = self
        menu.autoenablesItems = false

        configure(
            cancelUploadMenuItem,
            title: "Cancel upload".localized,
            action: #selector(cancelUpload)
        )
        menu.addItem(cancelUploadMenuItem)
        menu.addItem(cancelUploadSeparator)

        configure(
            uploadFromSelectFileMenuItem,
            title: "Upload from select file".localized,
            action: #selector(uploadSelectedFile)
        )
        configure(
            uploadFromPasteboardMenuItem,
            title: "Upload from clipboard".localized,
            action: #selector(uploadPasteboard)
        )
        configure(
            uploadFromScreenshotMenuItem,
            title: "Upload from screenshot".localized,
            action: #selector(uploadScreenshot)
        )
        menu.addItem(uploadFromSelectFileMenuItem)
        menu.addItem(uploadFromPasteboardMenuItem)
        menu.addItem(uploadFromScreenshotMenuItem)

        configureSubmenuItem(hostMenuItem, title: "Host".localized)
        configureSubmenuItem(outputFormatMenuItem, title: "Output format".localized)
        configureSubmenuItem(outputFormatEncodedMenuItem, title: "Output format encode".localized)
        configureSubmenuItem(
            compressFactorMenuItem,
            title: "Compress images before uploading".localized
        )
        menu.addItem(hostMenuItem)
        menu.addItem(outputFormatMenuItem)
        menu.addItem(outputFormatEncodedMenuItem)
        menu.addItem(compressFactorMenuItem)

        menu.addItem(.separator())
        menu.addItem(
            makeMenuItem(
                title: "Upload History".localized,
                action: #selector(openUploadHistory),
                keyEquivalent: "d"
            )
        )
        menu.addItem(
            makeMenuItem(
                title: "Preferences".localized,
                action: #selector(openPreferences),
                keyEquivalent: ","
            )
        )

        menu.addItem(.separator())
        menu.addItem(
            makeMenuItem(
                title: "Quit".localized,
                action: #selector(quit),
                keyEquivalent: "q"
            )
        )

        refreshMenu()
    }

    private func configure(_ item: NSMenuItem, title: String, action: Selector) {
        item.title = title
        item.target = self
        item.action = action
        item.isEnabled = true
    }

    private func configureSubmenuItem(_ item: NSMenuItem, title: String) {
        item.title = title
        item.submenu = NSMenu(title: title)
        item.isEnabled = true
    }

    private func makeMenuItem(
        title: String,
        action: Selector,
        keyEquivalent: String = ""
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.isEnabled = true
        return item
    }

    private func rebuildHostMenu() {
        guard let submenu = hostMenuItem.submenu else { return }
        submenu.removeAllItems()

        let hosts = ConfigManager.shared.getHostItems()
        let selectedHostID = ConfigManager.shared.getDefaultHost()?.id
        for host in hosts {
            let item = makeMenuItem(title: host.name, action: #selector(changeDefaultHost))
            item.identifier = NSUserInterfaceItemIdentifier(host.id)
            item.image = Host.getIconByType(type: host.type)
            item.state = host.id == selectedHostID ? .on : .off
            submenu.addItem(item)
        }

        setMenuTitle(
            hostMenuItem,
            title: "Host".localized,
            selectedValue: hosts.first(where: { $0.id == selectedHostID })?.name
        )
    }

    private func rebuildOutputFormatMenu() {
        guard let submenu = outputFormatMenuItem.submenu else { return }
        submenu.removeAllItems()

        let formats = DBManager.shared.getOutputFormatList()
        let selectedOutputID = ConfigManager.shared.getOutputType()?.identifier
        for format in formats {
            guard let identifier = format.identifier else { continue }
            let item = makeMenuItem(title: format.name, action: #selector(changeOutputFormat))
            item.tag = identifier
            item.state = identifier == selectedOutputID ? .on : .off
            submenu.addItem(item)
        }

        setMenuTitle(
            outputFormatMenuItem,
            title: "Output format".localized,
            selectedValue: formats.first(where: { $0.identifier == selectedOutputID })?.name
        )
    }

    private func refreshOutputEncodingMenu() {
        guard let submenu = outputFormatEncodedMenuItem.submenu else { return }
        submenu.removeAllItems()

        let isEncoded = Defaults[.outputFormatEncoded]
        let options = [
            (title: "On".localized, value: true),
            (title: "Off".localized, value: false)
        ]
        for (index, option) in options.enumerated() {
            let item = makeMenuItem(title: option.title, action: #selector(changeOutputEncoding))
            item.tag = index
            item.state = option.value == isEncoded ? .on : .off
            submenu.addItem(item)
        }

        setMenuTitle(
            outputFormatEncodedMenuItem,
            title: "Output format encode".localized,
            selectedValue: isEncoded ? "On".localized : "Off".localized
        )
    }

    private func rebuildCompressionMenu() {
        guard let submenu = compressFactorMenuItem.submenu else { return }
        submenu.removeAllItems()

        let selectedFactor = ConfigManager.shared.compressFactor
        for factor in stride(from: 10, through: 100, by: 10) {
            let title = factor == 100 ? "Off".localized : "\(factor)%"
            let item = makeMenuItem(title: title, action: #selector(changeCompressionFactor))
            item.tag = factor
            item.state = factor == selectedFactor ? .on : .off
            submenu.addItem(item)
        }

        let selectedTitle = selectedFactor >= 100 ? "Off".localized : "\(selectedFactor)%"
        setMenuTitle(
            compressFactorMenuItem,
            title: "Compress images before uploading".localized,
            selectedValue: selectedTitle
        )
    }

    private func setMenuTitle(_ item: NSMenuItem, title: String, selectedValue: String?) {
        guard let selectedValue, !selectedValue.isEmpty else {
            item.attributedTitle = nil
            item.title = title
            return
        }

        let fullTitle = "\(title)   \(selectedValue)"
        let attributedTitle = NSMutableAttributedString(string: fullTitle)
        let selectedRange = (fullTitle as NSString).range(of: selectedValue, options: .backwards)
        attributedTitle.addAttributes(
            [
                .font: NSFont.menuFont(ofSize: 12),
                .foregroundColor: NSColor.secondaryLabelColor
            ],
            range: selectedRange
        )
        item.attributedTitle = attributedTitle
    }

    @objc private func cancelUpload() {
        appDelegate.uploadCancel()
    }

    @objc private func uploadSelectedFile() {
        appDelegate.selectFile()
    }

    @objc private func uploadPasteboard() {
        appDelegate.uploadByPasteboard()
    }

    @objc private func uploadScreenshot() {
        appDelegate.screenshotAndUpload()
    }

    @objc private func changeDefaultHost(_ sender: NSMenuItem) {
        guard let hostID = sender.identifier?.rawValue else { return }
        Defaults[.defaultHostId] = hostID
        refreshMenu()
    }

    @objc private func changeOutputFormat(_ sender: NSMenuItem) {
        ConfigManager.shared.setOutputType(sender.tag)
        refreshMenu()
    }

    @objc private func changeOutputEncoding(_ sender: NSMenuItem) {
        Defaults[.outputFormatEncoded] = sender.tag == 0
        refreshMenu()
    }

    @objc private func changeCompressionFactor(_ sender: NSMenuItem) {
        ConfigManager.shared.compressFactor = sender.tag
        refreshMenu()
    }

    @objc private func openUploadHistory() {
        appDelegate.databaseWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        appDelegate.databaseWindowController.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func openPreferences() {
        appDelegate.preferencesWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        appDelegate.preferencesWindowController.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
