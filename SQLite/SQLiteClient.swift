//
//  SQLiteClient.swift
//  Index
//
//  Created by Axel Martinez on 13/11/24.
//  Refactored to actor on 28/01/26.
//

import Foundation
import SQLiteKit
import CoreData

enum SQLiteClientError: LocalizedError {
    case noConnection
    case connectionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No database connection available"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        }
    }
}

/// SQLite client for database operations.
actor SQLiteClient {
    private var connection: SQLiteConnection?
    private var _metadata: [String: Any]?
    private var _model: NSManagedObjectModel?
    
    var isConnected: Bool {
        connection != nil && !(connection?.isClosed ?? true)
    }
    
    var metadata: [String: Any]? {
        _metadata
    }
    
    var model: NSManagedObjectModel? {
        _model
    }
    
    var db: any SQLDatabase {
        get throws {
            guard let connection = connection, !connection.isClosed else {
                throw SQLiteClientError.noConnection
            }
            
            return connection.sql()
        }
    }
    
    init() {}
    
    deinit {
        // Synchronous close for deinit - actor isolation means this is safe
        try? connection?.close().wait()
    }
    
    func connect(to url: URL, readOnly: Bool = false) async throws {
        var newConnection: SQLiteConnection

        if readOnly {
            let fileURI = "file:\(url.path)?immutable=1"
            newConnection = try await SQLiteConnection.open(
                storage: .file(path: fileURI)
            )
            _ = try await newConnection.query("PRAGMA quick_check")
        } else {
            do {
                let rwConnection = try await SQLiteConnection.open(
                    storage: .file(path: url.path)
                )
                do {
                    _ = try await rwConnection.query("PRAGMA quick_check")
                    newConnection = rwConnection
                } catch {
                    try? await rwConnection.close()
                    throw error
                }
            } catch {
                let fileURI = "file:\(url.path)?immutable=1"
                newConnection = try await SQLiteConnection.open(
                    storage: .file(path: fileURI)
                )
                _ = try await newConnection.query("PRAGMA quick_check")
            }
        }

        if let oldConnection = self.connection {
            try? await oldConnection.close()
        }

        self.connection = newConnection

        // Load metadata and model for Core Data stores using the open connection
        if url.pathExtension == "store" {
            _metadata = await loadMetadata()
            _model = await loadModelCache()
        } else {
            _metadata = nil
            _model = nil
        }
    }


    func close() async throws {
        try await connection?.close()
        
        connection = nil
        _metadata = nil
        _model = nil
    }
    
    private func loadMetadata() async -> [String: Any]? {
        do {
            let row = try await db
                .select()
                .column("Z_PLIST")
                .from("Z_METADATA")
                .first()
            
            guard let row = row,
                  let plistData = try? row.decode(column: "Z_PLIST", as: Data.self),
                  let metadata = try? PropertyListSerialization.propertyList(
                    from: plistData,
                    format: nil
                  ) as? [String: Any] else {
                return nil
            }
            
            return metadata
        } catch {
            return nil
        }
    }
    
    
    private func loadModelCache() async -> NSManagedObjectModel? {
        do {
            let row = try await db
                .select()
                .column("Z_CONTENT")
                .from("Z_MODELCACHE")
                .first()
            
            guard let row = row,
                  let contentData = try? row.decode(column: "Z_CONTENT", as: Data.self),
                  let decompressed = try? (contentData as NSData).decompressed(using: .zlib) as Data else {
                return nil
            }
            
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: decompressed)
            unarchiver.requiresSecureCoding = false
            
            return unarchiver.decodeObject(of: NSManagedObjectModel.self, forKey: NSKeyedArchiveRootObjectKey)
        } catch {
            return nil
        }
    }
}
