//
//  HostConfigurationView.swift
//  PicFerry
//

import SwiftUI

struct HostConfigurationView: View {
    let model: HostPreferencesModel
    let host: Host
    @State private var draft: HostEditorDraft
    @State private var revealsToken = false

    init(model: HostPreferencesModel, host: Host) {
        self.model = model
        self.host = host
        _draft = State(initialValue: HostEditorDraft(host: host))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HostPreferencesMetrics.sectionSpacing) {
                overviewSection
                usageSection
                configurationSection
            }
            .padding(HostPreferencesMetrics.pageInset)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .defaultScrollAnchor(.top)
        .onChange(of: draft.name) { _, value in
            model.updateName(value, hostID: host.id)
        }
        .onChange(of: draft.owner) { _, value in
            model.updateString(value, for: "owner", hostID: host.id)
        }
        .onChange(of: draft.repo) { _, value in
            model.updateString(value, for: "repo", hostID: host.id)
        }
        .onChange(of: draft.branch) { _, value in
            model.updateString(value, for: "branch", hostID: host.id)
        }
        .onChange(of: draft.token) { _, value in
            model.updateString(value, for: "token", hostID: host.id)
        }
        .onChange(of: draft.domain) { _, value in
            model.updateString(value, for: "domain", hostID: host.id)
        }
        .onChange(of: draft.saveKeyPath) { _, value in
            model.updateString(value, for: "saveKeyPath", hostID: host.id)
        }
    }

    private var overviewSection: some View {
        @Bindable var draft = draft

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(nsImage: Host.getIconByType(type: host.type))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 38, height: 38)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(host.type.name)
                        .font(.title3)
                        .bold()
                    Text("Host".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if model.isDefault(host) {
                    Label("Default image host".localized, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                } else {
                    Button("Set as Default".localized) {
                        model.setDefault(hostID: host.id)
                    }
                }
            }

            Divider()

            HostConfigurationField(
                "Image host name".localized,
                detail: "Used to identify this configuration in the menu bar.".localized
            ) {
                TextField("Image host name".localized, text: $draft.name)
            }
        }
        .hostPanelStyle()
    }

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Before You Start".localized)
                    .font(.headline)
                Spacer()
                Button("View token guide".localized, action: model.openHelp)
            }

            Text(usageDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .hostPanelStyle()
    }

    private var configurationSection: some View {
        @Bindable var draft = draft

        return VStack(alignment: .leading, spacing: 16) {
            Text("Configuration".localized)
                .font(.title3)
                .bold()

            HostConfigurationField(
                "Owner".localized,
                detail: ownerDescription
            ) {
                TextField(ownerPlaceholder, text: $draft.owner)
            }

            Divider()

            HostConfigurationField(
                "Repo".localized,
                detail: "A repository used to store uploaded images.".localized
            ) {
                TextField("e.g. images", text: $draft.repo)
            }

            Divider()

            HostConfigurationField(
                "Branch".localized,
                detail: "The branch that receives uploaded files.".localized
            ) {
                TextField("main", text: $draft.branch)
            }

            Divider()

            HostConfigurationField(
                "Token".localized,
                detail: "Stored securely in Keychain. Grant only the repository permissions PicFerry needs.".localized
            ) {
                HStack(spacing: 8) {
                    if revealsToken {
                        TextField(tokenPlaceholder, text: $draft.token)
                    } else {
                        SecureField(tokenPlaceholder, text: $draft.token)
                    }

                    Button(
                        revealsToken ? "Hide token".localized : "Show token".localized,
                        systemImage: revealsToken ? "eye.slash" : "eye",
                        action: toggleTokenVisibility
                    )
                    .labelStyle(.iconOnly)
                }
            }

            Divider()

            HostConfigurationField(
                "Domain".localized,
                detail: "Optional. Use a custom CDN or raw-file domain for generated links.".localized
            ) {
                TextField("https://cdn.example.com", text: $draft.domain)
            }

            Divider()

            HostConfigurationField(
                "Save Key".localized,
                detail: "Leave empty to use PicFerry/{filename}{.suffix}. Date and random variables are supported.".localized
            ) {
                TextField("PicFerry/{filename}{.suffix}", text: $draft.saveKeyPath)
            }
        }
        .hostPanelStyle()
    }

    private var usageDescription: String {
        switch host.type {
        case .github:
            "Create a fine-grained GitHub token with access to the target repository and permission to write repository contents.".localized
        case .gitee:
            "Create a Gitee personal access token with permission to write files to the target repository.".localized
        }
    }

    private var ownerDescription: String {
        switch host.type {
        case .github:
            "The GitHub user or organization that owns the repository.".localized
        case .gitee:
            "The Gitee user or organization that owns the repository.".localized
        }
    }

    private var ownerPlaceholder: String {
        switch host.type {
        case .github:
            "e.g. octocat"
        case .gitee:
            "e.g. gitee-user"
        }
    }

    private var tokenPlaceholder: String {
        switch host.type {
        case .github:
            "GitHub token".localized
        case .gitee:
            "Gitee token".localized
        }
    }

    private func toggleTokenVisibility() {
        revealsToken.toggle()
    }
}

private extension View {
    func hostPanelStyle() -> some View {
        padding(HostPreferencesMetrics.panelInset)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: HostPreferencesMetrics.panelRadius))
            .overlay {
                RoundedRectangle(cornerRadius: HostPreferencesMetrics.panelRadius)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.28), lineWidth: 1)
            }
    }
}
