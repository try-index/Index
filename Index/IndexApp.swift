//
//  IndexApp.swift
//  Index
//
//  Created by Axel Martinez on 12/12/24.
//

import SwiftUI

@main
struct IndexApp: App {
    @StateObject private var databasesManager = DatabasesManager()
    @StateObject private var simManager = SimulatorsManager()

    @Environment(\.openWindow) private var openWindow

    init() {
        // Rename File menu to Database after a slight delay to ensure menu is created
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            Self.renameFileMenuToDatabase()
        }
    }

    var body: some Scene {
        // Databases window - shows on launch
        Window("Databases", id: "databases") {
            DatabasesView()
                .environmentObject(databasesManager)
                .environmentObject(simManager)
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                }
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        // Database windows - one per database
        WindowGroup(for: Database.ID.self) { $databaseId in
            if let databaseId = databaseId,
               let database = databasesManager.recentDatabases.first(where: { $0.id == databaseId }) {
                DatabaseView<SQLiteTable>(database: database)
                    .environmentObject(databasesManager)
                    .environmentObject(simManager)
                    .onAppear {
                        NSWindow.allowsAutomaticWindowTabbing = false
                    }
            }
        }
        .commands {
            // Replace File menu with Database menu
            CommandGroup(replacing: CommandGroupPlacement.newItem) {
                Button {
                    openDatabase()
                } label: {
                    Label("Open...", systemImage: "cylinder.split.1x2")
                }
                .keyboardShortcut("o", modifiers: [.command])

                // Recents submenu
                Menu {
                    if databasesManager.recentDatabases.isEmpty {
                        Text("No Recent Databases")
                    } else {
                        ForEach(databasesManager.recentDatabases) { database in
                            Button {
                                openRecentDatabase(database)
                            } label: {
                                Label(database.displayName, systemImage: "doc")
                            }
                        }

                        Divider()

                        Button {
                            databasesManager.clearAll()
                        } label: {
                            Label("Clear Recents", systemImage: "trash")
                        }
                    }
                } label: {
                    Label("Open Recent", systemImage: "clock")
                }

                Divider()

                Button {
                    NSApplication.shared.keyWindow?.close()
                } label: {
                    Label("Close", systemImage: "xmark")
                }
                .keyboardShortcut("w", modifiers: [.command])
            }

            // Hide other File menu items we don't need
            CommandGroup(replacing: .saveItem) {
                EmptyView()
            }

            CommandGroup(replacing: .printItem) {
                EmptyView()
            }

            // Add to Window menu
            CommandGroup(after: .windowList) {
                Divider()
                Button {
                    openDatabase()
                } label: {
                    Label("Show Databases Window", systemImage: "macwindow")
                }
                .keyboardShortcut("0", modifiers: [.command])
            }
        }
    }

    private func openDatabase() {
        // Show the open modal
        databasesManager.showOpenModal = true

        // Ensure the databases window is visible
        if let window = NSApp.windows.first(where: { $0.title == "Databases" }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            openWindow(id: "databases")
        }
    }

    private func openRecentDatabase(_ database: Database) {
        openWindow(value: database.id)
    }
}
