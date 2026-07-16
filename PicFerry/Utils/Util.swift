//
//  Util.swift
//  PicFerry
//
//  Created by Svend Jin on 2019/6/16.
//  Copyright © 2019 Svend Jin. All rights reserved.
//

import Foundation
import Cocoa
import UniformTypeIdentifiers

class Util {
    static func getFileData(filePath: String) -> Data? {
        guard let fileHandle = FileHandle(forReadingAtPath: filePath) else {
            return nil
        }
        return fileHandle.readDataToEndOfFile()
    }
    
    static func getFileData(fileUrl: URL) -> Data? {
        guard let fileHandle = try? FileHandle(forReadingFrom: fileUrl) else {
            return nil
        }
        return fileHandle.readDataToEndOfFile()
    }
    
    //根据后缀获取对应的Mime-Type
    static func getMimeType(pathExtension: String) -> String {
        // Use the new UTType API.
        if let utType = UTType(filenameExtension: pathExtension) {
            if let mimetype = utType.preferredMIMEType {
                return mimetype
            }
        }
        // 如果不知道，传万能类型application/octet-stream，服务器会自动解析文件类
        return "application/octet-stream"
    }
    
    static func getCurrentLanguage() -> String {
        let preferredLang = (Bundle.main.preferredLocalizations.first ?? "en") as NSString
        
        switch String(describing: preferredLang) {
        case "en-US", "en-CN":
            return "en"//英文
        case "zh-Hans-US","zh-Hans-CN","zh-Hant-CN","zh-TW","zh-HK","zh-Hans":
            return "cn"//中文
        default:
            return "en"
        }
    }
    
}
