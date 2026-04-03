//
//  DatabaseView+Connection.swift
//  Index
//
//  Created by Axel on 3/3/26.
//

import SwiftUI

extension DatabaseView {
    /// Request directory access from user via PowerBox
    enum DirectoryAccessResponse {
        case granted(Data)
        case openReadOnly
        case cancelled
    }

    func openDatabase() async {
        guard let url = databasesManager.resolveURL(for: database) else {
            databaseError = "Could not access the file. It may have been moved or deleted."
            showDatabaseError = true
            return
        }
        
        do {
            // Try to find an existing directory bookmark from another database in the same folder
            let existingDirBookmark = database.directoryBookmark ?? databasesManager.findExistingDirectoryBookmark(for: database)
            
            // Connect to database, passing existing bookmarks if available
            let (newFileBookmark, newDirBookmark) = try await client.connect(
                to: url,
                bookmarkData: database.bookmark,
                directoryBookmarkData: existingDirBookmark,
                readOnly: database.readOnly
            )
            
            // If new bookmarks were created, save them
            if let newFileBookmark = newFileBookmark {
                databasesManager.updateBookmark(for: database, bookmark: newFileBookmark)
            }
            
            if let newDirBookmark = newDirBookmark {
                databasesManager.updateDirectoryBookmark(for: database, bookmark: newDirBookmark)
            }
            
            databasesManager.updateLastOpened(for: database)
            
            if !database.ignoreDataModel,
               let metadata = await client.metadata,
               let version = metadata["NSPersistenceFrameworkVersion"] as? Int {
                
                await MainActor.run {
                    self.displayMode = version > 800 ? .SwiftData : .CoreData
                }
                
                // CoreData/SwiftData databases should always be read-only
                if !database.readOnly {
                    databasesManager.updateReadOnly(for: database, readOnly: true)
                }
            }
            
            let readOnly = await client.isReadOnly
            
            await MainActor.run {
                isReadOnly = readOnly
                isConnected = true
            }
            
            // If we don't have a directory bookmark and database is not read-only,
            // check for write permissions
            if !readOnly && !database.readOnly && database.directoryBookmark == nil {
                await checkDirectoryAccess()
            }
        } catch {
            await MainActor.run {
                databaseError = error.localizedDescription
                showDatabaseError = true
            }
        }
    }

    func closeDatabase() async {
        try? await client.close()
        
        
        // Check if this is the last database window closing
        // Count windows that are not the "Databases" window and not closing
        let databaseWindows = NSApp.windows.filter { window in
            window.title != "Databases" && window.isVisible
        }
        
        // If only one database window left (this one), show the databases window
        if databaseWindows.count <= 1 {
            openWindow(id: "databases")
        }
    }
    
    private func checkDirectoryAccess() async {
        guard let url = databasesManager.resolveURL(for: database) else { return }
        
        let parentDir = url.deletingLastPathComponent()
        
        if FileManager.default.isWritableFile(atPath: parentDir.path) {
            return
        }
        
        // Request directory access from user
        let response = await requestDirectoryAccess(for: url)
        
        switch response {
        case .granted(let dirBookmark):
            databasesManager.updateDirectoryBookmark(for: database, bookmark: dirBookmark)
            
            // Reconnect with the new directory bookmark
            do {
                let (newFileBookmark, newDirBookmark) = try await client.connect(
                    to: url,
                    bookmarkData: database.bookmark,
                    directoryBookmarkData: dirBookmark
                )
                
                if let newFileBookmark = newFileBookmark {
                    databasesManager.updateBookmark(for: database, bookmark: newFileBookmark)
                }
                if let newDirBookmark = newDirBookmark {
                    databasesManager.updateDirectoryBookmark(for: database, bookmark: newDirBookmark)
                }
            } catch {
                // Reconnection failed, will continue in read-only mode
            }
        case .openReadOnly:
            // Persist the read-only preference for future opens
            databasesManager.updateReadOnly(for: database, readOnly: true)
            
            // Reconnect in read-only mode
            do {
                let _ = try await client.connect(
                    to: url,
                    bookmarkData: database.bookmark,
                    directoryBookmarkData: nil,
                    readOnly: true
                )
                
                let readOnly = await client.isReadOnly
                
                await MainActor.run {
                    isReadOnly = readOnly
                }
            } catch {
                // Failed to reconnect, stay in current state
            }
        case .cancelled:
            // User cancelled, close the database and window entirely
            try? await client.close()
            
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    private func requestDirectoryAccess(for fileURL: URL) async -> DirectoryAccessResponse {
        let parentDirectory = fileURL.deletingLastPathComponent()
        
        // First, show alert asking user what they want to do
        let alert = NSAlert()
        alert.messageText = "Database Access Required"
        alert.informativeText = """
        To write to this database, Index needs access to the '\(parentDirectory.lastPathComponent)' folder.
        
        You can grant access to enable editing, or open the database in read-only mode.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Grant Access")
        alert.addButton(withTitle: "Open Read-Only")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            // User chose "Grant Access" - show folder picker
            let panel = NSOpenPanel()
            panel.message = "Select the '\(parentDirectory.lastPathComponent)' folder to grant write access."
            panel.prompt = "Grant Access"
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = false
            panel.directoryURL = parentDirectory
            
            let panelResponse = panel.runModal()
            
            guard panelResponse == .OK, let selectedURL = panel.url else {
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
            
        case .alertSecondButtonReturn:
            return .openReadOnly
            
        default:
            return .cancelled
        }
    }
    

}
