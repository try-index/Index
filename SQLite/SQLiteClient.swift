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

    // MARK: - Connection

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
                // Fallback to read-only mode
                let fileURI = "file:\(url.path)?immutable=1"
                
                newConnection = try await SQLiteNIO.SQLiteConnection.open(
                    storage: .file(path: fileURI)
                )
                _ = try await newConnection.query("PRAGMA quick_check")
            }
        }

        // Load metadata for Core Data/SwiftData stores
        if url.pathExtension == "store" {
            (_metadata, _model) = try await loadModelCacheAndMetadata(from: url, using: newConnection)
        } else {
            _metadata = nil
            _model = nil
        }

        // Close old connection after new one is established
        if let oldConnection = self.connection {
            try? await oldConnection.close()
        }

        self.connection = newConnection
    }

    func close() async throws {
        try await connection?.close()
        connection = nil
        _metadata = nil
        _model = nil
    }

    // MARK: - Private Methods

    private func loadModelCacheAndMetadata(
        from url: URL,
        using connection: SQLiteConnection
    ) async throws -> ([String: Any]?, NSManagedObjectModel?) {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: url,
            options: nil
        )

        let row = try await connection.sql()
            .select()
            .column("Z_CONTENT")
            .from("Z_MODELCACHE")
            .first()

        guard let row = row,
              let contentData = try? row.decode(column: "Z_CONTENT", as: Data.self),
              let decompressed = try? (contentData as NSData).decompressed(using: .zlib) as Data else {
            return (metadata, nil)
        }

        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: decompressed)
        unarchiver.requiresSecureCoding = false

        let model = unarchiver.decodeObject(of: NSManagedObjectModel.self, forKey: NSKeyedArchiveRootObjectKey)

        return (metadata, model)
    }
}
