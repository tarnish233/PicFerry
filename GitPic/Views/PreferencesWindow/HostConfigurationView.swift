//
//  HostConfigurationView.swift
//  GitPic
//
//  单页 GitHub 图床配置：登录 → 选仓库 → 选分支 / Single-page GitHub host config.
//

import SwiftUI

struct HostConfigurationView: View {
    let model: HostPreferencesModel
    let host: Host
    @State private var draft: HostEditorDraft
    @State private var repositorySelection = GithubRepositorySelectionModel()

    init(model: HostPreferencesModel, host: Host) {
        self.model = model
        self.host = host
        _draft = State(initialValue: HostEditorDraft(host: host))
    }

    private var isSignedIn: Bool {
        !draft.token.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HostPreferencesMetrics.sectionSpacing) {
                accountSection
                repositorySection
            }
            .padding(HostPreferencesMetrics.pageInset)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .defaultScrollAnchor(.top)
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
        .onChange(of: draft.saveKeyPath) { _, value in
            model.updateString(value, for: "saveKeyPath", hostID: host.id)
        }
        .onDisappear(perform: repositorySelection.cancel)
    }

    // MARK: - Account

    private var accountSection: some View {
        @Bindable var draft = draft

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(nsImage: Host.getIconByType(type: .github))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(host.type.name)
                        .font(.title3)
                        .bold()
                    Text("Image Host".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Divider()

            if isSignedIn {
                signedInRow
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sign in to let GitPic upload to your repositories.".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    GithubSignInView { token, login in
                        guard model.completeSignIn(
                            token: token,
                            login: login,
                            hostID: host.id
                        ) else {
                            return false
                        }

                        repositorySelection.reset()
                        draft.token = token
                        draft.owner = login ?? ""
                        draft.repo = ""
                        draft.branch = ""
                        return true
                    }
                }
            }
        }
        .padding(HostPreferencesMetrics.panelInset)
        .preferencesCard()
    }

    private var signedInRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(signedInTitle)
                    .font(.body)
                Text("Token saved to Keychain.".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Sign out".localized, action: signOut)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    private var signedInTitle: String {
        let owner = draft.owner.trimmingCharacters(in: .whitespaces)
        return owner.isEmpty
            ? "Signed in".localized
            : String(format: "Signed in as %@".localized, owner)
    }

    // MARK: - Repository

    private var repositorySection: some View {
        @Bindable var draft = draft

        return VStack(alignment: .leading, spacing: 16) {
            Text("Repository".localized)
                .font(.title3)
                .bold()

            HostConfigurationField(
                "Repo".localized,
                detail: "The repository that stores uploaded images.".localized
            ) {
                GithubRepoDropdown(
                    currentOwner: draft.owner,
                    currentRepo: draft.repo,
                    token: draft.token,
                    model: repositorySelection
                ) { repository in
                    repositorySelection.clearBranches()
                    draft.owner = repository.owner
                    draft.repo = repository.name
                    draft.branch = repository.defaultBranch
                }
            }

            Divider()

            HostConfigurationField(
                "Branch".localized,
                detail: "The branch that receives uploaded files.".localized
            ) {
                GithubBranchDropdown(
                    currentBranch: draft.branch,
                    token: draft.token,
                    owner: draft.owner,
                    repo: draft.repo,
                    model: repositorySelection
                ) { branch in
                    draft.branch = branch
                }
            }

            Divider()

            HostConfigurationField(
                "Save Key".localized,
                detail: "Leave empty to use GitPic/{filename}{.suffix}. Date and random variables are supported.".localized
            ) {
                TextField("GitPic/{filename}{.suffix}", text: $draft.saveKeyPath)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, HostPreferencesMetrics.inputHorizontalInset)
                    .frame(minHeight: HostPreferencesMetrics.inputHeight)
                    .background(
                        Color(nsColor: .textBackgroundColor),
                        in: RoundedRectangle(cornerRadius: HostPreferencesMetrics.inputCornerRadius)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: HostPreferencesMetrics.inputCornerRadius)
                            .stroke(.quaternary, lineWidth: 1)
                    }
            }
        }
        .padding(HostPreferencesMetrics.panelInset)
        .preferencesCard()
    }

    private func signOut() {
        guard model.signOut(hostID: host.id) else { return }
        repositorySelection.reset()
        draft.token = ""
        draft.owner = ""
        draft.repo = ""
        draft.branch = ""
    }
}
