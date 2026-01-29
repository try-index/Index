//
//  DatabasesManager.swift
//  Index
//
//  Created by Axel Martinez on 27/01/26.
//

import Foundation
import SwiftUI

/// Manages saved databases and recent history
class DatabasesManager: ObservableObject {
    @Published var recentDatabases: [Database] = []
    @Published var groups: [DatabaseGroup] = []

    /// Set to true to show the open database modal from menu commands
    @Published var showOpenModal = false

    private let maxRecentDatabases = 50
    private let databasesKey = "recentDatabases"
    private let groupsKey = "databaseGroups"

    init() {
        loadData()
    }

    // MARK: - Persistence

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: databasesKey),
           let databases = try? JSONDecoder().decode([Database].self, from: data) {
            self.recentDatabases = databases
        }

        if let data = UserDefaults.standard.data(forKey: groupsKey),
           let groups = try? JSONDecoder().decode([DatabaseGroup].self, from: data) {
            self.groups = groups
        }
    }

    private func saveDatabases() {
        guard let data = try? JSONEncoder().encode(recentDatabases) else { return }
        UserDefaults.standard.set(data, forKey: databasesKey)
    }

    private func saveGroups() {
        guard let data = try? JSONEncoder().encode(groups) else { return }
        UserDefaults.standard.set(data, forKey: groupsKey)
    }

    // MARK: - Database Management

    func addDatabase(from url: URL) {
        let bookmark = try? url.bookmarkData(options: .withSecurityScope)

        let database = Database(
            name: url.deletingPathExtension().lastPathComponent,
            filePath: url.path,
            bookmark: bookmark
        )

        // Remove existing database with same path
        recentDatabases.removeAll { $0.filePath == database.filePath }

        // Insert at beginning
        recentDatabases.insert(database, at: 0)

        // Trim to max
        if recentDatabases.count > maxRecentDatabases {
            recentDatabases = Array(recentDatabases.prefix(maxRecentDatabases))
        }

        saveDatabases()
    }

    func updateLastOpened(for database: Database) {
        if let index = recentDatabases.firstIndex(where: { $0.id == database.id }) {
            recentDatabases[index].lastOpened = Date()
            saveDatabases()
        }
    }

    func updateDatabase(_ database: Database) {
        if let index = recentDatabases.firstIndex(where: { $0.id == database.id }) {
            recentDatabases[index] = database
            saveDatabases()
        }
    }

    func removeDatabase(_ database: Database) {
        recentDatabases.removeAll { $0.id == database.id }
        saveDatabases()
    }

    func clearAll() {
        recentDatabases.removeAll()
        saveDatabases()
    }

    /// Resolves a database's bookmark and returns the URL
    func resolveURL(for database: Database) -> URL? {
        guard let bookmark = database.bookmark else {
            return URL(fileURLWithPath: database.filePath)
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        if isStale, let newBookmark = try? url.bookmarkData(options: .withSecurityScope) {
            if let index = recentDatabases.firstIndex(where: { $0.id == database.id }) {
                recentDatabases[index].bookmark = newBookmark
                saveDatabases()
            }
        }

        return url
    }

    // MARK: - Group Management

    func addGroup(name: String) {
        let group = DatabaseGroup(name: name)

        groups.append(group)
        saveGroups()
    }

    func removeGroup(_ group: DatabaseGroup) {
        // Move databases from this group back to ungrouped
        for index in recentDatabases.indices {
            if recentDatabases[index].groupId == group.id {
                recentDatabases[index].groupId = nil
            }
        }

        groups.removeAll { $0.id == group.id }
        saveDatabases()
        saveGroups()
    }

    func renameGroup(_ group: DatabaseGroup, to name: String) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index].name = name
            saveGroups()
        }
    }

    func moveDatabase(_ database: Database, to group: DatabaseGroup?) {
        if let index = recentDatabases.firstIndex(where: { $0.id == database.id }) {
            recentDatabases[index].groupId = group?.id
            saveDatabases()
        }
    }

    func databases(for group: DatabaseGroup?) -> [Database] {
        if let group = group {
            return recentDatabases.filter { $0.groupId == group.id }
        } else {
            return recentDatabases
        }
    }
}
