//
//  ContentView.swift
//  Index
//
//  Created by Axel Martinez on 13/11/24.
//

import Combine
import SQLiteKit
import SwiftUI

struct ContentView<T: SQLiteTable>: View {
    let client: SQLiteClient

    @State var records = [Record]()
    @State var selectedRecords = Set<UUID>()
    @State var newRecords = [Record]() // Temporary unsaved records
    @State var editingRecordId: UUID? // Track which record is being edited
    @State var error: SQLiteError? = nil
    @State var showAlert = false
    @State var properties = [Property]()
    @State var showDeleteConfirmation = false

    @State private var isLoading = false

    let tableFont: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular)

    var dataObject: T
    var refreshPublisher: PassthroughSubject<Void, Never>
    var addRecordPublisher: PassthroughSubject<Void, Never>
    var deleteRecordsPublisher: PassthroughSubject<Void, Never>
    var saveRecordsPublisher: PassthroughSubject<Void, Never>
    var filterColumn: String?
    var filterValue: Value?
    var onOpenRelatedTable: ((T, String, Value) -> Void)?
    
    @Binding var searchText: String
    @Binding var isUtilityExpanded: Bool
    @Binding var selectedRecordsCount: Int
    
    var isReadOnly: Bool = false
    var displayMode: DisplayMode = .SQLite

    var filteredRecords: [Record] {
        // Combine new records with existing records (new records at the bottom)
        let allRecords = records + newRecords
        
        return allRecords.filter({ record in
            // Apply column filter if specified
            if let filterColumn = filterColumn, let filterValue = filterValue {
                guard let recordValue = record.values[filterColumn],
                      recordValue == filterValue else {
                    return false
                }
            }
            
            // Apply search text filter
            return self.searchText.isEmpty || record.values.contains(where: {
                switch($0.value){
                case .text(let text):
                    return text.contains(self.searchText)
                default:
                    return false
                }
            })
        })
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ZStack {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                    ProgressView()
                }
            } else if records.isEmpty && newRecords.isEmpty {
                ZStack {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                    ContentUnavailableView("No records to show", image: "table.xmark")
                }
            } else {
                VStack(spacing: 0) {
                    TableView(
                        records: filteredRecords,
                        properties: properties,
                        isReadOnly: isReadOnly,
                        displayMode: displayMode,
                        newRecordIds: Set(newRecords.map { $0.id }),
                        selectedRecords: $selectedRecords,
                        scrollToRecordId: editingRecordId,
                        onUpdate: { recordId, columnName, newValue in
                            updateRecord(id: recordId, columnName: columnName, to: newValue)
                        },
                        onForeignKeyClick: onOpenRelatedTable != nil ? { fk, value, record in
                            handleForeignKeyClick(foreignKey: fk, value: value, callback: onOpenRelatedTable!)
                        } : nil,
                        onRowDeselected: { recordId in
                            // Only validate when the entire row is deselected (user clicked away)
                            if newRecords.contains(where: { $0.id == recordId }) {
                                validateAndSaveOrRemoveRecord(recordId)
                            }
                            
                            editingRecordId = nil
                        },
                        onEnterPressed: { recordId in
                            // Save record when user presses enter
                            if newRecords.contains(where: { $0.id == recordId }) {
                                validateAndSaveOrRemoveRecord(recordId)
                            }
                        }
                    )
                    
                    StatusBar(
                        recordCount: records.count,
                        filteredCount: filteredRecords.count,
                        tableName: (dataObject as? Entity)?.displayName ?? dataObject.name,
                        unsavedCount: newRecords.count,
                        isReadOnly: isReadOnly,
                        saveRecords: saveRecordsPublisher,
                        isUtilityExpanded: $isUtilityExpanded
                    )
                }
            }
        }
        .onAppear(perform: refreshRecords)
        .onChange(of: dataObject, refreshRecords)
        .onReceive(refreshPublisher, perform: refreshRecords)
        .onChange(of: selectedRecords) { _, newValue in
            selectedRecordsCount = newValue.count
        }
        .onReceive(deleteRecordsPublisher) { _ in
            confirmDeleteRecords()
        }
        .onReceive(addRecordPublisher) { _ in
            addEmptyRecord()
        }
        .onReceive(saveRecordsPublisher) { _ in
            saveNewRecords()
        }
        .alert(isPresented: $showAlert, error: error) { _ in
            Button("OK") {
                self.showAlert = false
            }
        } message: { error in
            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
            } else {
                // Provide context-appropriate recovery suggestions
                let errorMessage = error.localizedDescription.lowercased()
                
                if errorMessage.contains("constraint") {
                    Text("This change violates a database constraint. Check foreign key references or unique constraints.")
                } else if errorMessage.contains("readonly") || errorMessage.contains("read-only") {
                    Text("The database is read-only. Check file permissions or open in write mode.")
                } else if errorMessage.contains("locked") {
                    Text("The database is locked by another process. Close other connections and try again.")
                } else {
                    Text("Please check your input and try again.")
                }
            }
        }
        .alert("Delete Records", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteRecords()
            }
        } message: {
            Text("Are you sure you want to delete \(selectedRecords.count) record(s)? This action cannot be undone.")
        }
        .onKeyPress { event in
            // Check for Escape key to cancel new record creation
            if event.key == .escape, let editingId = editingRecordId, 
               newRecords.contains(where: { $0.id == editingId }) {
                // Remove the new record being edited
                newRecords.removeAll { $0.id == editingId }
                selectedRecords.remove(editingId)
                editingRecordId = nil
                return .handled
            }
            
            // Check for Command+S to save new records (only in editable mode)
            if event.key == "s" && event.modifiers.contains(.command) && !isReadOnly && !newRecords.isEmpty {
                saveNewRecords()
                return .handled
            }
            return .ignored
        }
    }

    func refreshRecords() {
        isLoading = true
        
        Task(priority: .userInitiated) {
            do {
                var loadedProperties = [Property]()
                var loadedRecords = [Record]()

                if let model = dataObject as? Model {
                    loadedProperties = model.properties.map(\.value).sorted { $0.name < $1.name }
                    loadedRecords = try await client.getRecords(from: model)
                } else if let entity = dataObject as? Entity {
                    loadedProperties = entity.properties.map(\.value).sorted { $0.name < $1.name }
                    loadedRecords = try await client.getRecords(from: entity)
                } else {
                    loadedProperties = dataObject.columns.map {
                        Property(column: $0)
                    }.sorted { $0.name < $1.name }

                    loadedRecords = try await client.getRecords(from: dataObject)
                }

                await MainActor.run {
                    self.properties = loadedProperties
                    self.records = loadedRecords
                    self.isLoading = false
                }
            } catch let error as SQLiteError {
                await MainActor.run {
                    self.error = error
                    self.showAlert = true
                    self.isLoading = false
                }
            } catch {
                print("Failed to load records: \(error)")
                
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }

    private func valueToString(_ value: Value) -> String {
        switch value {
        case .null:
            return "NULL"
        case .undefined:
            return ""
        case .integer(let int):
            return "\(int)"
        case .smallint(let int):
            return "\(int)"
        case .real(let double):
            return "\(double)"
        case .float(let float):
            return "\(float)"
        case .text(let string):
            return string
        case .uuid(let uuid):
            return uuid.uuidString
        case .data(let string):
            return string
        case .enumValue(let caseName):
            return ".\(caseName)"
        case .timestamp(let date):
            return date.ISO8601Format()
        case .array, .image:
            return "<DATA>"
        }
    }
    
    private func handleForeignKeyClick(
        foreignKey: SQLiteColumn.ForeignKey,
        value: Value,
        callback: @escaping (T, String, Value) -> Void
    ) {
        // Find the related table
        Task {
            do {
                // Get all tables to find the one referenced by the foreign key
                let tables: [T]
                
                if dataObject is Model {
                    tables = try await client.getModels() as? [T] ?? []
                } else if dataObject is Entity {
                    tables = try await client.getEntities() as? [T] ?? []
                } else {
                    tables = try await client.getTables() as? [T] ?? []
                }
                
                // Find the referenced table
                if let relatedTable = tables.first(where: { table in
                    if let entity = table as? Entity {
                        return entity.displayName == foreignKey.table
                    }
                    return table.name.uppercased() == "Z\(foreignKey.table.uppercased())" || 
                           table.name == foreignKey.table
                }) {
                    await MainActor.run {
                        callback(relatedTable, foreignKey.column, value)
                    }
                }
            } catch {
                print("Failed to load related table: \(error)")
            }
        }
    }
}

#Preview {
    @Previewable @State var searchText: String = ""
    @Previewable @State var refresh: PassthroughSubject<Void, Never> = .init()
    @Previewable @State var addRecord: PassthroughSubject<Void, Never> = .init()
    @Previewable @State var deleteRecords: PassthroughSubject<Void, Never> = .init()
    @Previewable @State var saveRecords: PassthroughSubject<Void, Never> = .init()
    @Previewable @State var isUtilityExpanded = false
    @Previewable @State var selectedRecordsCount = 0

    let table = SQLiteTable(name: "test", columns: [], recordCount: 0)

    ContentView(
        client: SQLiteClient(),
        dataObject: table,
        refreshPublisher: refresh,
        addRecordPublisher: addRecord,
        deleteRecordsPublisher: deleteRecords,
        saveRecordsPublisher: saveRecords,
        searchText: $searchText,
        isUtilityExpanded: $isUtilityExpanded,
        selectedRecordsCount: $selectedRecordsCount
    )
}
