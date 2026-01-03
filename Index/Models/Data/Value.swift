//
//  DataType.swift
//  Data Inspector
//
//  Created by Axel Martinez on 13/3/25.
//

import SwiftUI
import SQLiteKit

public enum Value: Hashable {
    case smallint(Int16)
    case integer(Int)
    case float(Float)
    case real(Double)
    case text(String)
    case array([Value])
    case image(NSImage)
    case timestamp(Date)
    case null
}
