//
//  HostEditorDraft.swift
//  GitPic
//

import Observation

@MainActor
@Observable
final class HostEditorDraft {
    var name: String
    var owner: String
    var repo: String
    var branch: String
    var token: String
    var saveKeyPath: String

    init(host: Host) {
        name = host.name
        owner = Self.value("owner", from: host)
        repo = Self.value("repo", from: host)
        branch = Self.value("branch", from: host)
        token = Self.value("token", from: host)
        saveKeyPath = Self.value("saveKeyPath", from: host)
    }

    private static func value(_ key: String, from host: Host) -> String {
        host.data?.value(forKey: key) as? String ?? ""
    }
}
