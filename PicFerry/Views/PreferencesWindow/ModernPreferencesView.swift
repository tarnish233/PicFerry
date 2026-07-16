//
//  ModernPreferencesView.swift
//  PicFerry
//
//  Created for the macOS 26 preferences redesign.
//

import AppKit
import KeyboardShortcuts
import LaunchAtLogin
import Observation
import SwiftUI

enum PreferencesDestination: String, CaseIterable, Identifiable {
    case general
    case hosts
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "General".localized
        case .hosts:
            return "Host".localized
        case .about:
            return "About".localized
        }
    }

    var symbolName: String {
        switch self {
        case .general:
            return "gearshape"
        case .hosts:
            return "externaldrive"
        case .about:
            return "info.circle"
        }
    }
}

struct ModernPreferencesView: View {
    @State private var selection = PreferencesDestination.general
    @State private var generalModel = GeneralPreferencesModel()
    private let hostModel: HostPreferencesModel

    init(hostModel: HostPreferencesModel) {
        self.hostModel = hostModel
    }

    var body: some View {
        NavigationSplitView {
            List(PreferencesDestination.allCases, selection: $selection) { destination in
                Label(destination.title, systemImage: destination.symbolName)
                    .font(.body)
                    .padding(.vertical, 4)
                    .tag(destination)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 148, ideal: 160, max: 176)
        } detail: {
            detailView
                .transaction { transaction in
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 740, minHeight: 480)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .general:
            GeneralPreferencesView(model: generalModel)
        case .hosts:
            ModernHostPreferencesView(model: hostModel)
        case .about:
            AboutPreferencesView()
        }
    }
}

// MARK: - Shared layout

private enum Metrics {
    static let pageHorizontalInset: CGFloat = 24
    static let pageTopInset: CGFloat = 24
    static let pageBottomInset: CGFloat = 28
    static let contentMaxWidth: CGFloat = 640

    static let sectionSpacing: CGFloat = 22
    static let sectionHeaderSpacing: CGFloat = 8

    static let rowHorizontalInset: CGFloat = 16
    static let rowVerticalInset: CGFloat = 10
    static let rowMinHeight: CGFloat = 44
    static let rowContentSpacing: CGFloat = 16
    static let titleDetailSpacing: CGFloat = 3

    static let cornerRadius: CGFloat = 12

}

private struct PreferencesPage<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                Text(title)
                    .font(.title2)
                    .bold()
                    .padding(.leading, Metrics.rowHorizontalInset)
                    .padding(.bottom, 2)

                content
            }
            .frame(maxWidth: Metrics.contentMaxWidth, alignment: .leading)
            .padding(.horizontal, Metrics.pageHorizontalInset)
            .padding(.top, Metrics.pageTopInset)
            .padding(.bottom, Metrics.pageBottomInset)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .defaultScrollAnchor(.top)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct PreferencesSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionHeaderSpacing) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.leading, Metrics.rowHorizontalInset)

            VStack(spacing: 0) {
                content
            }
            .background(
                Color(nsColor: .controlBackgroundColor).opacity(0.78),
                in: RoundedRectangle(cornerRadius: Metrics.cornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.cornerRadius)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.22), lineWidth: 1)
            }
        }
    }
}

private struct PreferencesRow<Control: View>: View {
    let title: String
    let detail: String?
    let control: Control

    init(_ title: String, detail: String? = nil, @ViewBuilder control: () -> Control) {
        self.title = title
        self.detail = detail
        self.control = control()
    }

    var body: some View {
        HStack(alignment: detail == nil ? .center : .top, spacing: Metrics.rowContentSpacing) {
            VStack(alignment: .leading, spacing: Metrics.titleDetailSpacing) {
                Text(title)
                    .font(.body)

                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            control
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, Metrics.rowHorizontalInset)
        .padding(.vertical, Metrics.rowVerticalInset)
        .frame(minHeight: Metrics.rowMinHeight)
    }
}

private struct PreferencesDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, Metrics.rowHorizontalInset)
    }
}

// MARK: - General

@MainActor
@Observable
private final class GeneralPreferencesModel {
    var hasFullDiskAccess = false

    init() {
        reload()
    }

    func reload() {
        refreshFullDiskAccess()
    }

    func refreshFullDiskAccess() {
        hasFullDiskAccess = DiskPermissionManager.shared.checkFullDiskAuthorizationStatus()
    }

    func manageFullDiskAccess() {
        if hasFullDiskAccess,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        } else {
            DiskPermissionManager.shared.requestFullDiskPermissions()
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled else { return }
                self?.refreshFullDiskAccess()
            }
        }
    }

    func resetAllPreferences() {
        ConfigManager.shared.removeAllUserDefaults()
        ConfigManager.shared.firstSetup()
        KeyboardShortcuts.resetAll()
        reload()
    }
}

private struct GeneralPreferencesView: View {
    @Bindable var model: GeneralPreferencesModel
    @State private var showsResetConfirmation = false
    @State private var showsOutputFormatEditor = false

    var body: some View {
        PreferencesPage("General".localized) {
            PreferencesSection("Startup".localized) {
                PreferencesRow(
                    "Launch PicFerry at login".localized,
                    detail: "PicFerry will automatically launch at login.".localized
                ) {
                    LaunchAtLogin.Toggle { EmptyView() }
                        .labelsHidden()
                }
            }

            PreferencesSection("Keyboard Shortcuts".localized) {
                PreferencesRow("Select file upload".localized) {
                    KeyboardShortcuts.Recorder(for: .selectFileShortcut)
                }
                PreferencesDivider()
                PreferencesRow("Pasteboard upload".localized) {
                    KeyboardShortcuts.Recorder(for: .pasteboardShortcut)
                }
                PreferencesDivider()
                PreferencesRow("Screenshot upload".localized) {
                    KeyboardShortcuts.Recorder(for: .screenshotShortcut)
                }
            }

            PreferencesSection("Output".localized) {
                PreferencesRow(
                    "Output Format Customization".localized,
                    detail: "Configure how uploaded links are copied to the clipboard.".localized
                ) {
                    Button("Config".localized) {
                        showsOutputFormatEditor = true
                    }
                }
                PreferencesDivider()
                PreferencesRow(
                    "Screenshot upload".localized,
                    detail: "Uses the built-in macOS screenshot tool.".localized
                ) {
                    Label("macOS", systemImage: "camera.viewfinder")
                        .foregroundStyle(.secondary)
                }
            }

            PreferencesSection("Permissions".localized) {
                PreferencesRow(
                    "Full Disk Access".localized,
                    detail: model.hasFullDiskAccess
                        ? "Authorized".localized
                        : "Required for reading files outside the sandbox.".localized
                ) {
                    Button(
                        model.hasFullDiskAccess ? "Manage Permission".localized : "Grant Permission".localized,
                        action: model.manageFullDiskAccess
                    )
                }
            }

            PreferencesSection("Reset".localized) {
                PreferencesRow(
                    "Reset preferences".localized,
                    detail: "This resets all PicFerry preferences and keyboard shortcuts.".localized
                ) {
                    Button("Reset preferences".localized, role: .destructive) {
                        showsResetConfirmation = true
                    }
                }
            }
        }
        .onAppear(perform: model.refreshFullDiskAccess)
        .sheet(isPresented: $showsOutputFormatEditor) {
            OutputFormatEditorView()
        }
        .alert("Reset User Preferences?".localized, isPresented: $showsResetConfirmation) {
            Button("Cancel".localized, role: .cancel) {}
            Button("Reset".localized, role: .destructive, action: model.resetAllPreferences)
        } message: {
            Text("⚠️ Note that this will reset all user preferences".localized)
        }
    }
}

// MARK: - About

private struct AboutPreferencesView: View {
    private var copyright: String {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String
            ?? "Copyright © 2021 Svend Jin. All rights reserved."
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 112, height: 112)
                    .accessibilityHidden(true)

                VStack(spacing: 5) {
                    Text("PicFerry")
                        .font(.largeTitle)
                        .bold()

                    Text(getAppVersionString())
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Label("Powered by Codex", systemImage: "sparkles")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffect()
                    .padding(.top, 6)
            }

            Spacer(minLength: 0)

            Text(copyright)
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Metrics.pageHorizontalInset)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
