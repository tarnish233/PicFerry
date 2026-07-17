//
//  HostPreferencesModel.swift
//  PicFerry
//

import AppKit
import Observation

@MainActor
@Observable
final class HostPreferencesModel {
    private(set) var hosts: [Host] = []
    var selectedID: String?
    private(set) var defaultHostID: String?
    private(set) var hasChanges = false
    private(set) var reloadRevision = 0
    var showsSaveError = false
    private(set) var saveErrorMessage = ""

    init() {
        reload()
    }

    var selectedHost: Host? {
        hosts.first { $0.id == selectedID }
    }

    var canRemoveSelectedHost: Bool {
        hosts.count > 1 && selectedHost != nil
    }

    func add(_ type: HostType) {
        let host = Host(type, data: HostConfig.create(type: type))
        hosts.append(host)
        selectedID = host.id
        markChanged()
    }

    func removeSelectedHost() {
        guard canRemoveSelectedHost,
              let index = hosts.firstIndex(where: { $0.id == selectedID }) else {
            return
        }

        let removedHost = hosts.remove(at: index)
        let nextHost = hosts[min(index, hosts.count - 1)]
        selectedID = nextHost.id
        if defaultHostID == removedHost.id {
            defaultHostID = nextHost.id
        }
        markChanged()
    }

    func setDefault(hostID: String) {
        guard hosts.contains(where: { $0.id == hostID }),
              defaultHostID != hostID else {
            return
        }
        defaultHostID = hostID
        markChanged()
    }

    func isDefault(_ host: Host) -> Bool {
        host.id == defaultHostID
    }

    func updateName(_ value: String, hostID: String) {
        guard let host = hosts.first(where: { $0.id == hostID }),
              host.name != value else {
            return
        }
        host.name = value
        markChanged()
    }

    func updateString(_ value: String, for key: String, hostID: String) {
        guard let config = hosts.first(where: { $0.id == hostID })?.data,
              (config.value(forKey: key) as? String ?? "") != value else {
            return
        }
        config.setValue(value, forKey: key)
        markChanged()
    }

    func save() {
        normalizeHosts()

        let previousDefaultHostID = Defaults[.defaultHostId]
        Defaults[.defaultHostId] = defaultHostID
        guard ConfigManager.shared.setHostItems(items: hosts) else {
            Defaults[.defaultHostId] = previousDefaultHostID
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

        let storedDefaultID = Defaults[.defaultHostId]
        defaultHostID = hosts.contains(where: { $0.id == storedDefaultID })
            ? storedDefaultID
            : hosts.first?.id
        selectedID = defaultHostID
        hasChanges = false
        reloadRevision += 1
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

    private func normalizeHosts() {
        let keys = ["owner", "repo", "branch", "token", "domain", "saveKeyPath"]
        for host in hosts {
            host.name = host.name.trim().isEmpty ? host.type.name : host.name.trim()
            guard let config = host.data else {
                continue
            }
            for key in keys {
                guard let value = config.value(forKey: key) as? String else {
                    continue
                }
                config.setValue(value.trim(), forKey: key)
            }
            config.fixPrefixAndSuffix()
        }
    }

    private func markChanged() {
        hasChanges = true
    }

    private static func helpURL(for type: HostType) -> URL? {
        switch type {
        case .gitee:
            URL(string: "https://gitee.com/profile/personal_access_tokens")
        case .github:
            URL(string: "https://github.com/settings/tokens")
        }
    }
}
