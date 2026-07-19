//
//  GithubOAuth.swift
//  GitPic
//
//  GitHub 登录（OAuth Device Flow）：无需 client_secret，适合桌面/沙盒 App，
//  与 gh CLI 采用的机制一致。用户在 App 内点“登录”，浏览器授权后自动拿到
//  token 并存入钥匙串。
//  GitHub sign-in via OAuth Device Flow: no client_secret needed, suitable for
//  a sandboxed desktop app, the same mechanism the gh CLI uses.
//

import Foundation
import Alamofire
import SwiftyJSON

/// 设备授权码信息 / The device-authorization payload shown to the user.
struct GithubDeviceCode: Sendable {
    /// 展示给用户、在浏览器输入的一次性码 / One-time code the user types in the browser.
    let userCode: String
    /// 用户授权页地址 / Where the user authorizes (e.g. https://github.com/login/device).
    let verificationURI: URL
    /// 轮询用的设备码 / Device code used for polling (not shown to the user).
    let deviceCode: String
    /// 轮询间隔（秒）/ Minimum seconds between poll attempts.
    let interval: Int
    /// 有效期（秒）/ Seconds until the code expires.
    let expiresIn: Int
}

/// 一个仓库（用于下拉选择）/ A repository (for the picker).
struct GithubRepo: Sendable, Identifiable {
    let id: Int64
    let name: String
    let owner: String
    let fullName: String
    let defaultBranch: String
    let isPrivate: Bool
    let isArchived: Bool
    let canPush: Bool
}

/// 登录过程中的错误 / Errors surfaced during sign-in.
enum GithubOAuthError: LocalizedError, Sendable {
    /// 未配置 client_id / No OAuth App client_id compiled in.
    case notConfigured
    /// 用户在浏览器拒绝了授权 / The user denied the authorization.
    case accessDenied
    /// 授权码已过期（用户太久没操作）/ The device code expired before authorization.
    case expired
    /// 网络或其它错误 / Network or other failure.
    case network(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "GitHub sign-in is not configured in this build.".localized
        case .accessDenied:
            return "Authorization was denied.".localized
        case .expired:
            return "The sign-in code expired. Please try again.".localized
        case .network(let message):
            return message
        }
    }
}

@MainActor
final class GithubOAuth {
    static let shared = GithubOAuth()

    /// OAuth App 的 client_id（Device Flow 只需公开的 client_id，无需 secret）。
    /// 在 GitHub → Settings → Developer settings → OAuth Apps 创建，勾选
    /// “Enable Device Flow”，把 Client ID 填到这里。为空时登录功能会被禁用。
    /// The OAuth App client_id (Device Flow needs only the public client_id).
    static let clientID = "Ov23li3tlwmAjVMW7HqQ"

    /// 申请的权限：需要写入仓库内容用于图床上传（含私有仓库）。
    /// Scope: needs to write repository contents for image uploads (incl. private repos).
    private static let scope = "repo"

    /// 是否已在本 build 中配置 client_id / Whether a client_id is compiled in.
    static var isConfigured: Bool { !clientID.isEmpty }

    private init() {}

    // MARK: - Step 1: 申请设备码 / Request a device code

    func requestDeviceCode() async throws -> GithubDeviceCode {
        guard Self.isConfigured else { throw GithubOAuthError.notConfigured }

        let parameters: [String: String] = [
            "client_id": Self.clientID,
            "scope": Self.scope
        ]
        let json = try await postForm("https://github.com/login/device/code", parameters: parameters)
        try Task.checkCancellation()

        guard let deviceCode = json["device_code"].string,
              let userCode = json["user_code"].string,
              let verificationString = json["verification_uri"].string,
              let verificationURI = URL(string: verificationString) else {
            throw GithubOAuthError.network(Self.apiError(from: json))
        }

        return GithubDeviceCode(
            userCode: userCode,
            verificationURI: verificationURI,
            deviceCode: deviceCode,
            interval: json["interval"].int ?? 5,
            expiresIn: json["expires_in"].int ?? 900
        )
    }

    // MARK: - Step 2: 轮询直到用户授权 / Poll until the user authorizes

    /// 轮询换取 access token；期间用户需在浏览器完成授权。可被 Task 取消。
    /// Polls for the access token while the user authorizes in the browser. Cancellable.
    func pollForAccessToken(_ device: GithubDeviceCode) async throws -> String {
        guard Self.isConfigured else { throw GithubOAuthError.notConfigured }

        var interval = max(device.interval, 1)
        let deadline = Date.now.addingTimeInterval(TimeInterval(device.expiresIn))

        while Date.now < deadline {
            try await Task.sleep(for: .seconds(interval))
            try Task.checkCancellation()

            let parameters: [String: String] = [
                "client_id": Self.clientID,
                "device_code": device.deviceCode,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
            ]
            let json = try await postForm("https://github.com/login/oauth/access_token", parameters: parameters)
            try Task.checkCancellation()

            if let token = json["access_token"].string, !token.isEmpty {
                return token
            }

            switch json["error"].string {
            case "authorization_pending":
                continue // 用户还没授权，继续等 / user hasn't authorized yet
            case "slow_down":
                interval += 5 // GitHub 要求放慢轮询 / back off as requested
            case "access_denied":
                throw GithubOAuthError.accessDenied
            case "expired_token":
                throw GithubOAuthError.expired
            default:
                throw GithubOAuthError.network(Self.apiError(from: json))
            }
        }

        throw GithubOAuthError.expired
    }

    // MARK: - Step 3: 用 token 读取登录名（用于自动填 Owner）/ Resolve the login for auto-filling Owner

    func fetchLogin(token: String) async throws -> String? {
        let data = try await authorizedGet("https://api.github.com/user", token: token)
        try Task.checkCancellation()
        return JSON(data)["login"].string
    }

    // MARK: - 列出账号下的仓库（用于下拉选择）/ List the account's repositories

    /// 拉取当前 token 可写入的仓库，自动翻页 / Fetches repositories writable by the token, paging automatically.
    func fetchRepositories(token: String) async throws -> [GithubRepo] {
        var repos: [GithubRepo] = []
        var page = 1
        let maxPages = 10 // 兜底：最多 1000 个，防止无限翻页 / cap at 1000 to avoid runaway paging

        while page <= maxPages {
            let url = "https://api.github.com/user/repos?per_page=100&sort=full_name&page=\(page)"
            let data = try await authorizedGet(url, token: token)
            try Task.checkCancellation()
            let items = JSON(data).array ?? []
            if items.isEmpty { break }
            for item in items {
                let id = item["id"].int64Value
                let name = item["name"].stringValue
                let owner = item["owner"]["login"].stringValue
                let fullName = item["full_name"].stringValue
                let defaultBranch = item["default_branch"].stringValue
                let isArchived = item["archived"].boolValue
                let canPush = item["permissions"]["push"].boolValue
                guard id != 0,
                      !name.isEmpty,
                      !owner.isEmpty,
                      !fullName.isEmpty,
                      !isArchived,
                      canPush else {
                    continue
                }
                repos.append(GithubRepo(
                    id: id,
                    name: name,
                    owner: owner,
                    fullName: fullName,
                    defaultBranch: defaultBranch,
                    isPrivate: item["private"].boolValue,
                    isArchived: isArchived,
                    canPush: canPush
                ))
            }
            if items.count < 100 { break }
            page += 1
        }
        return repos
    }

    // MARK: - 列出仓库的分支（用于下拉选择）/ List a repository's branches

    /// 拉取指定仓库的分支列表，自动翻页 / Fetches branches of a repo, paging automatically.
    func fetchBranches(token: String, owner: String, repo: String) async throws -> [String] {
        guard !owner.isEmpty, !repo.isEmpty else { return [] }
        var branches: [String] = []
        var page = 1
        let maxPages = 10

        while page <= maxPages {
            let url = "https://api.github.com/repos/\(owner)/\(repo)/branches?per_page=100&page=\(page)"
            let data = try await authorizedGet(url, token: token)
            try Task.checkCancellation()
            let items = JSON(data).array ?? []
            if items.isEmpty { break }
            for item in items {
                let name = item["name"].stringValue
                if !name.isEmpty { branches.append(name) }
            }
            if items.count < 100 { break }
            page += 1
        }
        return branches
    }

    // MARK: - Helpers

    /// 带 token 的 GET，返回原始数据 / Authorized GET returning raw data.
    private func authorizedGet(_ url: String, token: String) async throws -> Data {
        var headers = HTTPHeaders()
        headers.add(HTTPHeader.authorization(bearerToken: token))
        headers.add(HTTPHeader.accept("application/vnd.github+json"))
        headers.add(HTTPHeader.defaultUserAgent)
        headers.add(name: "X-GitHub-Api-Version", value: "2022-11-28")

        return try await withCheckedThrowingContinuation { continuation in
            AF.request(url, method: .get, headers: headers)
                .validate(statusCode: 200 ..< 300)
                .responseData { response in
                    switch response.result {
                    case .success(let value):
                        continuation.resume(returning: value)
                    case .failure(let error):
                        continuation.resume(throwing: GithubOAuthError.network(error.localizedDescription))
                    }
                }
        }
    }

    /// 发送表单编码 POST，返回 JSON（GitHub 在 Accept: json 时以 JSON 回错误）。
    /// Sends a form-encoded POST and returns JSON (GitHub returns JSON errors when Accept is json).
    private func postForm(_ url: String, parameters: [String: String]) async throws -> JSON {
        var headers = HTTPHeaders()
        headers.add(HTTPHeader.accept("application/json"))
        headers.add(HTTPHeader.defaultUserAgent)

        let data: Data = try await withCheckedThrowingContinuation { continuation in
            AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.httpBody, headers: headers)
                .validate(statusCode: 200 ..< 300)
                .responseData { response in
                    switch response.result {
                    case .success(let value):
                        continuation.resume(returning: value)
                    case .failure(let error):
                        let message = response.data.flatMap { JSON($0)["error_description"].string }
                            ?? error.localizedDescription
                        continuation.resume(throwing: GithubOAuthError.network(message))
                    }
                }
        }
        return JSON(data)
    }

    private static func apiError(from json: JSON) -> String {
        json["error_description"].string
            ?? json["error"].string
            ?? "Could not complete GitHub sign-in.".localized
    }
}
