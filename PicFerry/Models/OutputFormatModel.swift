//
//  OutputType.swift
//  PicFerry
//
//  Created by Svend Jin on 2021/01/19.
//  Copyright © 2021 Svend Jin. All rights reserved.
//

import Foundation
@preconcurrency import WCDBSwift

final class OutputFormatModel: TableCodable, Identifiable {
    var identifier: Int? = nil
    var name: String = ""
    var value: String = ""

    var id: Int {
        identifier ?? -1
    }
    
    enum CodingKeys: String, CodingTableKey {
        typealias Root = OutputFormatModel
        case identifier
        case name
        case value
        
        static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(identifier, isPrimary: true)
        }
    }
    
    init() {
        self.name = ""
        self.value = ""
    }
    
    init(name: String , value: String) {
        self.name = name
        self.value = value
    }
    
    public var debugDescription: String {
        return "ID: \(identifier ?? 0), NAME: \(name), VALUE: \(value)"
    }
    
    static func getDefaultOutputFormats() -> [OutputFormatModel] {
        let formats = [
            OutputFormatModel(name: "URL", value: "{url}"),
            OutputFormatModel(name: "HTML", value: "<img src=\"{url}\" alt=\"{filename}\"/>"),
            OutputFormatModel(name: "Markdown", value: "![{filename}]({url})")
        ]
        for (identifier, format) in formats.enumerated() {
            format.identifier = identifier
        }
        return formats
    }
    
    @MainActor
    static func formatUrl(_ url: String, outputFormat: OutputFormatModel?) -> String {
        var formatUrl = url
        if Defaults[.outputFormatEncoded] {
            formatUrl = url.urlEncoded()
        }
        var filename = url.lastPathComponent.deletingPathExtension.trim()
        let tempArr = filename.components(separatedBy: .whitespaces).map{ $0.trim() }.filter{ !$0.isEmpty }
        filename = tempArr.joined(separator: "")
        
        var output = outputFormat
        if output == nil {
            output = ConfigManager.shared.getOutputType()
        }
        
        guard let output else { return formatUrl }
        return output.value
            .replacingOccurrences(of: "{url}", with: formatUrl)
            .replacingOccurrences(of: "{filename}", with: filename)
        
        
    }
}
