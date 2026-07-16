//
//  GithubUtil.swift
//  PicFerry
//
//  Created by Svend Jin on 2019/6/29.
//  Copyright © 2019 Svend Jin. All rights reserved.
//

import Foundation
import Alamofire

enum GithubUtil {
    static func getUrl(owner: String, repo: String, filePath: String) -> String {
        return "https://api.github.com/repos/\(owner)/\(repo)/contents/\(filePath)".urlEncoded()
    }
    
    static func getRequestParameters(branch: String, b64Content: String) -> Parameters {
        var parameters = Parameters()
        parameters["branch"] = branch
        parameters["content"] = b64Content
        parameters["message"] = "⬆ Uploaded by PicFerry\nhttps://github.com/tarnish233/PicFerry"
        return parameters
    }
}
