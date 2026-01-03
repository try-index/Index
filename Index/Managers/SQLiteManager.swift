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
    
    var metadata : [String: Any]?
    var model: NSManagedObjectModel?
    
    var connection: SQLiteConnection? = nil
    var db: any SQLDatabase {
        get throws {
            if let connection = connection, !connection.isClosed {
                return connection.sql()
            }
            
            throw SQLiteManagerError.noConnection(message: "No database connection available")
        }
    }
    
    deinit {
        try? self.closeConnection()
    }
    
    func connect(fileURL: URL, appInfo: AppInfo? = nil) async throws {
        if self.connection != nil {
            try closeConnection()
        }
        
        self.connection = try await SQLiteConnectionSource(
            configuration: .init(
                storage: .file(path: fileURL.absoluteString)
            ),
            threadPool: .singleton
        ).makeConnection(
            logger: .init(label: "DataInspector"),
            on: MultiThreadedEventLoopGroup.singleton.any()
        ).get()
        
        if fileURL.pathExtension == "store" {
            try await loadModelCacheAndMetadata(from: fileURL)
        } else {
            self.metadata = nil
            self.model = nil
        }

        try await setDisplayMode()
        
        await MainActor.run {
            self.openFileURL = fileURL
            self.openAppInfo = appInfo
        }
    }
    
    func closeConnection() throws {
        try self.connection?.close().wait()
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
    
    private func loadModelCacheAndMetadata (from url: URL) async throws {
        self.metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: url,
            options: nil
        )

        let query = "SELECT Z_CONTENT FROM Z_MODELCACHE"
        let data =  try await self.runQuery(query, handler: { rows in
            do  {
                let data = try rows.first?.decode(column: "Z_CONTENT", as: Data.self)
                     
                    //return data
                let modelData = NSData(data: data!)
                return try? modelData.decompressed(using: .zlib) as Data
            } catch {
                print("Can't decode model cache: \(error.localizedDescription)")
            }
                
            return nil
        })
        
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data!)
        unarchiver.requiresSecureCoding = false
        
        self.model = unarchiver.decodeObject(of: NSManagedObjectModel.self, forKey: NSKeyedArchiveRootObjectKey)
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
