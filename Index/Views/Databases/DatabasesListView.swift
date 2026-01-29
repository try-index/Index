//
//  DatabasesListView.swift
//  Index
//
//  Created by Axel Martinez on 27/1/26.
//

import SwiftUI

struct DatabasesListView: View {
    @EnvironmentObject var databasesManager: DatabasesManager

    let databases: [Database]
    let onOpen: (Database) -> Void
    let onRemove: (Database) -> Void

    @Binding var selectedDatabase: Database?

    @State private var selectedDatabaseID: Database.ID?
    @State private var databaseToEdit: Database?

    var body: some View {
        Table(of: Database.self, selection: $selectedDatabaseID) {
            TableColumn("") { (database: Database) in
                DatabaseRow(
                    database: database,
                    isSelected: selectedDatabaseID == database.id,
                    onConnect: { onOpen(database) },
                    onEdit: { databaseToEdit = database }
                )
                .frame(height: 44)
            }
        } rows: {
            ForEach(databases) { database in
                TableRow(database)
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
        .tableColumnHeaders(.hidden)
        .environment(\.defaultMinListRowHeight, 44)
        .onChange(of: selectedDatabaseID) { _, newValue in
            selectedDatabase = databases.first { $0.id == newValue }
        }
        .onChange(of: selectedDatabase) { _, newValue in
            selectedDatabaseID = newValue?.id
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
