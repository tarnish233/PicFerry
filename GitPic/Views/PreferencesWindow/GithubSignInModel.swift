//
//  GithubSignInModel.swift
//  GitPic
//
//  驱动 GitHub 设备登录的 UI 状态机 / Drives the GitHub device-flow sign-in UI.
//

import AppKit
import Observation

@MainActor
@Observable
final class GithubSignInModel {
    enum Phase {
        case idle
        case starting
        case awaitingAuthorization(GithubDeviceCode)
        case success(login: String?)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private var task: Task<Void, Never>?
    private var revision = 0

    /// 登录成功后的回调：(token, login) / Persists the account and returns whether it succeeded.
    private let onSignedIn: (String, String?) -> Bool

    var isConfigured: Bool { GithubOAuth.isConfigured }

    init(onSignedIn: @escaping (String, String?) -> Bool) {
        self.onSignedIn = onSignedIn
    }

    func start() {
        task?.cancel()
        revision += 1
        let currentRevision = revision
        phase = .starting
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let device = try await GithubOAuth.shared.requestDeviceCode()
                guard currentRevision == self.revision else { return }
                self.phase = .awaitingAuthorization(device)
                // 自动打开授权页 / open the authorization page for the user
                NSWorkspace.shared.open(device.verificationURI)

                let token = try await GithubOAuth.shared.pollForAccessToken(device)
                let login: String?
                do {
                    login = try await GithubOAuth.shared.fetchLogin(token: token)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    login = nil
                }
                try Task.checkCancellation()
                guard currentRevision == self.revision else { return }
                guard self.onSignedIn(token, login) else {
                    throw GithubOAuthError.network("Unable to save credentials to Keychain".localized)
                }
                self.phase = .success(login: login)
            } catch is CancellationError {
                guard currentRevision == self.revision else { return }
                self.phase = .idle
            } catch {
                guard currentRevision == self.revision else { return }
                self.phase = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        revision += 1
        phase = .idle
    }

    func openAuthorizationPage() {
        guard case .awaitingAuthorization(let device) = phase else { return }
        NSWorkspace.shared.open(device.verificationURI)
    }
}
