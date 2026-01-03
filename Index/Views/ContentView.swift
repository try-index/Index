//
//  Content.swift
//  Data Inspector
//
//  Created by Axel Martinez on 13/11/24.
//

import Combine
import SQLiteKit
import SwiftUI

struct ContentView<T: SQLiteTable>: View {
    @EnvironmentObject var sqlManager: SQLiteManager

    @Binding var searchText: String
    
    @State private var isLoading = false
    @State private var selectedRecords = Set<UUID>()
    @State private var properties = [Property]()
    @State private var records = [Record]()
    @State private var error: SQLiteError? = nil
    @State private var showAlert = false
    
    let tableFont: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular)
    
    var dataObject: T
    var refresh: PassthroughSubject<Void, Never>
    
    var filteredRecords: [Record] {
        return records.filter({ record in
            self.searchText.isEmpty || record.values.contains(where: {
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
                ProgressView()
            } else {
                if records.isEmpty {
                    ContentUnavailableView("No records to show", image: "table.xmark")
                } else {
                    HStack(alignment: .center, spacing: 10) {
                        Spacer()
                        
                        Button(action: {}, label: {
                            Image(systemName: "plus")
                        })
                        .disabled(true)
                        .buttonStyle(.link)
                        
                        Button(action: removeRecords, label: {
                            Image(systemName: "trash")
                        })
                        .buttonStyle(.link)
                        .disabled(selectedRecords.isEmpty)
                        
                        Button(action: removeRecords, label: {
                            Image(systemName: "info")
                        })
                        .disabled(true)
                        .buttonStyle(.link)
                        
                        Spacer()
                    }
                    .font(.headline)
                    .padding(.vertical)
                    .background(.white)
                    
                    Table(filteredRecords, selection: $selectedRecords) {
                        TableColumnForEach(properties, id:\.name) { property in
                            TableColumn(
                                Text("""
                                \(Text(property.name).foregroundColor(XcodeThemeColors.property)): \
                                \(Text(property.type).foregroundColor(XcodeThemeColors.type))
                                """)
                            ) { record in
                                if let value = record.values[property.column.name] {
                                    CellView(value: value)
                                        .padding(.vertical, 5)
                                }
                            }
                            .width(min: property.displayName.estimatedWidth(using: tableFont))
                        }
                    }
                    .font(Font(tableFont))
                    .alternatingRowBackgrounds(.disabled)
                    .onKeyPress { event in
                        switch event.key {
                        case "\u{7f}", .delete:
                            removeRecords()
                            return .handled
                        default:
                            return .ignored
                        }
                    }
                }
            }
        }
        .onAppear(perform: refreshRecords)
        .onChange(of: dataObject, refreshRecords)
        .onReceive(refresh, perform: refreshRecords)
        .alert(isPresented: $showAlert, error: error) { _ in
            Button("OK") {
                self.showAlert = false
            }
        } message: { error in
            Text(error.recoverySuggestion ?? "Try opening a different file")
        }
    }
    
    func refreshRecords() {
        Task(priority: .userInitiated) {
            do {
                self.isLoading = true
                
                if let model = dataObject as? Model {
                    self.properties = model.properties.map(\.value).sorted { $0.name < $1.name }
                    self.records = try await sqlManager.getRecords(from: model)
                } else if let entity = dataObject as? Entity {
                    self.properties = entity.properties.map(\.value).sorted { $0.name < $1.name }
                    self.records = try await sqlManager.getRecords(from: entity)
                } else {
                    self.properties = dataObject.columns.map {
                        Property(column: $0)
                    }.sorted { $0.name < $1.name }
                    
                    self.records = try await sqlManager.getRecords(from: dataObject)
                }
                
                self.isLoading = false
            } catch let error as SQLiteError{
                self.error = error
                self.showAlert = true
            }
        }
    }
    
    func removeRecords() {
        guard selectedRecords.isEmpty else { return }
        
        Task(priority: .userInitiated) {
            do {
                let recordsToDelete = records.filter { selectedRecords.contains($0.id) }
                
                // Delete records from the database
                try await sqlManager.deleteRecords(recordsToDelete, from: dataObject)
                
                await MainActor.run {
                    // Remove the records from the local array
                    records.removeAll { selectedRecords.contains($0.id) }
                    
                    // Clear selection
                    selectedRecords.removeAll()
                }
            } catch let error as SQLiteError {
                self.error = error
                self.showAlert = true
            }
        }
    }
    
    func updateRecord(id: UUID, columnName: String, to newValue: Value) {
        // Find the index of the current record
        if var record = records.first(where: { $0.id == id }) {
            Task {
                // Update the value the fetched record
                record.values[columnName] = newValue
                
                // Update in database
                do {
                    try await sqlManager.updateRecord(
                        record,
                        for: columnName,
                        from: dataObject
                    )
                } catch let error as SQLiteError {
                    self.error = error
                    self.showAlert = true
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var searchText: String = ""
    @Previewable @State var refresh: PassthroughSubject<Void, Never> = .init()
    
    let table = SQLiteTable(name: "test", columns: [], recordCount: 0)
    
    ContentView(searchText: $searchText, dataObject: table,  refresh: refresh)
}
