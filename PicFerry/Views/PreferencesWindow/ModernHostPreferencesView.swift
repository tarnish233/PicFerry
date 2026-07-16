//
//  ModernHostPreferencesView.swift
//  PicFerry
//
//  Native macOS 26 host preferences.
//

import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class HostPreferencesModel {
    private(set) var hosts: [Host] = []
    var selectedID: String?
    private(set) var hasChanges = false
    var showsSaveError = false
    private(set) var saveErrorMessage = ""

    init() {
        reload()
    }

    var selectedHost: Host? {
        hosts.first { $0.id == selectedID }
    }

    func add(_ type: HostType) {
        let host = Host(type, data: HostConfig.create(type: type))
        hosts.append(host)
        selectedID = host.id
        markChanged()
    }

    func removeSelectedHost() {
        guard hosts.count > 1,
              let index = hosts.firstIndex(where: { $0.id == selectedID }) else {
            return
        }
        hosts.remove(at: index)
        selectedID = hosts[min(index, hosts.count - 1)].id
        markChanged()
    }

    func updateName(_ value: String) {
        guard let host = selectedHost else {
            return
        }
        host.name = value
        markChanged()
    }

    func stringValue(for key: String) -> String {
        selectedHost?.data?.value(forKey: key) as? String ?? ""
    }

    func updateString(_ value: String, for key: String) {
        selectedHost?.data?.setValue(value, forKey: key)
        markChanged()
    }

    func save() {
        for host in hosts {
            guard let config = host.data else {
                continue
            }
            // Trim text/secure fields on save so pasted tokens or keys with
            // stray whitespace/newlines don't break uploads. Multiline JSON
            // fields (bodys/headers) are left untouched.
            for field in HostField.fields(for: host) {
                switch field.kind {
                case .text, .secure:
                    if let value = config.value(forKey: field.key) as? String {
                        config.setValue(value.trim(), forKey: field.key)
                    }
                }
            }
            config.fixPrefixAndSuffix()
        }
        guard ConfigManager.shared.setHostItems(items: hosts) else {
            saveErrorMessage = "Unable to save credentials to Keychain".localized
            showsSaveError = true
            return
        }
        hasChanges = false
    }

    func reload() {
        hosts = ConfigManager.shared.getHostItems()
        if hosts.isEmpty {
            hosts = [Host.getDefaultHost()]
        }
        selectedID = hosts.first?.id
        hasChanges = false
    }

    func validateSelectedHost() {
        guard let host = selectedHost,
              let data = NSApp.applicationIconImage.pngData else {
            return
        }
        BaseUploader.upload(data: data, host)
    }

    func openHelp() {
        guard let type = selectedHost?.type,
              let url = Self.helpURL(for: type) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func markChanged() {
        hasChanges = true
    }

    private static func helpURL(for type: HostType) -> URL? {
        switch type {
        case .gitee:
            return URL(string: "https://gitee.com/profile/personal_access_tokens")
        case .github:
            return URL(string: "https://github.com/settings/tokens")
        }
    }
}

struct ModernHostPreferencesView: View {
    @Bindable var model: HostPreferencesModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Host".localized)
                .font(.title2)
                .bold()

            HStack(alignment: .top, spacing: 12) {
                hostList
                    .frame(width: 190)

                if let host = model.selectedHost {
                    HostEditorView(model: model, host: host)
                        .id(host.id)
                } else {
                    ContentUnavailableView(
                        "No Host".localized,
                        systemImage: "externaldrive.badge.questionmark"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Unable to save host configuration".localized, isPresented: $model.showsSaveError) {
        } message: {
            Text(model.saveErrorMessage)
        }
    }

    private var hostList: some View {
        VStack(spacing: 0) {
            List(model.hosts, selection: $model.selectedID) { host in
                Label {
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
                } icon: {
                    Image(nsImage: Host.getIconByType(type: host.type))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                }
                .padding(.vertical, 3)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Divider()

            HStack(spacing: 2) {
                Menu {
                    ForEach(HostType.allCases, id: \.self) { type in
                        Button(type.name) { model.add(type) }
                    }
                } label: {
                    Label("Add Host".localized, systemImage: "plus")
                }
                .menuIndicator(.hidden)
                .frame(width: 34, height: 24)
                .help("Add Host".localized)

                Button("Remove Host".localized, systemImage: "minus", action: model.removeSelectedHost)
                    .frame(width: 34, height: 24)
                    .disabled(model.hosts.count < 2)
                    .help("Remove Host".localized)

                Spacer()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(
            Color(nsColor: .controlBackgroundColor).opacity(0.72),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.25), lineWidth: 1)
        }
    }
}

private struct HostEditorView: View {
    let model: HostPreferencesModel
    let host: Host

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard
                fieldCard
                actionBar
            }
            .padding(.trailing, 3)
            .padding(.bottom, 6)
        }
        .scrollIndicators(.automatic)
    }

    private var headerCard: some View {
        VStack(spacing: 0) {
            HostEditorRow(title: "Name".localized) {
                TextField("Name".localized, text: Binding(
                    get: { host.name },
                    set: { model.updateName($0) }
                ))
                .frame(maxWidth: 320)
            }
            Divider().padding(.leading, 16)
            HostEditorRow(title: "Type".localized) {
                HStack(spacing: 8) {
                    Image(nsImage: Host.getIconByType(type: host.type))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                    Text(host.type.name)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .hostCardStyle()
    }

    private var fieldCard: some View {
        VStack(spacing: 0) {
            ForEach(fields.enumerated(), id: \.element.key) { index, field in
                if index > 0 {
                    Divider().padding(.leading, 16)
                }
                HostFieldRow(model: model, field: field)
            }
        }
        .hostCardStyle()
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button(action: model.openHelp) {
                Label("Help".localized, systemImage: "questionmark.circle")
            }
            Button(action: model.validateSelectedHost) {
                Label("Validate".localized, systemImage: "checkmark.circle")
            }

            Spacer()

            Button("Reset".localized, action: model.reload)
                .disabled(!model.hasChanges)
            Button("Save".localized, action: model.save)
                .buttonStyle(.glassProminent)
                .disabled(!model.hasChanges)
        }
        .padding(.top, 2)
    }

    private var fields: [HostField] {
        HostField.fields(for: host)
    }
}

private struct HostEditorRow<Control: View>: View {
    let title: String
    let control: Control

    init(title: String, @ViewBuilder control: () -> Control) {
        self.title = title
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 18) {
            Text(title)
                .font(.body)
                .frame(width: 82, alignment: .leading)
            control
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(minHeight: 44)
    }
}

private struct HostFieldRow: View {
    let model: HostPreferencesModel
    let field: HostField
    @State private var revealsSecret = false

    var body: some View {
        HostEditorRow(title: field.title) {
            switch field.kind {
            case .text:
                TextField("", text: stringBinding)
            case .secure:
                HStack(spacing: 6) {
                    if revealsSecret {
                        TextField("", text: stringBinding)
                    } else {
                        SecureField("", text: stringBinding)
                    }
                    Button(
                        revealsSecret ? "Hide token".localized : "Show token".localized,
                        systemImage: revealsSecret ? "eye.slash" : "eye",
                        action: toggleSecretVisibility
                    )
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    private func toggleSecretVisibility() {
        revealsSecret.toggle()
    }

    private var stringBinding: Binding<String> {
        Binding(
            get: { model.stringValue(for: field.key) },
            set: { model.updateString($0, for: field.key) }
        )
    }

}

private struct HostField {
    enum Kind {
        case text
        case secure
    }

    let key: String
    let title: String
    let kind: Kind

    static func fields(for host: Host) -> [HostField] {
        guard let config = host.data else {
            return []
        }

        let keys: [String]
        switch host.type {
        case .github, .gitee:
            keys = ["owner", "repo", "branch", "token", "domain", "saveKeyPath"]
        }

        return keys.map { key in
            HostField(
                key: key,
                title: config.displayName(key: key),
                kind: kind(for: key)
            )
        }
    }

    private static func kind(for key: String) -> Kind {
        switch key {
        case "token":
            return .secure
        default:
            return .text
        }
    }
}

private extension View {
    func hostCardStyle() -> some View {
        background(
            Color(nsColor: .controlBackgroundColor).opacity(0.72),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.25), lineWidth: 1)
        }
    }
}
