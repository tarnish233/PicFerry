//
//  HostCredentialStore.swift
//  GitPic
//
//  Stores provider credentials outside UserDefaults.
//

import Foundation
import Security

@MainActor
enum HostCredentialStore {
    private static var service: String {
        "\(Bundle.main.bundleIdentifier ?? "com.tarnish233.gitpic").host-credentials"
    }

    static func hydrate(_ host: Host) {
        guard let config = host.data else {
            return
        }

        for key in config.secretKeys {
            guard let value = read(account: account(for: host, key: key)) else {
                continue
            }
            config.setSecretValue(value, forKey: key)
        }
    }

    @discardableResult
    static func save(_ host: Host, removesEmptyValues: Bool = true) -> Bool {
        guard let config = host.data else {
            return true
        }

        return config.secretKeys.allSatisfy { key in
            let account = account(for: host, key: key)
            let value = config.secretValue(forKey: key)?.trim() ?? ""
            if value.isEmpty {
                return removesEmptyValues ? delete(account: account) : true
            }
            return write(value, account: account)
        }
    }

    static func remove(_ host: Host) {
        guard let config = host.data else {
            return
        }
        for key in config.secretKeys {
            delete(account: account(for: host, key: key))
        }
    }

    private static func account(for host: Host, key: String) -> String {
        "\(host.id).\(host.type.rawValue).\(key)"
    }

    private static func read(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            logFailure(operation: "read", status: status)
            return nil
        }
        return value
    }

    private static func write(_ value: String, account: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }

        let query = baseQuery(account: account)
        let update = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }
        guard updateStatus == errSecItemNotFound else {
            logFailure(operation: "update", status: updateStatus)
            return false
        }

        var newItem = query
        newItem[kSecValueData as String] = data
        newItem[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let addStatus = SecItemAdd(newItem as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            logFailure(operation: "add", status: addStatus)
            return false
        }
        return true
    }

    @discardableResult
    private static func delete(account: String) -> Bool {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logFailure(operation: "delete", status: status)
            return false
        }
        return true
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private static func logFailure(operation: String, status: OSStatus) {
        let detail = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
        Logger.shared.error("Keychain \(operation) failed: \(detail)")
    }
}
