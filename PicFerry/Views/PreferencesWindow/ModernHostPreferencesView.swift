//
//  ModernHostPreferencesView.swift
//  PicFerry
//
//  Image-host management workspace.
//

import SwiftUI

struct ModernHostPreferencesView: View {
    @Bindable var model: HostPreferencesModel
    @State private var showsProviderPicker = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header

                Divider()

                HStack(spacing: 0) {
                    HostSidebarView(model: model, addAction: showProviderPicker)

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
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                footer
            }

            if showsProviderPicker {
                providerPicker
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Unable to save host configuration".localized, isPresented: $model.showsSaveError) {
        } message: {
            Text(model.saveErrorMessage)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: HostPreferencesMetrics.headerSpacing) {
            Text("Image Hosts".localized)
                .font(.title2)
                .bold()

            Text("Manage image upload services. The default service is used for new uploads.".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private var providerPicker: some View {
        ZStack {
            Color.black.opacity(0.14)
                .ignoresSafeArea()
                .onTapGesture(perform: dismissProviderPicker)
                .accessibilityHidden(true)

            HostProviderPickerView(
                addAction: { type in
                    model.add(type)
                    dismissProviderPicker()
                },
                cancelAction: dismissProviderPicker
            )
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.2), radius: 24, y: 10)
            .onExitCommand(perform: dismissProviderPicker)
        }
        .zIndex(1)
    }

    private func showProviderPicker() {
        showsProviderPicker = true
    }

    private func dismissProviderPicker() {
        showsProviderPicker = false
    }
}
