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
    @Environment(\.dismiss) var dismiss
    @Environment(\.openWindow) var openWindow
    @Environment(DatabasesManager.self) var databasesManager
    @Environment(SimulatorsManager.self) var simManager
    
    let database: Database
    
    @State var tabs: [TabItem<T>] = []
    @State var selectedTab: TabItem<T>?
    @State var client = SQLiteClient()
    @State var databaseError: String?
    @State var showDatabaseError = false
    @State var displayMode: DisplayMode = .SQLite
    @State var isConnected = false
    @State var isReadOnly = false
    
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedTable: T?
    @State private var searchText: String = ""
    @State private var selectedRecordsCount = 0
    @State private var isFileMenuVisible = false
    @State private var isUtilityExpanded = false
    @State private var refreshContentPublisher: PassthroughSubject<Void, Never> = .init()
    @State private var addRecordPublisher: PassthroughSubject<Void, Never> = .init()
    @State private var deleteRecordsPublisher: PassthroughSubject<Void, Never> = .init()
    @State private var saveRecordsPublisher: PassthroughSubject<Void, Never> = .init()
    
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
                                onClose: closeTab
                            )
                        }
                        
                        // Tab content
                        if let selectedTab = selectedTab {
                            VStack(spacing: 0) {
                                ContentView(
                                    client: client,
                                    dataObject: selectedTab.table,
                                    refreshPublisher: refreshContentPublisher,
                                    addRecordPublisher: addRecordPublisher,
                                    deleteRecordsPublisher: deleteRecordsPublisher,
                                    saveRecordsPublisher: saveRecordsPublisher,
                                    filterColumn: selectedTab.filterColumn,
                                    filterValue: selectedTab.filterValue,
                                    onOpenRelatedTable: openRelatedTable,
                                    searchText: $searchText,
                                    isUtilityExpanded: $isUtilityExpanded,
                                    selectedRecordsCount: $selectedRecordsCount,
                                    isReadOnly: isReadOnly,
                                    displayMode: displayMode
                                )
                                
                                // Utility drawer
                                UtilityView(
                                    sqlQuery: selectedTab.sqlQuery,
                                    isExpanded: $isUtilityExpanded
                                )
                            }
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
                        Button {
                            isFileMenuVisible.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Text(fileURL.lastPathComponent)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .popover(isPresented: $isFileMenuVisible, arrowEdge: .bottom, content: {
                            FileMenu(fileURL: fileURL)
                                .frame(minWidth: 200,  maxWidth: 400, minHeight: 100)
                                .presentationCompactAdaptation(.popover)
                        })
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        HStack(spacing: 8) {
                            if isReadOnly {
                                Text("READ ONLY")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary)
                                    .clipShape(Capsule())
                                    .padding(.leading, 8)
                            } else {
                                Button("", systemImage: "plus", action: {
                                    addRecordPublisher.send()
                                })
                                .disabled(selectedTab == nil)
                                .help("Add Record")
                                
                                Button("", systemImage: "trash", action: {
                                    deleteRecordsPublisher.send()
                                })
                                .disabled(selectedRecordsCount == 0)
                                .help("Delete Selected Records (\(selectedRecordsCount))")
                            }
                            
                            Divider()
                                .frame(height: 16)
                            
                            Button("", systemImage: "arrow.clockwise", action: {
                                refreshContentPublisher.send()
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
        .task {
            await openDatabase()
        }
        .onDisappear {
            Task {
                await closeDatabase()
            }
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
