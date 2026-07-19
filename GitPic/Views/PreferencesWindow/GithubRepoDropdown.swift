//
//  GithubRepoDropdown.swift
//  GitPic
//
//  cc-switch 风格的仓库下拉：整行圆角框显示当前仓库，点击展开列表选择。
//  A cc-switch-style repository dropdown: a full-width bordered field showing the
//  current repo, tap to expand the list.
//

import SwiftUI

struct GithubRepoDropdown: View {
    let currentOwner: String
    let currentRepo: String
    let token: String
    let model: GithubRepositorySelectionModel
    let onSelect: (GithubRepo) -> Void

    private var trimmedToken: String {
        token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Menu {
            menuContent
        } label: {
            GithubSelectionFieldLabel(
                value: displayText,
                symbolName: "shippingbox",
                isPlaceholder: currentRepo.isEmpty,
                isLoading: model.isLoadingRepositories
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(maxWidth: .infinity)
        .disabled(trimmedToken.isEmpty)
        .githubSelectionField()
        .accessibilityLabel("Repo".localized)
        .accessibilityValue(displayText)
        .accessibilityHint("Choose repository".localized)
        .task(id: trimmedToken) {
            model.loadRepositories(token: trimmedToken)
        }
    }

    private var displayText: String {
        if !currentRepo.isEmpty {
            return currentOwner.isEmpty ? currentRepo : "\(currentOwner)/\(currentRepo)"
        }
        return trimmedToken.isEmpty ? "Sign in first".localized : "Choose repository".localized
    }

    @ViewBuilder
    private var menuContent: some View {
        switch model.repositoryPhase {
        case .loaded(let repos):
            if repos.isEmpty {
                Text("No repositories found.".localized)
            } else {
                ForEach(repos) { repo in
                    Button {
                        onSelect(repo)
                    } label: {
                        if repo.isPrivate {
                            Label(repo.fullName, systemImage: "lock")
                        } else {
                            Text(repo.fullName)
                        }
                    }
                }
            }
            Divider()
            Button("Refresh".localized, systemImage: "arrow.clockwise", action: reload)

        case .failed(let message):
            Text(message)
            Button("Retry".localized, systemImage: "arrow.clockwise", action: reload)

        case .loading:
            Text("Fetching…".localized)

        case .idle:
            Button("Fetch repositories".localized, systemImage: "square.and.arrow.down", action: reload)
        }
    }

    private func reload() {
        model.loadRepositories(token: trimmedToken, force: true)
    }
}
