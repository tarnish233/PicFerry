//
//  GithubSelectionFieldLabel.swift
//  GitPic
//

import SwiftUI

struct GithubSelectionFieldLabel: View {
    let value: String
    let symbolName: String
    let isPlaceholder: Bool
    let isLoading: Bool

    var body: some View {
        HStack(spacing: HostPreferencesMetrics.controlSpacing) {
            Image(systemName: symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 18)
                .accessibilityHidden(true)

            Text(value)
                .foregroundStyle(isPlaceholder ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: HostPreferencesMetrics.controlSpacing)

            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "chevron.up.chevron.down")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, HostPreferencesMetrics.inputHorizontalInset)
        .frame(minHeight: HostPreferencesMetrics.inputHeight)
        .frame(maxWidth: .infinity)
    }
}

extension View {
    func githubSelectionField() -> some View {
        self
            .frame(minHeight: HostPreferencesMetrics.inputHeight)
            .background(
                Color(nsColor: .textBackgroundColor),
                in: RoundedRectangle(cornerRadius: HostPreferencesMetrics.inputCornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: HostPreferencesMetrics.inputCornerRadius)
                    .stroke(Color.primary.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
            .contentShape(RoundedRectangle(cornerRadius: HostPreferencesMetrics.inputCornerRadius))
    }
}
