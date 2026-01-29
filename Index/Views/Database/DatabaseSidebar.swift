//
//  DatabaseSidebar.swift
//  Index
//
//  Created by Axel Martinez on 13/11/24.
//

import SwiftUI
import SQLiteKit

struct DatabaseSidebar<T: SQLiteTable>: View {
    let client: SQLiteClient
    let displayMode: DisplayMode
    let openFileURL: URL?

    @Binding var selection: T?

    @State private var dataObjects = [T]()
    @State private var error: SQLiteError? = nil
    @State private var showAlert = false

    var body: some View {
        VStack {
            List(selection: $selection) {
                switch displayMode {
                case .SwiftData:
                    if let models = dataObjects as? [Model], !models.isEmpty {
                        Section(header: Text("Models")) {
                            ForEach(models, id: \.self) { model in
                                HStack {
                                    Label(model.displayName, systemImage: "swiftdata")
                                    Spacer()
                                    Text("\(model.recordCount)")
                                }
                            }
                        }
                    }
                case .CoreData:
                    if let entities = dataObjects as? [Entity], !entities.isEmpty {
                        Section(header: Text("Entities")) {
                            ForEach(entities, id: \.self) { entity in
                                HStack {
                                    Label(entity.displayName, systemImage: "e.square")
                                    Spacer()
                                    Text("\(entity.recordCount)")
                                }
                            }
                        }
                    }
                default:
                    if !dataObjects.isEmpty {
                        Section(header: Text("Tables")) {
                            ForEach(dataObjects, id: \.self) { dataObject in
                                HStack {
                                    Label(dataObject.name, systemImage: "tablecells")
                                    Spacer()
                                    Text("\(dataObject.recordCount)")
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
        }
        .alert(isPresented: $showAlert, error: error) { _ in
            Button("OK") {
                self.showAlert = false
            }
        } message: { error in
            Text(error.recoverySuggestion ?? "Try opening a different file")
        }
        .onAppear {
            loadData()
        }
        .onChange(of: openFileURL) { _, _ in
            loadData()
        }
    }

    private func loadData() {
        guard openFileURL != nil else { return }

        Task {
            do {
                var loadedObjects = [T]()

                switch displayMode {
                case .SwiftData:
                    if let models = try await client.getModels() as? [T] {
                        loadedObjects = models
                    }
                case .CoreData:
                    if let entities = try await client.getEntities() as? [T] {
                        loadedObjects = entities
                    }
                default:
                    if let tables = try await client.getTables() as? [T] {
                        loadedObjects = tables
                    }
                }

                await MainActor.run {
                    self.dataObjects = loadedObjects
                    self.selection = loadedObjects.first
                }
            } catch let error as SQLiteError {
                await MainActor.run {
                    self.error = error
                    self.showAlert = true
                }
            } catch {
                print("Failed to load data: \(error)")
            }
        }
    }
}

#Preview {
    @Previewable @State var selection: SQLiteTable?

    DatabaseSidebar<SQLiteTable>(
        client: SQLiteClient(),
        displayMode: .SQLite,
        openFileURL: nil,
        selection: $selection
    )
}
