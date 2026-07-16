//
//  BoolType.swift
//  PicFerry
//
//  Created by Svend Jin on 2019/6/13.
//  Copyright © 2019 Svend Jin. All rights reserved.
//

public enum BoolType: String {
    case _true
    case _false

    public var bool: Bool {
        get {
            return self == ._true
        }

        set {
            self = newValue ? ._true : ._false
        }
    }
}
