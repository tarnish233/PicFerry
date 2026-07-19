//
//  ModernPreferencesView.swift
//  GitPic
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
        .frame(minWidth: 760, minHeight: 520)
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

private struct PreferencesPage<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PreferencesStyleMetrics.sectionSpacing) {
                Text(title)
                    .font(.title2)
                    .bold()
                    .padding(.leading, PreferencesStyleMetrics.rowHorizontalInset)
                    .padding(.bottom, 2)

                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PreferencesStyleMetrics.pageHorizontalInset)
            .padding(.top, PreferencesStyleMetrics.pageTopInset)
            .padding(.bottom, PreferencesStyleMetrics.pageBottomInset)
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
        VStack(alignment: .leading, spacing: PreferencesStyleMetrics.sectionHeaderSpacing) {
            Text(title)
                .font(.headline)
                .padding(.leading, PreferencesStyleMetrics.rowHorizontalInset)

            VStack(spacing: 0) {
                content
            }
            .preferencesCard()
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
        HStack(alignment: detail == nil ? .center : .top, spacing: PreferencesStyleMetrics.rowContentSpacing) {
            VStack(alignment: .leading, spacing: PreferencesStyleMetrics.titleDetailSpacing) {
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
        .padding(.horizontal, PreferencesStyleMetrics.rowHorizontalInset)
        .padding(.vertical, PreferencesStyleMetrics.rowVerticalInset)
        .frame(minHeight: PreferencesStyleMetrics.rowMinHeight)
    }
}

private struct PreferencesDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, PreferencesStyleMetrics.rowHorizontalInset)
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
                    "Launch GitPic at login".localized,
                    detail: "GitPic will automatically launch at login.".localized
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

@MainActor
@Observable
private final class AboutUpdateModel {
    enum State {
        case idle
        case checking
        case upToDate
        case available(AppRelease)
        case failed(String)
    }

    private(set) var state: State = .idle

    func checkForUpdates() {
        guard !isChecking else { return }
        state = .checking
        Task {
            do {
                let result = try await UpdateChecker.shared.checkForUpdates()
                switch result {
                case .upToDate:
                    state = .upToDate
                case .updateAvailable(let release):
                    state = .available(release)
                }
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    private var isChecking: Bool {
        if case .checking = state { return true }
        return false
    }
}

private struct AboutPreferencesView: View {
    @State private var updateModel = AboutUpdateModel()

    private var copyright: String {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String
            ?? "Copyright © 2021 Svend Jin. All rights reserved."
    }

    var body: some View {
        PreferencesPage("About".localized) {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 112, height: 112)
                        .accessibilityHidden(true)

                    VStack(spacing: 5) {
                        Text("GitPic")
                            .font(.largeTitle)
                            .bold()

                        Text(getAppVersionString())
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    updateControl
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 28)

                Divider()
                    .padding(.leading, PreferencesStyleMetrics.rowHorizontalInset)

                HStack(spacing: PreferencesStyleMetrics.rowContentSpacing) {
                    Label("Powered by Codex", systemImage: "sparkles")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(copyright)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.horizontal, PreferencesStyleMetrics.rowHorizontalInset)
                .padding(.vertical, PreferencesStyleMetrics.rowVerticalInset)
            }
            .preferencesCard()
        }
    }

    @ViewBuilder
    private var updateControl: some View {
        switch updateModel.state {
        case .idle:
            Button("Check for Updates".localized) {
                updateModel.checkForUpdates()
            }
            .padding(.top, 6)

        case .checking:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Checking for updates…".localized)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 6)

        case .upToDate:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
                Text("You're up to date.".localized)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 6)

        case .available(let release):
            VStack(spacing: 8) {
                Text(String(format: "A new version (%@) is available.".localized, release.tagName))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Download Update".localized) {
                    NSWorkspace.shared.open(release.htmlURL)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 6)

        case .failed(let message):
            VStack(spacing: 6) {
                Text("Could not check for updates.".localized)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                Button("Try Again".localized) {
                    updateModel.checkForUpdates()
                }
            }
            .padding(.top, 6)
        }
    }
}
