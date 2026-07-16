//
//  ScreenUtil.swift
//  PicFerry
//
//  Created by Svend Jin on 2021/1/21.
//  Copyright © 2021 Svend Jin. All rights reserved.
//

import Cocoa

class ScreenUtil {
    static func screeningRecordPermissionCheck() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// 请求屏幕权限
    static func requestRecordScreenPermissions() {
        CGRequestScreenCaptureAccess()
    }

    /// 打开屏幕权限设置页
    static func openPrivacyScreenCapture() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

}
