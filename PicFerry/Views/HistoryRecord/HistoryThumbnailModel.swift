//
//  PreViewModel.swift
//  GitPic
//
//  Created by 侯猛 on 2019/10/25.
//  Copyright © 2019 Svend Jin. All rights reserved.
//

import Foundation
@preconcurrency import WCDBSwift

final class HistoryThumbnailModel: TableCodable {
    var identifier: Int? = nil
    var url: String = ""
    var previewWidth: Double = 0
    var previewHeight: Double = 0
    var thumbnailData: Data?
    var createdDate: Date = Date()
    var size: Int = 0
    var host: String?
    var isImage: Bool = false
    
    var isAutoIncrement: Bool { return true }
    
    // dynamic
    var fileName: String {
        return url.lastPathComponent
    }
    
    var ext: String? {
        return url.lastPathComponent.pathExtension
    }
    
    enum CodingKeys: String, CodingTableKey {
        typealias Root = HistoryThumbnailModel
        case identifier
        case url
        case previewWidth
        case previewHeight
        case thumbnailData
        case createdDate
        case size
        case host
        case isImage
        
        static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(identifier, isPrimary: true)
        }
    }
    
    static func keyValue(keyValue: [String: Any]) -> HistoryThumbnailModel {
        let model = HistoryThumbnailModel()
        model.url = keyValue["url"] as? String ?? ""
        model.previewWidth = keyValue["previewWidth"] as? Double ?? 0
        model.previewHeight = keyValue["previewHeight"] as? Double ?? 0
        model.thumbnailData = keyValue["thumbnailData"] as? Data
        if let createDateStr = keyValue["createdDate"] as? String, !createDateStr.isEmpty {
            model.createdDate = Date.dateFromISOString(string: createDateStr) ?? Date()
        } else {
            model.createdDate = Date()
        }
        model.size = keyValue["size"] as? Int ?? 0
        model.host = keyValue["host"] as? String
        model.isImage = keyValue["isImage"] as? Bool ?? false
        return model
    }
    
    func toKeyValue() -> [String: Any] {
        var historyKeyValue: [String: Any] = [:]
        historyKeyValue["url"] = url
        historyKeyValue["previewWidth"] = previewWidth
        historyKeyValue["previewHeight"] = previewHeight
        if let thumbnailData = thumbnailData {
            historyKeyValue["thumbnailData"] = thumbnailData
        }
        
        historyKeyValue["createdDate"] = createdDate.toISOString()
        historyKeyValue["size"] = size
        historyKeyValue["host"] = host
        historyKeyValue["isImage"] = isImage
        return historyKeyValue
    }
    
}

extension HistoryThumbnailModel: Identifiable {
    var stableID: String {
        if let identifier {
            return String(identifier)
        }
        return "\(createdDate.timeIntervalSince1970)-\(url)"
    }

    var id: String { stableID }
}
