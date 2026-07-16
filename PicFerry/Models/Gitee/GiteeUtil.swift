//
//  GiteeUtil.swift
//  PicFerry
//
//  Created by Svend Jin on 2019/6/29.
//  Copyright © 2019 Svend Jin. All rights reserved.
//

import Foundation
import Alamofire

enum GiteeUtil {
    static func getUrl(owner: String, repo: String, filePath: String) -> String {
        return "https://gitee.com/api/v5/repos/\(owner)/\(repo)/contents/\(filePath)".urlEncoded()
    }
    
    static func getRequestParameters(token: String, branch: String, b64Content: String) -> Parameters {
        var parameters = Parameters()
        parameters["access_token"] = token
        parameters["branch"] = branch
        parameters["content"] = b64Content
        parameters["message"] = "⬆ Uploaded by PicFerry\nhttps://github.com/tarnish233/PicFerry"
        return parameters
    }
}
