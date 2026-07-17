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
    case history
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "General".localized
        case .hosts:
            return "Host".localized
        case .history:
            return "Upload History".localized
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
        case .history:
            return "clock.arrow.circlepath"
        case .about:
            return "info.circle"
        }
    }
}

struct ModernPreferencesView: View {
    @Bindable var navigationModel: PreferencesNavigationModel
    @State private var generalModel = GeneralPreferencesModel()
    private let hostModel: HostPreferencesModel

    init(
        hostModel: HostPreferencesModel,
        navigationModel: PreferencesNavigationModel
    ) {
        self.hostModel = hostModel
        self.navigationModel = navigationModel
    }

    var body: some View {
        NavigationSplitView {
            List(PreferencesDestination.allCases, selection: $navigationModel.selection) { destination in
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
        .frame(minWidth: 720, minHeight: 480)
    }

    @ViewBuilder
    private var detailView: some View {
        switch navigationModel.selection {
        case .general:
            GeneralPreferencesView(model: generalModel)
        case .hosts:
            ModernHostPreferencesView(model: hostModel)
        case .history:
            HistoryView()
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
            .frame(maxWidth: .infinity, alignment: .leading)
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
    var hasFileAccessAuthorization = false

    init() {
        reload()
    }

    func reload() {
        refreshFileAccessAuthorization()
    }

    func refreshFileAccessAuthorization() {
        hasFileAccessAuthorization = DiskPermissionManager.shared.checkDirectoryAuthorizationStatus()
    }

    func chooseFileAccessFolder() {
        DiskPermissionManager.shared.requestHomeDirectoryPermissions()
        refreshFileAccessAuthorization()
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
            }

            PreferencesSection("Permissions".localized) {
                PreferencesRow(
                    "File Access".localized,
                    detail: model.hasFileAccessAuthorization
                        ? "An authorized folder is available for command-line uploads.".localized
                        : "Choose a folder only when command-line uploads need persistent access to files outside the sandbox.".localized
                ) {
                    Button(
                        model.hasFileAccessAuthorization ? "Reauthorize".localized : "Choose Folder".localized,
                        action: model.chooseFileAccessFolder
                    )
                }
            }

            PreferencesSection("Reset".localized) {
                PreferencesRow(
                    "Restore General Settings".localized,
                    detail: "Resets keyboard shortcuts, output options, compression settings, and file access authorization.".localized
                ) {
                    Button("Restore General Settings".localized, role: .destructive) {
                        showsResetConfirmation = true
                    }
                }
            }
        }
        .onAppear(perform: model.refreshFileAccessAuthorization)
        .sheet(isPresented: $showsOutputFormatEditor) {
            OutputFormatEditorView()
        }
        .alert("Restore General Settings?".localized, isPresented: $showsResetConfirmation) {
            Button("Cancel".localized, role: .cancel) {}
            Button("Restore Settings".localized, role: .destructive, action: model.resetAllPreferences)
        } message: {
            Text("This will reset keyboard shortcuts, output options, compression settings, and file access authorization. Image hosts, Tokens, and upload history will be kept. This action cannot be undone.".localized)
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
