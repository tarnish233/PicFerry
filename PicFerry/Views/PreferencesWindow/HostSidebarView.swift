//
//  HostSidebarView.swift
//  PicFerry
//

import SwiftUI

struct HostSidebarView: View {
    @Bindable var model: HostPreferencesModel
    let addAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            List(model.hosts, selection: $model.selectedID) { host in
                row(for: host)
                    .tag(host.id)
                    .contextMenu {
                        Button("Set as Default".localized) {
                            model.setDefault(hostID: host.id)
                        }
                        .disabled(model.isDefault(host))

                        Divider()

                        Button("Remove Host".localized, role: .destructive, action: model.removeSelectedHost)
                            .disabled(!model.canRemoveSelectedHost || model.selectedID != host.id)
                    }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Divider()

            HStack(spacing: 0) {
                Button(action: addAction) {
                    Image(systemName: "plus")
                        .font(.body.weight(.medium))
                        .frame(width: 42, height: 32)
                        .contentShape(.rect)
                }
                .accessibilityLabel("Add Host".localized)
                .help("Add Host".localized)

                Divider()
                    .frame(height: 18)

                Button(action: model.removeSelectedHost) {
                    Image(systemName: "minus")
                        .font(.body.weight(.medium))
                        .frame(width: 42, height: 32)
                        .contentShape(.rect)
                }
                .accessibilityLabel("Remove Host".localized)
                .disabled(!model.canRemoveSelectedHost)
                .help("Remove Host".localized)
            }
            .buttonStyle(.plain)
            .background(
                Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: HostPreferencesMetrics.sidebarWidth)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private func row(for host: Host) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: Host.getIconByType(type: host.type))
                .resizable()
                .scaledToFit()
                .frame(width: HostPreferencesMetrics.iconSize, height: HostPreferencesMetrics.iconSize)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(host.name)
                    .lineLimit(1)

                if host.name != host.type.name {
                    Text(host.type.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            if model.isDefault(host) {
                Text("Default".localized)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.tint, in: Capsule())
                    .accessibilityLabel("Default image host".localized)
            }
        }
        .frame(minHeight: HostPreferencesMetrics.listRowHeight)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
