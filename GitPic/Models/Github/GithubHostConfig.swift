//
//  GithubHostConfig.swift
//  GitPic
//
//  Created by Svend Jin on 2019/6/29.
//  Copyright © 2019 Svend Jin. All rights reserved.
//

import Cocoa
import SwiftyJSON

@objcMembers
class GithubHostConfig: HostConfig {
    dynamic var owner: String = ""
    dynamic var repo: String = ""
    dynamic var branch: String = "main"
    dynamic var token: String = ""
    dynamic var domain: String = ""
    dynamic var saveKeyPath: String?
    
    override func displayName(key: String) -> String {
        switch key {
        case "owner":
            return "Owner".localized
        case "repo":
            return "Repo".localized
        case "branch":
            return "Branch".localized
        case "token":
            return "Token".localized
        case "domain":
            return "Domain".localized
        case "saveKeyPath":
            return "Save Key".localized
        default:
            return ""
        }
    }
    
    override var secretKeys: [String] {
        ["token"]
    }

    override func serialize(includeSecrets: Bool) -> String {
        var dict = Dictionary<String, Any>()
        dict["owner"] = self.owner
        dict["repo"] = self.repo
        dict["branch"] = self.branch
        if includeSecrets {
            dict["token"] = self.token
        }
        dict["domain"] = self.domain
        dict["saveKeyPath"] = self.saveKeyPath
        
        return JSON(dict).rawString() ?? "{}"
    }
    
    static func deserialize(str: String?) -> GithubHostConfig? {
        let config = GithubHostConfig()
        guard let str = str else {
            return config
        }
        guard let data = str.data(using: .utf8), let json = try? JSON(data: data) else {
            return nil
        }
        config.owner = json["owner"].stringValue
        config.repo = json["repo"].stringValue
        config.branch = json["branch"].stringValue
        config.token = json["token"].stringValue
        config.domain = json["domain"].stringValue
        config.saveKeyPath = json["saveKeyPath"].string
        
        return config
    }
}
