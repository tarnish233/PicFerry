//
//  ModernHostPreferencesView.swift
//  GitPic
//
//  Single-page GitHub image-host workspace.
//

import SwiftUI

struct ModernHostPreferencesView: View {
    @Bindable var model: HostPreferencesModel

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if let host = model.selectedHost {
                HostConfigurationView(model: model, host: host)
                    .id("\(host.id)-\(model.reloadRevision)")
            } else {
                ContentUnavailableView(
                    "No Host".localized,
                    systemImage: "externaldrive.badge.questionmark"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()

            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Unable to save host configuration".localized, isPresented: $model.showsSaveError) {
        } message: {
            Text(model.saveErrorMessage)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: HostPreferencesMetrics.headerSpacing) {
            Text("Image Host".localized)
                .font(.title2)
                .bold()

            Text("Sign in with GitHub, choose a repository, and GitPic uploads there.".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, PreferencesStyleMetrics.rowHorizontalInset)
        .padding(.horizontal, HostPreferencesMetrics.pageInset)
        .padding(.vertical, HostPreferencesMetrics.headerVerticalInset)
    }

    private var footer: some View {
        HStack(spacing: HostPreferencesMetrics.controlSpacing) {
            Button("Test configuration".localized, systemImage: "checkmark.circle", action: model.validateSelectedHost)

            Spacer()

            Button("Reset".localized, action: model.reload)
                .disabled(!model.hasChanges)

            Button("Save".localized, action: model.save)
                .buttonStyle(.glassProminent)
                .disabled(!model.hasChanges)
        }
        .padding(.horizontal, HostPreferencesMetrics.pageInset)
        .padding(.vertical, HostPreferencesMetrics.footerVerticalInset)
    }
}
