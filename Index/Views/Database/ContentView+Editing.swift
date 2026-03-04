//
//  ContentView+Editing.swift
//  Index
//
//  Created by Axel on 2/3/26.
//

import SwiftUI
import SQLiteNIO

extension ContentView {
    func addEmptyRecord() {
        // Create a new record with null values for all columns
        var values: [String: Value] = [:]
        
        for property in properties {
            values[property.column.name] = .null
        }
        
        let newRecord = Record(id: UUID(), values: values)
        
        newRecords.append(newRecord) // Insert at the end
        
        // Select the new record and mark it as being edited
        selectedRecords = [newRecord.id]
        editingRecordId = newRecord.id
    }
    
    func updateRecord(id: UUID, columnName: String, to newValue: Value) {
        // Check if this is a new record first
        if let newIndex = newRecords.firstIndex(where: { $0.id == id }) {
            // Update the new record locally only - don't save to database
            newRecords[newIndex].values[columnName] = newValue
            
            return
        }
        
        // Handle existing record update
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        // Keep the original record with old values for WHERE clause
        let record = records[index]
        var newRecord = record
        
        let oldValue = record.values[columnName]
        
        Task {
            // Optimistically update the UI
            await MainActor.run {
                records[index].values[columnName] = newValue
            }
            
            // Update the value in the record
            newRecord.values[columnName] = newValue

            // Update in database - use originalRecord for WHERE clause, updatedRecord for SET
            do {
                try await client.updateRecord(
                    record,
                    newRecord: newRecord,
                    for: columnName,
                    from: dataObject
                )
            } catch let error as SQLiteError {
                // Revert the optimistic update on error
                await MainActor.run {
                    records[index].values[columnName] = oldValue
                    self.error = error
                    self.showAlert = true
                }
            } catch {
                // Revert the optimistic update on any other error
                await MainActor.run {
                    records[index].values[columnName] = oldValue
                    print("Failed to update record: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func deleteRecords() {
        guard !selectedRecords.isEmpty else {
            return
        }

        // Check if any selected records are new (unsaved)
        let newRecordsToDelete = newRecords.filter { selectedRecords.contains($0.id) }
        let existingRecordsToDelete = records.filter { selectedRecords.contains($0.id) }
        
        // Remove new records immediately (they're not in the database)
        if !newRecordsToDelete.isEmpty {
            newRecords.removeAll { selectedRecords.contains($0.id) }
        }
        
        // Delete existing records from database
        if !existingRecordsToDelete.isEmpty {
            Task(priority: .userInitiated) {
                do {
                    // Delete records from the database
                    try await client.deleteRecords(existingRecordsToDelete, from: dataObject)

                    await MainActor.run {
                        // Remove the records from the local array
                        records.removeAll { selectedRecords.contains($0.id) }

                        // Clear selection
                        selectedRecords.removeAll()
                    }
                } catch let error as SQLiteError {
                    await MainActor.run {
                        self.error = error
                        self.showAlert = true
                    }
                }
            }
        } else {
            // If only new records were deleted, clear selection immediately
            selectedRecords.removeAll()
        }
    }
    
    func confirmDeleteRecords() {
        guard !selectedRecords.isEmpty else {
            return
        }
        
        showDeleteConfirmation = true
    }
    
    func validateAndSaveOrRemoveRecord(_ recordId: UUID) {
        guard let record = newRecords.first(where: { $0.id == recordId }) else {
            return
        }
        
        // Check if all required (NOT NULL) fields are filled
        var allRequiredFieldsFilled = true
        
        for property in properties {
            // Skip auto-increment primary keys
            if property.column.pk > 0 {
                // Check if this is an auto-increment column by seeing if it's INTEGER PRIMARY KEY
                let isAutoIncrement = property.column.datatype.uppercased().contains("INTEGER") &&
                                    property.column.pk > 0
                if isAutoIncrement {
                    continue
                }
            }
            
            if property.column.notNull {
                if let value = record.values[property.column.name] {
                    switch value {
                    case .null, .undefined:
                        allRequiredFieldsFilled = false
                    case .text(let str) where str.isEmpty:
                        allRequiredFieldsFilled = false
                    default:
                        break
                    }
                } else {
                    allRequiredFieldsFilled = false
                }
            }
        }
        
        if allRequiredFieldsFilled {
            // Save the record
            saveSpecificRecord(recordId)
        } else {
            // Remove the record
            newRecords.removeAll { $0.id == recordId }
            selectedRecords.remove(recordId)
        }
    }
    
    func saveSpecificRecord(_ recordId: UUID) {
        guard let record = newRecords.first(where: { $0.id == recordId }) else {
            return
        }
        
        Task {
            do {
                try await client.addRecord(record, to: dataObject)
                
                await MainActor.run {
                    // Remove from new records
                    newRecords.removeAll { $0.id == recordId }
                    
                    // Refresh to show saved record
                    refreshRecords()
                }
            } catch {
                if let sqlError = error as? SQLiteError {
                    await MainActor.run {
                        self.error = sqlError
                        self.showAlert = true
                        
                        // Keep the record in newRecords so user can fix it
                    }
                }
            }
        }
    }
    
    func saveNewRecords() {
        guard !newRecords.isEmpty else {
            return
        }
        
        Task {
            var savedCount = 0
            var failedCount = 0
            
            for record in newRecords {
                do {
                    try await client.addRecord(record, to: dataObject)
                    
                    savedCount += 1
                } catch {
                    failedCount += 1
                    
                    if let sqlError = error as? SQLiteError {
                        await MainActor.run {
                            self.error = sqlError
                            self.showAlert = true
                        }
                    }
                }
            }
            
            await MainActor.run {
                // Clear all new records after attempting to save
                newRecords.removeAll()
                
                // Refresh to show saved records
                if savedCount > 0 {
                    refreshRecords()
                }
            }
        }
    }
}
