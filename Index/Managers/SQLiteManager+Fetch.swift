//
//  SQLManager+Fetch.swift
//  Index
//
//  Created by Axel Martinez on 6/3/25.
//

import Foundation
import SQLiteKit
import SwiftData
import CoreData

extension SQLiteManager {
    func getModels() async throws -> [Model] {
        return try await getEntities() as [Model]
    }
    
    func getEntities<T: Entity>() async throws -> [T] {
        let tableNames = try await getTableNames()
        
        var entities: [T] = []
        
        for entity in model?.entities ?? [] {
            // Fetch SQLite table
            guard let name = entity.name,
                let tableName = tableNames.first(where: {
                $0.contains(name.uppercased())
            }) else {
                continue
            }
            
            entities.append(try await getEntity(
                entity,
                tables: tableNames,
                tableName: tableName
            ))
        }
        
        return entities
    }
    
    func getTables() async throws -> [SQLiteTable] {
        let tableNames = try await getTableNames()
        
        var tables: [SQLiteTable] = []
        
        for tableName in tableNames {
            tables.append(try await getTable(tableName))
        }
        
        return tables
    }
    
    func getRecords(from model: Model) async throws -> [Record] {
        return try await getRecords(from: model as SQLiteTable)
    }
    
    func getRecords(from entity: Entity) async throws -> [Record] {
        return try await getRecords(from: entity as SQLiteTable)
    }
    
    func getRecords(from table: SQLiteTable) async throws -> [Record] {
        let query = "SELECT ROWID as rowId,* FROM \(table.name)"
        
        return try await runQuery(query, mapping: { row in
            return try Record(row, from: table.columns)
        })
    }
    
    private func getTableNames() async throws -> [String] {
        let query = """
                    SELECT name FROM sqlite_master
                    WHERE type='table'
                    AND name NOT LIKE 'sqlite_%'
                    ORDER BY name;
                    """
        
        return try await runQuery(query) { row in
            try row.decode(column: "name", as: String.self)
        }
    }
    
    private func getEntity<T: Entity>(_ description: NSEntityDescription, tables: [String], tableName: String) async throws -> T {
        let tableColumns = try await getColumns(from: tableName)
        let recordCount = try await getRecordCount(tableName)
        
        var properties = [String: Property]()
        
        for attribute in description.attributesByName {
            guard let column = tableColumns.first(where: {
                var columnName = $0.name.lowercased()
                columnName.removeFirst()
                return attribute.key.lowercased() == columnName
            }) else {
                continue
            }
            
            properties[attribute.value.name] = Property(attribute: attribute.value, column: column)
        }

        guard let name = description.name else {
            throw URLError(.badURL, userInfo: [NSLocalizedDescriptionKey : "Missing entity name"])
        }
        
        return T(
            displayName: name,
            properties: properties,
            tableName: tableName,
            tableColumns: tableColumns,
            recordCount: recordCount
        )
    }
    
    private func getTable(_ name: String) async throws -> SQLiteTable {
        let columns = try await getColumns(from: name)
        let recordCount = try await getRecordCount(name)
        
        return SQLiteTable(
            name: name,
            columns: columns,
            recordCount: recordCount
        )
    }
    
    private func getColumns(from tableName: String) async throws -> [SQLiteColumn] {
        let query = "PRAGMA table_info(\(tableName));"
        
        return try await self.runQuery(query, mapping: { row in
            do  {
                let name = try row.decode(column: "name", as: String.self)
                let dataType = try row.decode(column: "type", as: String.self)
                let notNull = try row.decode(column: "notnull", as: Bool.self)
                let pk = try row.decode(column: "pk", as: Int.self)
                
                return SQLiteColumn(
                    name: name,
                    datatype: dataType,
                    notNull: notNull,
                    pk: pk
                )
            } catch {
                print("Can't decode table \(tableName): \(error.localizedDescription)")
            }
            
            return nil
        })
    }
    
    private func getRecordCount(_ tableName: String) async throws -> Int {
        let query = "SELECT COUNT(*) as rowCount FROM \(tableName)"
        
        return try await runQuery(query, column: "rowCount") ?? 0
    }
}
