//
//  DisplayMode.swift
//  Index
//
//  Created by Axel Martinez on 13/11/24.
//

import Foundation

/// Display mode for database content based on the underlying format
enum DisplayMode: String {
    case coreData = "CoreData"
    case swiftData = "SwiftData"
    case sqlite = "SQLite"
}
