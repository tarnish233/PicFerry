//
//  GithubBranchDropdown.swift
//  GitPic
//

import SwiftUI

struct GithubBranchDropdown: View {
    let currentBranch: String
    let token: String
    let owner: String
    let repo: String
    let model: GithubRepositorySelectionModel
    let onSelect: (String) -> Void

    private var trimmedToken: String {
        token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canLoad: Bool {
        !trimmedToken.isEmpty && !owner.isEmpty && !repo.isEmpty
    }

    var body: some View {
        Menu {
            menuContent
        } label: {
            GithubSelectionFieldLabel(
                value: displayText,
                symbolName: "arrow.triangle.branch",
                isPlaceholder: currentBranch.isEmpty,
                isLoading: model.isLoadingBranches
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(maxWidth: .infinity)
        .disabled(!canLoad)
        .githubSelectionField()
        .accessibilityLabel("Branch".localized)
        .accessibilityValue(displayText)
        .accessibilityHint("Choose branch".localized)
        .task(id: "\(trimmedToken)\u{0}\(owner)\u{0}\(repo)") {
            model.loadBranches(token: trimmedToken, owner: owner, repo: repo)
        }
    }

    private var displayText: String {
        currentBranch.isEmpty ? "Choose branch".localized : currentBranch
    }

    @ViewBuilder
    private var menuContent: some View {
        switch model.branchPhase {
        case .loaded(let branches):
            if branches.isEmpty {
                Text("No branches found.".localized)
            } else {
                ForEach(branches, id: \.self) { branch in
                    Button(branch) { onSelect(branch) }
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
            Button("Refresh".localized, systemImage: "arrow.clockwise", action: reload)
        }
    }

    private func reload() {
        model.loadBranches(
            token: trimmedToken,
            owner: owner,
            repo: repo,
            force: true
        )
    }
}
