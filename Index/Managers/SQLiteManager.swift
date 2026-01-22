//
//  SQLManager.swift
//  Data Inspector
//
//  Created by Axel Martinez on 13/11/24.
//

import SQLiteKit
import SwiftUI

enum SQLiteManagerError: LocalizedError {
    case noConnection(message: String)
}

enum DisplayMode: String {
    case CoreData
    case SwiftData
    case SQLite
}

class SQLiteManager: ObservableObject {
    @Published var openFileURL: URL?
    @Published var openAppInfo: AppInfo?
    @Published var openAsSQLite = false
    @Published var displayMode: DisplayMode = .SQLite
    @Published var isReadOnly = false
    
    var metadata : [String: Any]?
    var model: NSManagedObjectModel?
    var connection: SQLiteConnection? = nil
    
    private var accessedFolderURL: URL?
    
    var db: any SQLDatabase {
        get throws {
            if let connection = connection, !connection.isClosed {
                return connection.sql()
            }
            
            throw SQLiteManagerError.noConnection(message: "No database connection available")
        }
    }
    
    deinit {
        // Use the synchronous close via EventLoopFuture for deinit
        try? self.connection?.close().wait()
        
        accessedFolderURL?.stopAccessingSecurityScopedResource()
    }
    
    func setFolderAccess(_ folderURL: URL) {
        // Stop previous folder access
        accessedFolderURL?.stopAccessingSecurityScopedResource()
        accessedFolderURL = folderURL
    }
    
    func connect(fileURL: URL, appInfo: AppInfo? = nil, forceReadOnly: Bool = false) async throws {
        var newConnection: SQLiteConnection
        var openedAsReadOnly = false

        if forceReadOnly {
            // User requested read-only mode
            let fileURI = "file:\(fileURL.path)?immutable=1"

            newConnection = try await SQLiteConnection.open(
                storage: .file(path: fileURI)
            )

            _ = try await newConnection.query("PRAGMA quick_check")

            openedAsReadOnly = true
        } else {
            // Try read-write mode first
            do {
                let rwConnection = try await SQLiteConnection.open(
                    storage: .file(path: fileURL.path)
                )

                // Validate the connection and check for corruption
                do {
                    _ = try await rwConnection.query("PRAGMA quick_check")

                    newConnection = rwConnection
                } catch {
                    // Close if validation failed
                    try? await rwConnection.close()

                    throw error
                }
            } catch {
                // Fallback to immutable (read-only) mode for WAL databases or permission issues
                let fileURI = "file:\(fileURL.path)?immutable=1"

                newConnection = try await SQLiteConnection.open(
                    storage: .file(path: fileURI)
                )

                // Validate the read-only connection and check for corruption
                _ = try await newConnection.query("PRAGMA quick_check")

                openedAsReadOnly = true
            }
        }
        
        do {
            var newMetadata: [String: Any]? = nil
            var newModel: NSManagedObjectModel? = nil
            
            if fileURL.pathExtension == "store" {
                (newMetadata, newModel) = try await loadModelCacheAndMetadata(from: fileURL, using: newConnection)
            }
            
            // Close the old connection only after the new one is established and validated
            if let oldConnection = self.connection {
                try? await oldConnection.close()
            }
            
            self.connection = newConnection
            self.metadata = newMetadata
            self.model = newModel

            try await setDisplayMode()

            let isReadOnly = openedAsReadOnly
            
            await MainActor.run {
                self.openFileURL = fileURL
                self.openAppInfo = appInfo
                self.isReadOnly = isReadOnly
            }
        } catch {
            // Close the new connection if setup fails
            try? await newConnection.close()
            
            throw error
        }
    }
    
    func closeConnection() async throws {
        try await self.connection?.close()
    }
    
    func runQuery(_ query: String) async throws {
        try await db.execute(sql: SQLQueryString(query)) { row in }
    }
    
    func runQuery<T>(_ query: String) async throws -> [T] where T: Decodable {
        let rows = try db.raw(SQLQueryString(query))
        
        return try await rows.all(decoding: T.self)
    }
    
    func runQuery<T>(_ query: String, mapping: (any SQLRow) throws -> T?) async throws -> [T]  {
        let rows = try db.raw(SQLQueryString(query))
        
        return try await rows.all().compactMap(mapping)
    }
    
    func runQuery<T>(_ query: String, column: String) async throws -> T? where T: Decodable {
        let row = try await db.raw(SQLQueryString(query)).first()
        
        return try row?.decode(column: column, as: T.self)
    }
    
    func runQuery(_ query: String, handler: @escaping @Sendable (any SQLRow) -> Void) async throws {
        let rows = try db.raw(SQLQueryString(query))
        
        try await rows.run(handler)
    }
    
    func runQuery<T>(_ query: String, handler: @escaping @Sendable ([any SQLRow]) -> T) async throws -> T {
        let rows = try db.raw(SQLQueryString(query))
        
        return try await handler(rows.all())
    }
    
    private func loadModelCacheAndMetadata(from url: URL, using connection: SQLiteConnection) async throws -> ([String: Any]?, NSManagedObjectModel?) {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: url,
            options: nil
        )

        let query = "SELECT Z_CONTENT FROM Z_MODELCACHE"
        let rows = connection.sql().raw(SQLQueryString(query))
        let data = try await { rows in
            do {
                let data = try rows.first?.decode(column: "Z_CONTENT", as: Data.self)
                let modelData = NSData(data: data!)
                return try? modelData.decompressed(using: .zlib) as Data
            } catch {
                print("Can't decode model cache: \(error.localizedDescription)")
            }
            return nil
        }(rows.all())
        
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data!)
        unarchiver.requiresSecureCoding = false
        
        let model = unarchiver.decodeObject(of: NSManagedObjectModel.self, forKey: NSKeyedArchiveRootObjectKey)
        
        return (metadata, model)
    }
    
    @MainActor
    private func setDisplayMode() async throws {
        if openAsSQLite {
            self.displayMode = .SQLite
        } else {
            guard let version = metadata?["NSPersistenceFrameworkVersion"] as? Int else {
                self.displayMode = .SQLite
                return
            }
            
            if version > 800 {
                self.displayMode = .SwiftData
            } else {
                self.displayMode = .CoreData
            }
        }
    }
}
