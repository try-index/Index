//
//  DatabasesGridView.swift
//  Index
//
//  Created by Axel Martinez on 27/1/26.
//

import SwiftUI

struct DatabasesGridView: View {
    @EnvironmentObject var databasesManager: DatabasesManager

    let databases: [Database]
    @Binding var selectedDatabase: Database?

    let onOpen: (Database) -> Void
    let onRemove: (Database) -> Void

    @State private var databaseToEdit: Database?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 16)], spacing: 16) {
                ForEach(databases) { database in
                    DatabaseIcon(
                        database: database,
                        isSelected: selectedDatabase?.id == database.id,
                        onOpen: { onOpen(database) },
                        onEdit: { databaseToEdit = database },
                        onRemove: { onRemove(database) }
                    )
                    .simultaneousGesture(
                        TapGesture(count: 2).onEnded {
                            onOpen(database)
                        }
                    )
                    .simultaneousGesture(
                        TapGesture(count: 1).onEnded {
                            selectedDatabase = database
                        }
                    )
                    .contextMenu {
                        Button("Open") {
                            onOpen(database)
                        }

                        Button("Edit...") {
                            databaseToEdit = database
                        }

                        if !databasesManager.groups.isEmpty {
                            Divider()

                            Menu("Move to Group") {
                                Button("No Group") {
                                    databasesManager.moveDatabase(database, to: nil)
                                }
                                Divider()
                                ForEach(databasesManager.groups) { group in
                                    Button(group.name) {
                                        databasesManager.moveDatabase(database, to: group)
                                    }
                                }
                            }
                        }

                        Divider()

                        Button("Delete", role: .destructive) {
                            onRemove(database)
                        }
                    }
                }
            }
            .padding(16)
        }
        .sheet(item: $databaseToEdit) { database in
            EditDatabaseView(
                database: database,
                onSave: { updatedDatabase in
                    databasesManager.updateDatabase(updatedDatabase)
                    databaseToEdit = nil
                },
                onCancel: {
                    databaseToEdit = nil
                }
            )
        }
    }
}
