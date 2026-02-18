//
//  SQLiteClient.swift
//  Index
//
//  Created by Axel Martinez on 13/11/24.
//

import Foundation
import SQLiteKit
import CoreData
import AppKit

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
    private var securityScopedURL: URL?
    private var securityScopedDirectoryURL: URL?
    
    var isReadOnly: Bool = false
    var metadata: [String: Any]?
    var model: NSManagedObjectModel?
    
    var isConnected: Bool {
        connection != nil && !(connection?.isClosed ?? true)
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
        try? connection?.close().wait()
    }
    
    /// Request directory access from user via PowerBox
    enum DirectoryAccessResponse {
        case granted(Data)
        case openReadOnly
        case cancelled
    }
    
    @MainActor
    func requestDirectoryAccess(for fileURL: URL) async -> DirectoryAccessResponse {
        let parentDirectory = fileURL.deletingLastPathComponent()
        
        let panel = NSOpenPanel()
        panel.message = """
        To write to this database, Index needs access to the '\(parentDirectory.lastPathComponent)' folder.
        Select the folder to grant access, or click 'Open Read-Only' to continue without write permissions.
        """
        panel.prompt = "Grant Access"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.directoryURL = parentDirectory
        
        // Add "Open Read-Only" button as accessory
        let readOnlyButton = NSButton(title: "Open Read-Only", target: nil, action: nil)
        readOnlyButton.bezelStyle = .rounded
        panel.accessoryView = readOnlyButton
        
        let response = panel.runModal()
        
        // Check if user clicked the "Open Read-Only" button
        if readOnlyButton.state == .on {
            return .openReadOnly
        }
        
        guard response == .OK, let selectedURL = panel.url else {
            return .cancelled
        }
        
        // Create security-scoped bookmark for the directory
        if let bookmark = try? selectedURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            return .granted(bookmark)
        } else {
            return .cancelled
        }
    }
    
    func connect(
        to url: URL,
        bookmarkData: Data? = nil,
        directoryBookmarkData: Data? = nil,
        readOnly: Bool = false
    ) async throws -> (fileBookmark: Data?, directoryBookmark: Data?) {
        var newConnection: SQLiteConnection
        var connectionIsReadOnly = readOnly
        var finalURL = url
        var createdBookmark: Data? = nil
        var createdDirectoryBookmark: Data? = nil
        
        // If we have bookmark data, resolve it and start accessing
        if let bookmarkData = bookmarkData {
            var isStale = false
            do {
                let resolvedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                finalURL = resolvedURL
                
                // Start accessing file
                let didStartAccessing = finalURL.startAccessingSecurityScopedResource()
                if didStartAccessing {
                    securityScopedURL = finalURL
                }
                
                // If bookmark is stale, recreate it
                if isStale {
                    createdBookmark = try? finalURL.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                }
            } catch {
                // Bookmark resolution failed, will use provided URL
            }
        }
        
        // Also resolve and access parent directory bookmark for SQLite WAL/SHM files
        if let directoryBookmarkData = directoryBookmarkData {
            var isStale = false
            do {
                let resolvedDirURL = try URL(
                    resolvingBookmarkData: directoryBookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                // Start accessing directory
                let didStartAccessingDirectory = resolvedDirURL.startAccessingSecurityScopedResource()
                if didStartAccessingDirectory {
                    securityScopedDirectoryURL = resolvedDirURL
                }
                
                // If bookmark is stale, recreate it
                if isStale {
                    createdDirectoryBookmark = try? resolvedDirURL.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                }
            } catch {
                // Directory bookmark resolution failed
            }
        }
        
        if readOnly {
            // Open in read-only mode if explicitly requested
            let fileURI = "file:\(finalURL.path)?immutable=1"
            
            newConnection = try await SQLiteConnection.open(
                storage: .file(path: fileURI)
            )
            
            _ = try await newConnection.query("PRAGMA quick_check")
            connectionIsReadOnly = true
        } else {
            // Try to open in write mode
            do {
                newConnection = try await SQLiteConnection.open(
                    storage: .file(path: finalURL.path)
                )
                
                _ = try await newConnection.query("PRAGMA quick_check")
                connectionIsReadOnly = false
                
                // Create bookmarks for persistent access if we don't have them
                if bookmarkData == nil && createdBookmark == nil {
                    // URL is from NSOpenPanel (security-scoped) - create file bookmark
                    createdBookmark = try? finalURL.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                }
                
                if directoryBookmarkData == nil && createdDirectoryBookmark == nil {
                    // Create directory bookmark for WAL/SHM files
                    let parentURL = finalURL.deletingLastPathComponent()
                    createdDirectoryBookmark = try? parentURL.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                }
            } catch {
                // If write mode fails, fallback to read-only
                let fileURI = "file:\(finalURL.path)?immutable=1"
                
                newConnection = try await SQLiteConnection.open(
                    storage: .file(path: fileURI)
                )
                
                _ = try await newConnection.query("PRAGMA quick_check")
                connectionIsReadOnly = true
            }
        }
        
        // Save references to old security-scoped resources before updating
        let oldFileURL = securityScopedURL
        let oldDirectoryURL = securityScopedDirectoryURL
        
        // Close old connection
        if let oldConnection = self.connection {
            try? await oldConnection.close()
        }
        
        // Update connection and security-scoped URLs
        self.connection = newConnection
        self.isReadOnly = connectionIsReadOnly
        
        // Stop accessing old file URL if it's different from the new one
        if let oldURL = oldFileURL, oldURL != finalURL {
            oldURL.stopAccessingSecurityScopedResource()
        }
        
        // Stop accessing old directory URL ONLY if it's different from the new one
        // This prevents stopping and restarting access to the same directory
        if let oldDirURL = oldDirectoryURL {
            // Check if we have a new directory URL
            if let newDirURL = securityScopedDirectoryURL {
                // Only stop if they're different
                if oldDirURL != newDirURL {
                    oldDirURL.stopAccessingSecurityScopedResource()
                }
            } else {
                // No new directory, stop the old one
                oldDirURL.stopAccessingSecurityScopedResource()
            }
        }
        
        // Load metadata and model for Core Data stores using the open connection
        if finalURL.pathExtension == "store" {
            metadata = await loadMetadata()
            model = await loadModelCache()
        } else {
            metadata = nil
            model = nil
        }
        
        return (createdBookmark, createdDirectoryBookmark)
    }
    
    func close() async throws {
        try await connection?.close()
        
        // Stop accessing security-scoped resources
        if let url = securityScopedURL {
            url.stopAccessingSecurityScopedResource()
            securityScopedURL = nil
        }
        
        if let dirURL = securityScopedDirectoryURL {
            dirURL.stopAccessingSecurityScopedResource()
            securityScopedDirectoryURL = nil
        }
        
        connection = nil
        metadata = nil
        model = nil
        isReadOnly = false
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
