//
//  EditDatabaseView.swift
//  Index
//
//  Created by Axel Martinez on 27/1/26.
//

import SwiftUI

struct EditDatabaseView: View {
    let database: Database
    let onSave: (Database) -> Void
    let onCancel: () -> Void

    @State private var displayName: String

    init(database: Database, onSave: @escaping (Database) -> Void, onCancel: @escaping () -> Void) {
        self.database = database
        self.onSave = onSave
        self.onCancel = onCancel
        
        self._displayName = State(initialValue: database.name)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Display Name", text: $displayName)

                LabeledContent("Path") {
                    Text(database.filePath)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                LabeledContent("Last Opened") {
                    Text(database.lastOpened, format: .dateTime.month().day().year().hour().minute())
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .padding()

            Spacer()

            Divider()

            // Footer
            HStack {
                Spacer()

                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    var updatedDatabase = database
                    updatedDatabase.name = displayName
                    onSave(updatedDatabase)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(displayName.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 400, height: 300)
    }
}
