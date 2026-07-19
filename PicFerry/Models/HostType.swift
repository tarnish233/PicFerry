//
//  HostType.swift
//  GitPic
//
//  Created by Svend Jin on 2019/6/15.
//  Copyright © 2019 Svend Jin. All rights reserved.
//

import Foundation

public enum HostType: String, CaseIterable, Codable {
    case github

    public init?(legacyIntValue: Int) {
        switch legacyIntValue {
        case 6:
            self = .github
        default:
            return nil
        }
    }


    public var name: String {
        NSLocalizedString("host.type.\(rawValue)", comment: "")
    }
}
