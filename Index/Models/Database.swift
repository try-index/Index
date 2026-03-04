//
//  Database.swift
//  Index
//
//  Created by Axel Martinez on 27/01/26.
//

import Foundation

/// Represents a group of databases
struct DatabaseGroup: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

enum DatabaseType: String, Codable, CaseIterable {
    case sqlite = "SQLite File"
    case fdbDocumentLayer = "FDB Document Layer"

    var isEnabled: Bool {
        switch self {
        case .sqlite: return true
        case .fdbDocumentLayer: return false
        }
    }
}

/// Represents a saved database
struct Database: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let filePath: String
    let dateAdded: Date
    var lastOpened: Date
    var bookmark: Data?
    var directoryBookmark: Data? // Optional: only created if user grants explicit directory access
    var groupId: UUID?
    var readOnly: Bool // Whether to open this database in read-only mode
    var ignoreDataModel: Bool // Whether to open as plain SQLite instead of CoreData/SwiftData

    init(
        id: UUID = UUID(),
        name: String,
        filePath: String,
        dateAdded: Date = Date(),
        lastOpened: Date = Date(),
        bookmark: Data? = nil,
        directoryBookmark: Data? = nil,
        groupId: UUID? = nil,
        readOnly: Bool = false,
        ignoreDataModel: Bool = false
    ) {
        self.id = id
        self.name = name
        self.filePath = filePath
        self.dateAdded = dateAdded
        self.lastOpened = lastOpened
        self.bookmark = bookmark
        self.directoryBookmark = directoryBookmark
        self.groupId = groupId
        self.readOnly = readOnly
        self.ignoreDataModel = ignoreDataModel
    }

    var displayName: String {
        if !name.isEmpty && name != URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent {
            return name
        }
        return URL(fileURLWithPath: filePath).lastPathComponent
    }

    var fileExtension: String {
        URL(fileURLWithPath: filePath).pathExtension.lowercased()
    }
}

