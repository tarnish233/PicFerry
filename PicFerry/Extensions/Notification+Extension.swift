//
//  NotificationExt.swift
//  GitPic
//
//  Created by Svend Jin on 2019/8/16.
//  Copyright © 2019 Svend Jin. All rights reserved.
//

import Cocoa
import UserNotifications

final class NotificationExt: NSObject, @unchecked Sendable {
    
    static let shared = NotificationExt()
    
    func post(title: String, info: String, subtitle: String? = nil, openURL: URL? = nil) -> Void {
        self.postByNew(title: title, info: info, subtitle: subtitle, openURL: openURL)
    }
    
    func postUploadErrorNotice(_ body: String? = "") {
        self.post(title: "Upload failed".localized,
                  info: body ?? "")
    }
    
    func postUploadSuccessfulNotice(_ body: String? = "") {
        self.post(title: "Uploaded successfully".localized,
                  info: body ?? "", subtitle: "URL has been copied to the clipboard, paste and use it!".localized)
    }
    
    func postCopySuccessfulNotice(_ body: String? = "") {
        self.post(title: "URL has been copied to the clipboard, paste and use it!".localized,
                  info: body ?? "")
    }
    
    func postFileDoesNotExistNotice() {
        self.post(title: "Upload failed".localized,
                  info: "The file does not exist or has been deleted!".localized)
    }
    
    func postFileNoAccessNotice() {
        self.post(title: "Upload failed".localized,
                  info: "No access to file!".localized)
    }
    
    func postUplodingNotice(_ body: String? = "") {
        self.post(title: "The current upload task is not complete".localized,
                  info: body ?? "")
    }
    
    
    func postImportErrorNotice(_ body: String? = "The configuration file is invalid, please check!".localized) {
        self.post(title: "Import failed".localized,
                  info: body ?? "")
    }
    
    func postImportSuccessfulNotice() {
        self.post(title: "Successfully".localized,
                  info: "The configuration has been imported, please check and use!".localized)
    }
    
    func postExportErrorNotice(_ body: String? = "configuration export error!".localized) {
        self.post(title: "The current upload task is not complete".localized,
                  info: body ?? "")
    }
    
    func postExportSuccessfulNotice() {
        self.post(title: "Successfully".localized,
                  info: "The configuration file is exported successfully, Do not modify the file contents!".localized)
    }
    
    func postAppIsAlreadyRunningNotice() {
        self.post(title: "GitPic", info: "App is already running".localized)
    }

    func postUpdateAvailableNotice(_ release: AppRelease) {
        self.post(
            title: String(format: "A new version (%@) is available.".localized, release.tagName),
            info: release.releaseNotes ?? "A new version of GitPic is available for download.".localized,
            subtitle: "Click to download the update.".localized,
            openURL: release.htmlURL
        )
    }
}

extension NotificationExt: UNUserNotificationCenterDelegate {
    func postByNew(title: String, info: String, subtitle: String? = nil, openURL: URL? = nil) -> Void {
        let content = UNMutableNotificationContent()
        content.title = title
        if let subtitle = subtitle {
            content.subtitle = subtitle
        }
        content.body = info
        content.sound = UNNotificationSound.default
        var userInfo: [String: Any] = ["body": info]
        if let openURL = openURL {
            userInfo["openURL"] = openURL.absoluteString
        }
        content.userInfo = userInfo
        
        let request = UNNotificationRequest(identifier: "GITPIC_REQUEST_\(String.randomStr(len: 5))",
                                            content: content,
                                            trigger: nil)
        
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.delegate = self
        notificationCenter.setNotificationCategories([])
        
        notificationCenter.add(request) { (error) in
            if error != nil {
                // Handle any errors.
            }
        }
    }
    
    // 用户点击弹窗后的回调
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        // 若通知携带链接（例如可用更新），点击后在浏览器中打开
        if let urlString = userInfo["openURL"] as? String,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
            completionHandler()
            return
        }

        if let body = userInfo["body"] as? String {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.declareTypes([.string], owner: nil)
            NSPasteboard.general.setString(body, forType: .string)
        }
        
        completionHandler()
    }
    
    // 配置通知发起时的行为 alert -> 显示弹窗, sound -> 播放提示音
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.badge, .banner, .list, .sound])
    }
}

extension NotificationExt {
    // MARK: 请求通知权限
    static func requestAuthorization () {
        Logger.shared.verbose("Request notification authorization")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (success, error) in
            if success {
                // user accept
            } else {
                // user rejection
            }
        }
    }
}
