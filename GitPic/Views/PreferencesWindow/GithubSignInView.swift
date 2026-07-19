//
//  GithubSignInView.swift
//  GitPic
//
//  “使用 GitHub 登录”按钮及设备授权码展示 / The "Sign in with GitHub" button
//  and the device-code prompt.
//

import SwiftUI

struct GithubSignInView: View {
    @State private var model: GithubSignInModel

    init(onSignedIn: @escaping (String, String?) -> Bool) {
        _model = State(initialValue: GithubSignInModel(onSignedIn: onSignedIn))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onDisappear(perform: model.cancel)
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle:
            signInButton

        case .starting:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Getting a sign-in code…".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case .awaitingAuthorization(let device):
            awaitingView(device)

        case .success(let login):
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
                Text(successMessage(login))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                signInButton
            }
        }
    }

    private var signInButton: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button("Sign in with GitHub".localized, systemImage: "person.badge.key", action: model.start)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!model.isConfigured)
            if !model.isConfigured {
                Text("GitHub sign-in is not configured in this build.".localized)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func awaitingView(_ device: GithubDeviceCode) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Enter this code in your browser to authorize:".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Text(device.userCode)
                    .font(.system(.title2, design: .monospaced))
                    .bold()
                    .textSelection(.enabled)
                Button("Copy code".localized, systemImage: "doc.on.doc", action: { copyCode(device.userCode) })
                    .labelStyle(.iconOnly)
            }

            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Waiting for authorization…".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button("Open authorization page".localized, action: model.openAuthorizationPage)
                Button("Cancel".localized, role: .cancel, action: model.cancel)
            }
        }
    }

    private func successMessage(_ login: String?) -> String {
        if let login, !login.isEmpty {
            String(format: "Signed in as %@".localized, login)
        } else {
            "Signed in. Token saved to Keychain.".localized
        }
    }

    private func copyCode(_ code: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
    }
}
