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

    @EnvironmentObject var databasesManager: DatabasesManager
    @EnvironmentObject var simManager: SimulatorsManager

    let databaseId: Database.ID

    @State private var client = SQLiteClient()
    @State private var accessedFolderURL: URL?
    @State private var databaseError: String?
    @State private var displayMode: DisplayMode = .SQLite
    @State private var openFileURL: URL?
    @State private var showDatabaseError = false
    @State private var isConnected = false
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedTable: T?
    @State private var searchText: String = ""
    @State private var refreshContent: PassthroughSubject<Void, Never> = .init()

    var body: some View {
        Group {
            if isConnected {
                NavigationSplitView(columnVisibility: $sidebarVisibility) {
                    DatabaseSidebar(
                        client: client,
                        displayMode: displayMode,
                        openFileURL: openFileURL,
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
                        PathIndicator(openFileURL: openFileURL)
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
            connectToDatabase()
        }
        .onDisappear {
            cleanupDatabase()
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

    private func connectToDatabase() {
        guard let database = databasesManager.recentDatabases.first(where: { $0.id == databaseId }) else {
            databaseError = "Database not found. It may have been deleted."
            showDatabaseError = true
            return
        }

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

            accessedFolderURL?.stopAccessingSecurityScopedResource()
            accessedFolderURL = url

            do {
                try await client.connect(to: url)
                databasesManager.updateLastOpened(for: database)

                let mode = await determineDisplayMode()

                await MainActor.run {
                    displayMode = mode
                    openFileURL = url
                    isConnected = true
                }
            } catch {
                url.stopAccessingSecurityScopedResource()

                await MainActor.run {
                    databaseError = error.localizedDescription
                    showDatabaseError = true
                }
            }
        }
    }

    private func determineDisplayMode() async -> DisplayMode {
        guard let metadata = await client.metadata,
              let version = metadata["NSPersistenceFrameworkVersion"] as? Int else {
            return .SQLite
        }

        return version > 800 ? .SwiftData : .CoreData
    }

    private func cleanupDatabase() {
        accessedFolderURL?.stopAccessingSecurityScopedResource()

        Task {
            try? await client.close()
        }
    }
}

#Preview {
    DatabaseView<SQLiteTable>(databaseId: UUID())
}
