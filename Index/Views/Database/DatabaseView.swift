//
//  DatabaseView.swift
//  Index
//
//  Created by Axel Martinez on 13/11/24.
//

import Combine
import SwiftUI

struct DatabaseView<T: SQLiteTable>: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @Environment(DatabasesManager.self) var databasesManager
    @Environment(SimulatorsManager.self) var simManager

    let database: Database
    
    @State private var client = SQLiteClient()
    @State private var accessedFolderURL: URL?
    @State private var databaseError: String?
    @State private var displayMode: DisplayMode = .SQLite
    @State private var isFileMenuVisible: Bool = false
    @State private var showDatabaseError = false
    @State private var isConnected = false
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedTable: T?
    @State private var searchText: String = ""
    @State private var refreshContent: PassthroughSubject<Void, Never> = .init()
    
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
                        selection: $selectedTable
                    )
                } detail: {
                    if let selectedTable = selectedTable {
                        ContentView(
                            client: client,
                            searchText: $searchText,
                            dataObject: selectedTable,
                            refresh: refreshContent
                        )
                    } else {
                        ContentUnavailableView {
                            Label("Select a Table", systemImage: "tablecells")
                        } description: {
                            Text("Choose a table from the sidebar to view its contents.")
                        }
                    }
                }
                .searchable(text: $searchText)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
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
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        Button("", systemImage: "arrow.clockwise", action: {
                            refreshContent.send()
                        })
                        .disabled(self.selectedTable == nil)
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
        .alert("Database Error", isPresented: $showDatabaseError) {
            Button("Close") {
                dismiss()
            }
        } message: {
            Text(databaseError ?? "Failed to open the database file.")
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
            guard url.startAccessingSecurityScopedResource() else {
                await MainActor.run {
                    databaseError = "Could not access the file. Permission denied."
                    showDatabaseError = true
                }
                return
            }
            
            accessedFolderURL = url
            
            do {
                try await client.connect(to: url)
                
                databasesManager.updateLastOpened(for: database)
                
                let mode = await configureDisplayMode()
                
                await MainActor.run {
                    displayMode = mode
                    isConnected = true
                }
            } catch {
                await MainActor.run {
                    databaseError = error.localizedDescription
                    showDatabaseError = true
                }
            }
            
            accessedFolderURL?.stopAccessingSecurityScopedResource()
        }
    }
    
    private func closeDatabase() {
        accessedFolderURL?.stopAccessingSecurityScopedResource()
        
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
}

#Preview {
    /*DatabaseView<SQLiteTable>(
     database: Database(),
     fileURL: URL(fileURLWithPath: "test")
     )*/
}
