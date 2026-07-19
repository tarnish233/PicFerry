//
//  HostPreferencesModel.swift
//  GitPic
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

    func completeSignIn(token: String, login: String?, hostID: String) -> Bool {
        let normalizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLogin = login?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !normalizedToken.isEmpty,
              persistAccount(
                token: normalizedToken,
                owner: normalizedLogin,
                repo: "",
                branch: "",
                hostID: hostID
              ) else {
            return false
        }

        updateCurrentAccount(
            token: normalizedToken,
            owner: normalizedLogin,
            repo: "",
            branch: "",
            hostID: hostID
        )
        return true
    }

    func signOut(hostID: String) -> Bool {
        guard persistAccount(
            token: "",
            owner: "",
            repo: "",
            branch: "",
            hostID: hostID
        ) else {
            saveErrorMessage = "Unable to save credentials to Keychain".localized
            showsSaveError = true
            return false
        }

        updateCurrentAccount(
            token: "",
            owner: "",
            repo: "",
            branch: "",
            hostID: hostID
        )
        return true
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
        let activeHost = hosts.first(where: { $0.id == storedDefaultID }) ?? hosts[0]
        defaultHostID = activeHost.id
        selectedID = activeHost.id
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

    private func persistAccount(
        token: String,
        owner: String,
        repo: String,
        branch: String,
        hostID: String
    ) -> Bool {
        guard let currentHost = hosts.first(where: { $0.id == hostID }) else {
            return false
        }

        var storedHosts = ConfigManager.shared.getHostItems()
        let storedHost: Host
        if let existingHost = storedHosts.first(where: { $0.id == hostID }) {
            storedHost = existingHost
        } else if let newHost = Host.deserialize(str: currentHost.serialize()) {
            storedHost = newHost
            storedHosts.append(newHost)
        } else {
            return false
        }

        guard let config = storedHost.data else { return false }
        let previousToken = config.value(forKey: "token") as? String ?? ""
        let previousOwner = config.value(forKey: "owner") as? String ?? ""
        let previousRepo = config.value(forKey: "repo") as? String ?? ""
        let previousBranch = config.value(forKey: "branch") as? String ?? ""

        config.setValue(token, forKey: "token")
        config.setValue(owner, forKey: "owner")
        config.setValue(repo, forKey: "repo")
        config.setValue(branch, forKey: "branch")

        guard ConfigManager.shared.setHostItems(items: storedHosts) else {
            config.setValue(previousToken, forKey: "token")
            config.setValue(previousOwner, forKey: "owner")
            config.setValue(previousRepo, forKey: "repo")
            config.setValue(previousBranch, forKey: "branch")
            _ = HostCredentialStore.save(storedHost)
            return false
        }
        return true
    }

    private func updateCurrentAccount(
        token: String,
        owner: String,
        repo: String,
        branch: String,
        hostID: String
    ) {
        guard let config = hosts.first(where: { $0.id == hostID })?.data else {
            return
        }
        config.setValue(token, forKey: "token")
        config.setValue(owner, forKey: "owner")
        config.setValue(repo, forKey: "repo")
        config.setValue(branch, forKey: "branch")
    }

    private func markChanged() {
        hasChanges = true
    }
}
