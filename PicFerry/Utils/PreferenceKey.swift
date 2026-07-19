//
//  PreferenceKey.swift
//  GitPic
//
//  Created by Svend Jin on 2019/6/13.
//  Copyright © 2019 Svend Jin. All rights reserved.
//

import Foundation

struct Keys {
    static let firstUsage = "GitPic_FirstUsage"
    static let hostItems = "GitPic_hostItems"
    static let defaultHostId = "GitPic_DefaultHostId"
    static let outputFormat = "GitPic_OutputFormat"
    static let outputFormatEncoded = "GitPic_OutputFormatEncoded"
    static let historyList = "GitPic_HistoryList_New"
    static let historyLimit = "GitPic_HistoryLimit_New"
    static let compressFactor = "GitPic_CompressFactor"
    static let lastUpdateCheck = "GitPic_LastUpdateCheck"
    static let lastNotifiedVersion = "GitPic_LastNotifiedVersion"
    static let rootDirectoryBookmark = "GitPic_RootDirectoryBookmark"
    static let homeDirectoryBookmark = "GitPic_HomeDirectoryBookmark"
    static let rootSubdirectoryBookmarks = "GitPic_RootSubdirectoryBookmarks"
    static let rootSubdirectoryNames = "GitPic_RootSubdirectoryNames"
}

class DefaultsKeys {
    fileprivate init() {
    }
}

class DefaultsKey<ValueType>: DefaultsKeys, @unchecked Sendable {
    let _key: String

    init(_ key: String) {
        self._key = key
    }

}


extension DefaultsKeys {

    // The values corresponding to the following keys are String.

    // value example: BoolType._true.rawValue
    static let firstUsage = DefaultsKey<String>(Keys.firstUsage)
    static let hostItems = DefaultsKey<[Host]>(Keys.hostItems)
    static let defaultHostId = DefaultsKey<String>(Keys.defaultHostId)
    static let outputFormat = DefaultsKey<Int>(Keys.outputFormat)
    static let outputFormatEncoded = DefaultsKey<Bool>(Keys.outputFormatEncoded)
    static let historyLimit = DefaultsKey<Int>(Keys.historyLimit)
    static let compressFactor = DefaultsKey<Int>(Keys.compressFactor)
    // 上次自动检查更新的时间（timeIntervalSince1970）
    static let lastUpdateCheck = DefaultsKey<Double>(Keys.lastUpdateCheck)
    // 上次已通过通知提醒过的可用版本号（避免同一版本每天重复提醒）
    static let lastNotifiedVersion = DefaultsKey<String>(Keys.lastNotifiedVersion)
    // 根目录授权书签
    static let rootDirectoryBookmark = DefaultsKey<Data>(Keys.rootDirectoryBookmark)
    // 主目录授权书签
    static let homeDirectoryBookmark = DefaultsKey<Data>(Keys.homeDirectoryBookmark)
    // 根目录子目录书签（用于 macOS 15.0 的临时解决方案）
    static let rootSubdirectoryBookmarks = DefaultsKey<[Data]>(Keys.rootSubdirectoryBookmarks)
    // 根目录子目录名称列表（用于对比检测）
    static let rootSubdirectoryNames = DefaultsKey<[String]>(Keys.rootSubdirectoryNames)

}

nonisolated(unsafe) let Defaults = UserDefaults.standard

extension UserDefaults {
    subscript(key: DefaultsKey<Bool>) -> Bool {
        get {
            bool(forKey: key._key) 
        }
        set {
            set(newValue, forKey: key._key)
        }
    }
    
    subscript(key: DefaultsKey<String>) -> String? {
        get {
            return string(forKey: key._key)
        }
        set {
            set(newValue, forKey: key._key)
        }
    }

    subscript(key: DefaultsKey<Int>) -> Int? {
        get {
            return integer(forKey: key._key)
        }
        set {
            set(newValue, forKey: key._key)
        }
    }
    
    subscript(key: DefaultsKey<Double>) -> Double? {
        get {
            return double(forKey: key._key)
        }
        set {
            set(newValue, forKey: key._key)
        }
    }
    
    subscript(key: DefaultsKey<Float>) -> Float? {
        get {
            return float(forKey: key._key)
        }
        set {
            set(newValue, forKey: key._key)
        }
    }
    
    subscript(key: DefaultsKey<Data>) -> Data? {
        get {
            return data(forKey: key._key)
        }
        set {
            set(newValue, forKey: key._key)
        }
    }

    subscript(key: DefaultsKey<[Host]>) -> [Host]? {
        get {
            var result = [Host]()
            if let arr = array(forKey: key._key) {
                for item in arr {
                    guard let string = item as? String,
                          let host = Host.deserialize(str: string) else {
                        continue
                    }
                    result.append(host)
                }
            }
            return result
        }
        set {
            var result = [String]()
            if let arr = newValue {
                for item in arr {
                    let encodedString = item.serialize()
                    result.append(encodedString)
                }
            }
            set(result, forKey: key._key)
        }
    }
    
    subscript(key: DefaultsKey<[String]>) -> [String]? {
        get {
            return array(forKey: key._key) as? [String]
        }
        set {
            set(newValue, forKey: key._key)
        }
    }
    
    subscript(key: DefaultsKey<[[String: Any]]>) -> [[String: Any]]? {
        get {
            return array(forKey: key._key) as? [[String: Any]]
        }
        set {
            set(newValue, forKey: key._key)
        }
    }
    
    subscript(key: DefaultsKey<[Data]>) -> [Data]? {
        get {
            return array(forKey: key._key) as? [Data]
        }
        set {
            set(newValue, forKey: key._key)
        }
    }
}
