//
//  Host.swift
//  PicFerry
//
//  Created by Svend Jin on 2019/6/11.
//  Copyright © 2019 Svend Jin. All rights reserved.
//

import Foundation
import Cocoa
import SwiftyJSON

class Host: Equatable, CustomDebugStringConvertible, Codable {

    static func ==(lhs: Host, rhs: Host) -> Bool {
        return (lhs.id == rhs.id)
    }

    static func getDefaultHost() -> Host {
        return Host(HostType.github, data: HostConfig.create(type: .github))
    }

    static func getIconNameByType(type: HostType) -> String {
        return "host_icon_\(type.rawValue)"
    }

    static func getIconByType(type: HostType) -> NSImage {
        let iconName = Host.getIconNameByType(type: type)
        guard let image = NSImage(named: iconName) else {
            return NSImage(
                systemSymbolName: "externaldrive",
                accessibilityDescription: type.name
            ) ?? NSImage(size: NSSize(width: 20, height: 20))
        }
        let width = 20.0, height = Double(image.size.height) / (Double(image.size.width) / width)
        image.size = NSSize(width: width, height: height)
        return image
    }

    var id: String
    var name: String
    var type: HostType
    var data: HostConfig?

    init(_ type: HostType, data: HostConfig?) {
        self.id = UUID().uuidString
        self.name = type.name
        self.type = type
        self.data = data
    }

    public var debugDescription: String {
        "\(name) Type: \(type.rawValue)"
    }


    func serialize(includeSecrets: Bool = false) -> String {
        var dict = Dictionary<String, Any>()
        dict["id"] = self.id
        dict["name"] = self.name
        dict["type"] = self.type.rawValue
        dict["data"] = self.data?.serialize(includeSecrets: includeSecrets)

        return JSON(dict).rawString() ?? "{}"
    }
    
    func copy() -> Host {
        guard let newHost = Host.deserialize(str: serialize(includeSecrets: true)) else {
            return Host(type, data: data)
        }
        newHost.id = UUID().uuidString
        return newHost
    }

    static func deserialize(str: String) -> Host? {
        // FIXME: - Workaround
        guard let data = str.data(using: .utf8), let json = try? JSON(data: data) else {
            return nil
        }

        let type: HostType?
        if let legacyValue = json["type"].int {
            type = HostType(legacyIntValue: legacyValue)
        } else {
            type = HostType(rawValue: json["type"].stringValue)
        }
        guard let type else { return nil }
        
        
        let hostData = HostConfig.deserialize(type: type, str: json["data"].string)

        let host = Host(type, data: hostData)
        let savedID = json["id"].stringValue
        let savedName = json["name"].stringValue
        host.id = savedID.isEmpty ? UUID().uuidString : savedID
        host.name = savedName.isEmpty ? type.name : savedName
        host.type = type
        host.data = hostData

        return host
    }
}

// Host already exposes a stable `id`, so it can drive SwiftUI lists directly.
extension Host: Identifiable {}
