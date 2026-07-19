//
//  GithubRepositorySelectionModel.swift
//  GitPic
//
//  Owns the token → repositories → branches dependency chain so stale requests
//  cannot overwrite a newer account or repository selection.
//

import Foundation
import Observation

@MainActor
@Observable
final class GithubRepositorySelectionModel {
    enum RepositoryPhase {
        case idle
        case loading
        case loaded([GithubRepo])
        case failed(String)
    }

    enum BranchPhase {
        case idle
        case loading
        case loaded([String])
        case failed(String)
    }

    private(set) var repositoryPhase: RepositoryPhase = .idle
    private(set) var branchPhase: BranchPhase = .idle

    private var repositoryTask: Task<Void, Never>?
    private var branchTask: Task<Void, Never>?
    private var repositoryRequestKey: String?
    private var branchRequestKey: String?
    private var repositoryRevision = 0
    private var branchRevision = 0

    var isLoadingRepositories: Bool {
        if case .loading = repositoryPhase { return true }
        return false
    }

    var isLoadingBranches: Bool {
        if case .loading = branchPhase { return true }
        return false
    }

    func loadRepositories(token: String, force: Bool = false) {
        let normalizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedToken.isEmpty else {
            reset()
            return
        }

        let requestKey = normalizedToken
        if !force,
           repositoryRequestKey == requestKey,
           case .loaded = repositoryPhase {
            return
        }

        repositoryTask?.cancel()
        repositoryRevision += 1
        let revision = repositoryRevision
        repositoryRequestKey = requestKey
        repositoryPhase = .loading

        repositoryTask = Task { [weak self] in
            guard let self else { return }
            do {
                let repositories = try await GithubOAuth.shared.fetchRepositories(token: normalizedToken)
                try Task.checkCancellation()
                guard revision == self.repositoryRevision,
                      requestKey == self.repositoryRequestKey else {
                    return
                }
                self.repositoryPhase = .loaded(repositories)
            } catch is CancellationError {
                return
            } catch {
                guard revision == self.repositoryRevision,
                      requestKey == self.repositoryRequestKey else {
                    return
                }
                self.repositoryPhase = .failed(error.localizedDescription)
            }
        }
    }

    func loadBranches(
        token: String,
        owner: String,
        repo: String,
        force: Bool = false
    ) {
        let normalizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedOwner = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRepo = repo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedToken.isEmpty,
              !normalizedOwner.isEmpty,
              !normalizedRepo.isEmpty else {
            clearBranches()
            return
        }

        let requestKey = "\(normalizedToken)\u{0}\(normalizedOwner)\u{0}\(normalizedRepo)"
        if !force,
           branchRequestKey == requestKey,
           case .loaded = branchPhase {
            return
        }

        branchTask?.cancel()
        branchRevision += 1
        let revision = branchRevision
        branchRequestKey = requestKey
        branchPhase = .loading

        branchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let branches = try await GithubOAuth.shared.fetchBranches(
                    token: normalizedToken,
                    owner: normalizedOwner,
                    repo: normalizedRepo
                )
                try Task.checkCancellation()
                guard revision == self.branchRevision,
                      requestKey == self.branchRequestKey else {
                    return
                }
                self.branchPhase = .loaded(branches)
            } catch is CancellationError {
                return
            } catch {
                guard revision == self.branchRevision,
                      requestKey == self.branchRequestKey else {
                    return
                }
                self.branchPhase = .failed(error.localizedDescription)
            }
        }
    }

    func clearBranches() {
        branchTask?.cancel()
        branchTask = nil
        branchRevision += 1
        branchRequestKey = nil
        branchPhase = .idle
    }

    func reset() {
        repositoryTask?.cancel()
        branchTask?.cancel()
        repositoryTask = nil
        branchTask = nil
        repositoryRevision += 1
        branchRevision += 1
        repositoryRequestKey = nil
        branchRequestKey = nil
        repositoryPhase = .idle
        branchPhase = .idle
    }

    func cancel() {
        repositoryTask?.cancel()
        branchTask?.cancel()
        repositoryTask = nil
        branchTask = nil
    }
}
