//
//  GithubUploader.swift
//  GitPic
//
//  Created by Svend Jin on 2019/6/29.
//  Copyright © 2019 Svend Jin. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

final class GithubUploader: BaseUploader, @unchecked Sendable {
    static let shared = GithubUploader()
    static let fileExtensions: [String] = []
    
    @MainActor
    func _upload(_ fileUrl: URL?, fileData: Data?, host: Host) {
        guard let config = host.data as? GithubHostConfig else {
            super.faild(errorMsg: "There is a problem with the map bed configuration, please check!".localized)
            return
        }
        
        super.start()
        
        let owner = config.owner
        let repo = config.repo
        let branch = config.branch
        let token = config.token
        let domain = config.domain
        
        let saveKeyPath = config.saveKeyPath
        let hostID = host.id
        
        guard let configuration = BaseUploaderUtil.getSaveConfigurationWithB64(fileUrl, fileData, saveKeyPath) else {
            super.faild(errorMsg: "Invalid file")
            return
        }
        guard let fileBase64 = configuration["fileBase64"] as? String,
              let saveKey = configuration["saveKey"] as? String else {
            super.faild(errorMsg: "Invalid file".localized)
            return
        }
        let retData = configuration["retData"] as? Data
        
        
        let url = GithubUtil.getUrl(owner: owner, repo: repo, filePath: saveKey)

        let parameters = GithubUtil.getRequestParameters(branch: branch, b64Content: fileBase64)
        
        var headers = HTTPHeaders()
        headers.add(HTTPHeader.authorization("Bearer \(token)"))
        headers.add(HTTPHeader.accept("application/vnd.github+json"))
        headers.add(HTTPHeader.contentType("application/json"))
        headers.add(HTTPHeader.defaultUserAgent)
        headers.add(name: "X-GitHub-Api-Version", value: "2026-03-10")
        
        AF.request(
            url,
            method: .put,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: headers
        )
            .validate(statusCode: 200..<300)
            .responseData(completionHandler: { response -> Void in
                switch response.result {
                case .success(let value):
                    let json = JSON(value)
                    if let errorMessage = json["message"].string {
                        super.faild(responseData: response.data, errorMsg: errorMessage)
                        return
                    }
                    if domain.isEmpty {
                        super.completed(url: json["content"]["download_url"].stringValue, retData, fileUrl, hostID: hostID)
                    } else {
                        super.completed(url: BaseUploaderUtil.makePublicURL(domain: domain, path: saveKey), retData, fileUrl, hostID: hostID)
                    }
                case .failure(let error):
                    var errorMsg = error.localizedDescription
                    if let data = response.data {
                        let json = JSON(data)
                        if let apiMessage = json["message"].string,
                           !apiMessage.isEmpty {
                            errorMsg = apiMessage
                        }
                    }
                    super.faild(responseData: response.data, errorMsg: errorMsg)
                }
            })
        
    }
    
    @MainActor
    func upload(_ fileUrl: URL, host: Host) {
        self._upload(fileUrl, fileData: nil, host: host)
    }
    
    @MainActor
    func upload(_ fileData: Data, host: Host) {
        self._upload(nil, fileData: fileData, host: host)
    }

}
