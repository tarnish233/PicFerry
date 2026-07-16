//
//  HostConfig.swift
//  PicFerry
//
//  Created by Svend Jin on 2019/6/15.
//  Copyright © 2019 Svend Jin. All rights reserved.
//

import Foundation

@objcMembers
class HostConfig: NSObject, Codable {
    override init() {
        super.init()
    }

    // Static

    static func create(type: HostType) -> HostConfig? {
        switch type {
        case .github:
            return GithubHostConfig()
        case .gitee:
            return GiteeHostConfig()
        }
    }

    func displayName(key: String) -> String {
        return ""
    }

    var secretKeys: [String] {
        []
    }

    func secretValue(forKey key: String) -> String? {
        value(forKey: key) as? String
    }

    func setSecretValue(_ value: String, forKey key: String) {
        setValue(value, forKey: key)
    }

    func serialize(includeSecrets: Bool) -> String {
        return ""
    }

    static func deserialize(type: HostType, str: String?) -> HostConfig? {
        var config: HostConfig?
        switch type {
        case .github:
            config = GithubHostConfig.deserialize(str: str)
        case .gitee:
            config = GiteeHostConfig.deserialize(str: str)
        }
        
        config?.fixPrefixAndSuffix()
        return config
    }
    
    func containsKey(key: String) -> Bool {
        let morror = Mirror.init(reflecting: self)
        return morror.children.contains(where: {(label, _ ) -> Bool in
            return label == key
        })
    }
    
    // 修复用户有时候会不注意在 domain 后面多写一个 /
    func fixPrefixAndSuffix() {
        if self.containsKey(key: "saveKeyPath") {
            if var saveKeyPath = self.value(forKey: "saveKeyPath") as? String, saveKeyPath.hasPrefix("/") {
                saveKeyPath.removeFirst()
                self.setValue(saveKeyPath, forKey: "saveKeyPath")
            }
        }
    }

}
