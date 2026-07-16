//
//  Data+Extension.swift
//  PicFerry
//
//  Created by Svend Jin on 2019/6/16.
//  Copyright © 2019 Svend Jin. All rights reserved.
//

import Cocoa

extension Data {

    func toBase64() -> String {
        base64EncodedString()
    }
    
    func toString() -> String {
        return String(data: self, encoding: .utf8) ?? ""
    }
    
    // 转换图片格式
    func convertImageData(_ fileType: NSBitmapImageRep.FileType = .png) -> Data? {
        let bitmap = NSBitmapImageRep(data: self)
        let data = bitmap?.representation(using: fileType, properties: [:])
        return data
    }
}
