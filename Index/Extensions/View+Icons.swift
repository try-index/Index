//
//  View+Icons.swift
//  Index
//
//  Created by Axel Martinez on 27/1/26.
//

import SwiftUI

extension View {
    // Shared helper for file icon
    func databaseFileIcon(for database: Database) -> String {
        switch database.fileExtension {
        case "store":
            return "swiftdata"
        case "sqlite", "sqlite3", "db":
            return "cylinder.split.1x2"
        default:
            return "doc"
        }
    }
}
