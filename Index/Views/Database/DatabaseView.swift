//
//  ContentView.swift
//  Index
//
//  Created by Axel Martinez on 13/11/24.
//

import Combine
import SQLiteKit
import SwiftUI

struct DatabaseView<T: SQLiteTable>: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @Environment(DatabasesManager.self) var databasesManager
    @Environment(SimulatorsManager.self) var simManager
    
    let database: Database
    
    @State var tabs: [TabItem<T>] = []
    @State var selectedTab: TabItem<T>?
    
    @State private var client = SQLiteClient()
    @State private var databaseError: String?
    @State private var displayMode: DisplayMode = .SQLite
    @State private var showDatabaseError = false
    @State private var isConnected = false
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedTable: T?
    @State private var searchText: String = ""
    @State private var refreshContent: PassthroughSubject<Void, Never> = .init()
    @State private var selectedRecordsCount = 0
    @State private var isReadOnly = false
    @State private var isFileMenuVisible = false
    @State private var isUtilityExpanded = false
    
    var fileURL: URL {
        URL(filePath: database.filePath)
    }
    
    var body: some View {
        Group {
            if isConnected {
                NavigationSplitView(columnVisibility: $sidebarVisibility) {
                    DatabaseSidebar(
                        client: client,
                        displayMode: displayMode,
                        selection: $selectedTable,
                        onOpenInNewTab: { table in
                            openTab(for: table, forceNewTab: true)
                        }
                    )
                } detail: {
                    VStack(spacing: 0) {
                        // Custom tab bar
                        if tabs.count > 1 {
                            TabBar(
                                tabs: tabs,
                                selectedTab: $selectedTab,
                                tabTitle: { $0.title },
                                onClose: { tab in
                                    closeTab(tab)
                                }
                            )
                        }
                        
                        // Tab content
                        if let selectedTab = selectedTab {
                            tabContentView(for: selectedTab)
                        } else if selectedTable != nil {
                            ContentUnavailableView {
                                Label("No Tabs Open", systemImage: "square.stack.3d.up.slash")
                            } description: {
                                Text("Click on a table in the sidebar to open it.")
                            }
                        } else {
                            ContentUnavailableView {
                                Label("Select a Table", systemImage: "tablecells")
                            } description: {
                                Text("Choose a table from the sidebar to view its contents.")
                            }
                        }
                    }
                }
                .searchable(text: $searchText)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        HStack(spacing: 6) {
                            Button {
                                isFileMenuVisible.toggle()
                            } label: {
                                Text(fileURL.lastPathComponent)
                            }
                            .popover(isPresented: $isFileMenuVisible, arrowEdge: .bottom, content: {
                                FileMenu(fileURL: fileURL)
                                    .frame(minWidth: 200,  maxWidth: 400, minHeight: 100)
                                    .presentationCompactAdaptation(.popover)
                            })
                            
                            if isReadOnly {
                                
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10))
                                
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.quaternary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        HStack(spacing: 8) {
                            Button("", systemImage: "plus", action: {
                                requestAddRecord()
                            })
                            .disabled(selectedTab == nil || isReadOnly)
                            .help(isReadOnly ? "Cannot add records (Read Only)" : "Add Record")
                            
                            Button("", systemImage: "trash", action: {
                                requestDeleteRecords()
                            })
                            .disabled(selectedRecordsCount == 0 || isReadOnly)
                            .help(isReadOnly ? "Cannot delete records (Read Only)" : "Delete Selected Records (\(selectedRecordsCount))")
                            
                            Divider()
                                .frame(height: 16)
                            
                            Button("", systemImage: "arrow.clockwise", action: {
                                refreshContent.send()
                            })
                            .disabled(self.selectedTable == nil)
                            .help("Refresh")
                        }
                    }
                }
            } else {
                ProgressView("Opening...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("")
        .onAppear {
            openDatabase()
        }
        .onDisappear {
            closeDatabase()
        }
        .onChange(of: selectedTable) { _, newTable in
            if let newTable = newTable {
                openTab(for: newTable)
            }
        }
        .alert("Database Error", isPresented: $showDatabaseError) {
            Button("Close") {
                dismiss()
            }
        } message: {
            Text(databaseError ?? "Failed to open the database file.")
        }
    }
    
    @ViewBuilder
    private func tabContentView(for tab: TabItem<T>) -> some View {
        VStack(spacing: 0) {
            ContentView(
                client: client,
                searchText: $searchText,
                dataObject: tab.table,
                refresh: refreshContent,
                filterColumn: tab.filterColumn,
                filterValue: tab.filterValue,
                onOpenRelatedTable: { table, column, value in
                    openRelatedTable(table: table, column: column, value: value)
                },
                isUtilityExpanded: $isUtilityExpanded,
                selectedRecordsCount: $selectedRecordsCount,
                isReadOnly: isReadOnly
            )
            
            // Utility drawer
            UtilityView(
                sqlQuery: tab.sqlQuery,
                isExpanded: $isUtilityExpanded
            )
        }
    }
    
    // MARK: - Connection
    
    private func openDatabase() {
        guard let url = databasesManager.resolveURL(for: database) else {
            databaseError = "Could not access the file. It may have been moved or deleted."
            showDatabaseError = true
            return
        }
        
        Task {
            do {
                // Try to find an existing directory bookmark from another database in the same folder
                let existingDirBookmark = database.directoryBookmark ?? databasesManager.findExistingDirectoryBookmark(for: database)
                
                // Connect to database, passing existing bookmarks if available
                let (newFileBookmark, newDirBookmark) = try await client.connect(
                    to: url,
                    bookmarkData: database.bookmark,
                    directoryBookmarkData: existingDirBookmark,
                    readOnly: database.forceReadOnly
                )
                
                // If new bookmarks were created, save them
                if let newFileBookmark = newFileBookmark {
                    databasesManager.updateBookmark(for: database, bookmark: newFileBookmark)
                }
                
                if let newDirBookmark = newDirBookmark {
                    databasesManager.updateDirectoryBookmark(for: database, bookmark: newDirBookmark)
                }
                
                databasesManager.updateLastOpened(for: database)
                
                let mode = await configureDisplayMode()
                let readOnly = await client.isReadOnly
                
                await MainActor.run {
                    displayMode = mode
                    isConnected = true
                    isReadOnly = readOnly
                }
                
                // If we don't have a directory bookmark and database is not read-only,
                // check if we can write by attempting to create a test file
                if !readOnly && !database.forceReadOnly && database.directoryBookmark == nil {
                    await checkAndRequestDirectoryAccessIfNeeded()
                }
            } catch {
                await MainActor.run {
                    databaseError = error.localizedDescription
                    showDatabaseError = true
                }
            }
        }
    }
    
    private func checkAndRequestDirectoryAccessIfNeeded() async {
        guard let url = databasesManager.resolveURL(for: database) else { return }
        
        let parentDir = url.deletingLastPathComponent()
        let testFile = parentDir.appendingPathComponent(".index_write_test")
        
        // Try to create a test file to check write access
        let canWrite = FileManager.default.createFile(atPath: testFile.path, contents: Data())
        
        if canWrite {
            // Clean up test file
            try? FileManager.default.removeItem(at: testFile)
            
            return
        }
        
        // Request directory access from user
        let response = await client.requestDirectoryAccess(for: url)
        
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
            // User cancelled, continue in current state (read-only)
            break
        }
    }
    
    private func closeDatabase() {
        Task {
            try? await client.close()
        }
        
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
    
    private func configureDisplayMode() async -> DisplayMode {
        guard let metadata = await client.metadata,
              let version = metadata["NSPersistenceFrameworkVersion"] as? Int else {
            return .SQLite
        }
        
        return version > 800 ? .SwiftData : .CoreData
    }
    
    // MARK: - Record Actions
    
    private func requestAddRecord() {
        // Trigger add record in ContentView
        NotificationCenter.default.post(name: .addRecordRequested, object: nil)
    }
    
    private func requestDeleteRecords() {
        // Trigger delete confirmation in ContentView
        NotificationCenter.default.post(name: .deleteRecordsRequested, object: nil)
    }
}

extension Notification.Name {
    static let deleteRecordsRequested = Notification.Name("deleteRecordsRequested")
    static let addRecordRequested = Notification.Name("addRecordRequested")
    static let saveRecordsRequested = Notification.Name("saveRecordsRequested")
}

#Preview {
    DatabaseView<SQLiteTable>(
        database: Database(
            name: "Sample Database",
            filePath: "/path/to/sample.db"
        )
    )
    .environment(DatabasesManager())
    .environment(SimulatorsManager())
}
