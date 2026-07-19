//
//  UpdateChecker.swift
//  GitPic
//
//  检查更新：从 GitHub Releases 获取最新版本并与当前版本比较。
//  Check for updates: fetch the latest release from GitHub and compare it
//  against the running version.
//

import Foundation
import Alamofire
import SwiftyJSON

/// 一个已发布的版本 / A published release.
struct AppRelease: Sendable {
    /// 归一化后的版本号，例如 "2.0.2" / Normalized version, e.g. "2.0.2".
    let version: String
    /// 原始 tag，例如 "v2.0.2" / Raw tag, e.g. "v2.0.2".
    let tagName: String
    /// Release 页面地址 / Release page URL.
    let htmlURL: URL
    /// Release 说明（可能为空）/ Release notes (may be empty).
    let releaseNotes: String?
}

/// 检查更新的结果 / The outcome of an update check.
enum UpdateCheckResult: Sendable {
    /// 已是最新版本，附带当前版本号 / Already up to date, carries the current version.
    case upToDate(current: String)
    /// 有可用更新 / A newer release is available.
    case updateAvailable(AppRelease)
}

/// 检查更新时可能出现的错误 / Errors surfaced while checking for updates.
enum UpdateCheckError: LocalizedError, Sendable {
    case network(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .network(let message):
            return message
        case .invalidResponse:
            return "Could not read the latest release information.".localized
        }
    }
}

@MainActor
final class UpdateChecker {
    static let shared = UpdateChecker()

    /// GitHub 仓库标识 / GitHub repository slug.
    private let repositorySlug = "tarnish233/GitPic"

    /// 最新 Release 的 API 地址 / Latest-release API endpoint.
    private var latestReleaseAPI: String {
        "https://api.github.com/repos/\(repositorySlug)/releases/latest"
    }

    private init() {}

    /// 自动检查的最小间隔：一天 / Minimum interval between automatic checks: one day.
    private let automaticCheckInterval: TimeInterval = 24 * 60 * 60

    /// 检查是否有可用更新 / Check whether a newer release is available.
    func checkForUpdates() async throws -> UpdateCheckResult {
        let release = try await fetchLatestRelease()
        // 每次成功检查都记录时间，手动/自动检查都参与节流（网络失败会先抛出，不会记录）
        Defaults[.lastUpdateCheck] = Date.now.timeIntervalSince1970

        if Self.isVersion(release.version, newerThan: Self.currentVersion) {
            return .updateAvailable(release)
        }
        return .upToDate(current: Self.currentVersion)
    }

    /// 后台静默检查：每天最多一次，且同一版本只提醒一次 / Silent background check:
    /// at most once per day, and only notifies once per version.
    func checkForUpdatesInBackgroundIfNeeded() async {
        let lastCheck = Defaults[.lastUpdateCheck] ?? 0
        guard Date.now.timeIntervalSince1970 - lastCheck >= automaticCheckInterval else {
            Logger.shared.verbose("距上次检查更新不足一天，跳过自动检查")
            return
        }

        do {
            let result = try await checkForUpdates()
            guard case .updateAvailable(let release) = result else {
                Logger.shared.verbose("自动检查更新：已是最新版本")
                return
            }
            // 同一版本只提醒一次，避免每天重复弹通知
            guard Defaults[.lastNotifiedVersion] != release.version else {
                Logger.shared.verbose("该版本已提醒过，跳过通知：\(release.tagName)")
                return
            }
            Defaults[.lastNotifiedVersion] = release.version
            Logger.shared.info("自动检查发现新版本：\(release.tagName)")
            NotificationExt.shared.postUpdateAvailableNotice(release)
        } catch {
            Logger.shared.warn("自动检查更新失败：\(error.localizedDescription)")
        }
    }

    // MARK: - Networking

    private func fetchLatestRelease() async throws -> AppRelease {
        var headers = HTTPHeaders()
        headers.add(HTTPHeader.accept("application/vnd.github+json"))
        headers.add(HTTPHeader.defaultUserAgent)
        headers.add(name: "X-GitHub-Api-Version", value: "2022-11-28")

        let data: Data = try await withCheckedThrowingContinuation { continuation in
            AF.request(latestReleaseAPI, method: .get, headers: headers)
                .validate(statusCode: 200 ..< 300)
                .responseData { response in
                    switch response.result {
                    case .success(let value):
                        continuation.resume(returning: value)
                    case .failure(let error):
                        var message = error.localizedDescription
                        if let data = response.data {
                            let apiMessage = JSON(data)["message"].string
                            if let apiMessage, !apiMessage.isEmpty {
                                message = apiMessage
                            }
                        }
                        continuation.resume(throwing: UpdateCheckError.network(message))
                    }
                }
        }

        let json = JSON(data)
        guard let tagName = json["tag_name"].string, !tagName.isEmpty,
              let htmlURLString = json["html_url"].string,
              let htmlURL = URL(string: htmlURLString) else {
            throw UpdateCheckError.invalidResponse
        }

        let notes = json["body"].string?.trimmingCharacters(in: .whitespacesAndNewlines)
        return AppRelease(
            version: Self.normalize(tagName),
            tagName: tagName,
            htmlURL: htmlURL,
            releaseNotes: (notes?.isEmpty == false) ? notes : nil
        )
    }

    // MARK: - Version helpers

    /// 当前应用版本（归一化）/ The running app version, normalized.
    static var currentVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        return normalize(version)
    }

    /// 去掉前缀 "v" 并保留数字点分部分 / Strip a leading "v" and keep the dotted numeric core.
    static func normalize(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = value.first, first == "v" || first == "V" {
            value.removeFirst()
        }
        return value
    }

    /// 比较语义化版本号：lhs 是否比 rhs 新 / Semantic-ish compare: is lhs newer than rhs.
    static func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        let lhsParts = components(of: lhs)
        let rhsParts = components(of: rhs)
        let count = max(lhsParts.count, rhsParts.count)
        for index in 0 ..< count {
            let left = index < lhsParts.count ? lhsParts[index] : 0
            let right = index < rhsParts.count ? rhsParts[index] : 0
            if left != right {
                return left > right
            }
        }
        return false
    }

    /// 把版本号拆成数字部分，忽略预发布后缀 / Split a version into numeric parts, ignoring pre-release suffixes.
    private static func components(of version: String) -> [Int] {
        normalize(version)
            .split(separator: ".")
            .map { part -> Int in
                let digits = part.prefix { $0.isNumber }
                return Int(digits) ?? 0
            }
    }
}
