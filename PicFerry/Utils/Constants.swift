//
//  Constants.swift
//  GitPic
//
//  Created by Svend Jin on 2019/6/11.
//  Copyright © 2019 Svend Jin. All rights reserved.
//

import Cocoa
import Foundation

struct Constants {
    
    static let none = "None"
    
    struct CachePath {
        static let historyTableName: String = "historyTable"
        static let outputFormatTableTableName: String = "outputFormatTableTable"
        static var databasePath: String {
            let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.tarnish233.gitpic"
            return URL.cachesDirectory
                .appending(path: bundleIdentifier, directoryHint: .isDirectory)
                .appending(path: "GitPic.db", directoryHint: .notDirectory)
                .path
        }
    }
}
