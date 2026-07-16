//
//  Util.swift
//  PicFerry
//
//  Created by Svend Jin on 2019/6/9.
//  Copyright © 2019 Svend Jin. All rights reserved.
//

import Cocoa
import SwiftyJSON

func getSystemVersionString() -> String {
    return ProcessInfo.processInfo.operatingSystemVersionString
}

func getAppVersionString() -> String {
    let versionNum = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    let buildNum = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
    return "v\(versionNum) (\(buildNum))"
}

func getModelIdentifier() -> String {
    #if os(iOS)
    var systemInfo = utsname()
    uname(&systemInfo)
    let machineMirror = Mirror(reflecting: systemInfo.machine)
    let modelIdentifier = machineMirror.children.reduce("") { identifier, element in
        guard let value = element.value as? Int8, value != 0 else { return identifier }
        return identifier + String(UnicodeScalar(UInt8(value)))
    }
    return modelIdentifier

    #else
    var modelIdentifier: String?
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
    if let modelData = IORegistryEntryCreateCFProperty(service, "model" as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? Data {
        modelIdentifier = String(data: modelData, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
    }
    IOObjectRelease(service)
    return modelIdentifier ?? "Mac"

    #endif
}

func debugPrintOnly(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    debugPrint(items, separator: separator, terminator: terminator)
    #endif
}
