//
//  DatabasesView.swift
//  Index
//
//  Created by Axel Martinez on 27/01/26.
//

import SwiftUI

/// Sidebar selection item
enum SidebarItem: Hashable {
    case allDatabases
    case group(DatabaseGroup)
}

/// Display mode for databases
enum DatabasesDisplayMode: String, CaseIterable {
    case list
    case icons
}

struct DatabasesView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @EnvironmentObject var databasesManager: DatabasesManager
    @EnvironmentObject var simManager: SimulatorsManager

    @State private var showOpenDatabaseModal = false
    @State private var showSimulatorsModal = false
    @State private var showNewGroupAlert = false
    @State private var newGroupName = ""
    @State private var selectedSidebarItem: SidebarItem? = .allDatabases
    @State private var selectedDatabase: Database?
    @State private var databaseError: String?
    @State private var showDatabaseError = false
    @State private var searchText: String = ""
    @State private var displayMode: DatabasesDisplayMode = .list

    private var filteredDatabases: [Database] {
        let baseDatabases: [Database]

        switch selectedSidebarItem {
        case .allDatabases, .none:
            baseDatabases = databasesManager.recentDatabases
        case .group(let group):
            baseDatabases = databasesManager.databases(for: group)
        }

        if searchText.isEmpty {
            return baseDatabases
        }
        return baseDatabases.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.filePath.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationSplitView {
            DatabasesSidebar(
                selectedSidebarItem: $selectedSidebarItem,
                onAddGroup: { showNewGroupAlert = true },
                onDeleteGroup: deleteSelectedGroup
            )
            .environmentObject(databasesManager)
        } detail: {
            // Main content
            if databasesManager.recentDatabases.isEmpty {
                emptyStateView
            } else if filteredDatabases.isEmpty {
                noResultsView
            } else {
                switch displayMode {
                case .list:
                    DatabasesListView(
                        databases: filteredDatabases,
                        onOpen: openRecentDatabase,
                        onRemove: removeRecentDatabase,
                        selectedDatabase: $selectedDatabase
                    )
                    .environmentObject(databasesManager)
                case .icons:
                    DatabasesGridView(
                        databases: filteredDatabases,
                        selectedDatabase: $selectedDatabase,
                        onOpen: openRecentDatabase,
                        onRemove: removeRecentDatabase
                    )
                    .environmentObject(databasesManager)
                }
            }
        }
        .navigationTitle(navigationTitle)
        .searchable(text: $searchText, placement: .toolbar)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Display mode picker
                Picker("Display Mode", selection: $displayMode) {
                    Image(systemName: "square.grid.2x2")
                        .tag(DatabasesDisplayMode.icons)
                    Image(systemName: "list.bullet")
                        .tag(DatabasesDisplayMode.list)
                }
                .pickerStyle(.segmented)
                .help("Switch between list and icon view")

                // Actions menu
                Menu {
                    Button("Open") {
                        if let database = selectedDatabase {
                            openRecentDatabase(database)
                        }
                    }
                    .disabled(selectedDatabase == nil)

                    Divider()

                    if !databasesManager.groups.isEmpty {
                        Menu("Move to Group") {
                            Button("No Group") {
                                if let database = selectedDatabase {
                                    databasesManager.moveDatabase(database, to: nil)
                                }
                            }
                            Divider()
                            ForEach(databasesManager.groups) { group in
                                Button(group.name) {
                                    if let database = selectedDatabase {
                                        databasesManager.moveDatabase(database, to: group)
                                    }
                                }
                            }
                        }
                        .disabled(selectedDatabase == nil)

                        Divider()
                    }

                    Button("Delete", role: .destructive) {
                        if let database = selectedDatabase {
                            databasesManager.removeDatabase(database)
                            selectedDatabase = nil
                        }
                    }
                    .disabled(selectedDatabase == nil)

                    Divider()

                    Button("Clear All Recents", role: .destructive) {
                        databasesManager.clearAll()
                        selectedDatabase = nil
                    }
                    .disabled(databasesManager.recentDatabases.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .help("Actions")

                // Add button
                Button(action: { showOpenDatabaseModal = true }) {
                    Image(systemName: "plus")
                }
                .help("Open Database")
            }
        }
        .frame(minWidth: 600, idealWidth: 700, minHeight: 400, idealHeight: 500)
        .sheet(isPresented: $showOpenDatabaseModal) {
            OpenDatabaseView(
                onFileSelected: { url, forceReadOnly in
                    openDatabase(url: url, forceReadOnly: forceReadOnly)
                },
                onBrowseSimulators: {
                    showOpenDatabaseModal = false
                    showSimulatorsModal = true
                }
            )
        }
        .sheet(isPresented: $showSimulatorsModal) {
            SimulatorsView(
                sidebarVisibility: .constant(.all),
                onDatabaseOpened: { database in
                    openWindow(value: database.id)
                    dismissWindow(id: "databases")
                }
            )
            .environmentObject(simManager)
            .environmentObject(databasesManager)
        }
        .alert("New Group", isPresented: $showNewGroupAlert) {
            TextField("Group Name", text: $newGroupName)

            Button("Cancel", role: .cancel) {
                newGroupName = ""
            }

            Button("Create") {
                if !newGroupName.isEmpty {
                    databasesManager.addGroup(name: newGroupName)
                    newGroupName = ""
                }
            }
        } message: {
            Text("Enter a name for the new group.")
        }
        .alert("Database Error", isPresented: $showDatabaseError) {
            Button("OK") { showDatabaseError = false }
        } message: {
            Text(databaseError ?? "Failed to open the database file.")
        }
        .onChange(of: databasesManager.showOpenModal) { _, newValue in
            if newValue {
                showOpenDatabaseModal = true
                databasesManager.showOpenModal = false
            }
        }
    }

    // MARK: - Computed Properties

    private var navigationTitle: String {
        switch selectedSidebarItem {
        case .allDatabases, .none:
            return "All Databases"
        case .group(let group):
            return group.name
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cylinder.split.1x2")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)

            VStack(spacing: 4) {
                Text("No Recent Databases")
                    .font(.system(size: 13, weight: .medium))

                Text("Open a database file to get started.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Button("Open Database...") {
                showOpenDatabaseModal = true
            }
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text("No Results")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func deleteSelectedGroup() {
        if case .group(let group) = selectedSidebarItem {
            databasesManager.removeGroup(group)
            selectedSidebarItem = .allDatabases
        }
    }

    private func openRecentDatabase(_ database: Database) {
        // Verify we can access the file before opening
        guard databasesManager.resolveURL(for: database) != nil else {
            databaseError = "Could not access the file. It may have been moved or deleted."
            showDatabaseError = true
            return
        }

        // Open the database window and close this window
        openWindow(value: database.id)
        dismissWindow(id: "databases")
    }

    private func removeRecentDatabase(_ database: Database) {
        databasesManager.removeDatabase(database)
        selectedDatabase = nil
    }

    private func openDatabase(url: URL, forceReadOnly: Bool) {
        // Add to databases manager first
        databasesManager.addDatabase(from: url)

        // Find the newly added database and open it
        if let database = databasesManager.recentDatabases.first(where: { $0.filePath == url.path }) {
            openWindow(value: database.id)
            dismissWindow(id: "databases")
        }
    }
}
