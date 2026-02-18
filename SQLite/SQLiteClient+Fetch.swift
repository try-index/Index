//
//  SQLiteClient+Fetch.swift
//  Index
//
//  Created by Axel Martinez on 6/3/25.
//  Refactored to actor extension on 28/01/26.
//

import Foundation
import SQLiteKit
import CoreData

extension SQLiteClient {
    func getModels() async throws -> [Model] {
        return try await getEntities() as [Model]
    }

    func getEntities<T: Entity>() async throws -> [T] {
        let tableNames = try await getTableNames()

        var entities: [T] = []

        for entity in model?.entities ?? [] {
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
        let rows = try await db
            .select()
            .column(SQLLiteral.all)
            .column(SQLAlias(SQLColumn("ROWID"), as: SQLIdentifier("rowId")))
            .from(table.name)
            .all()

        return try rows.compactMap { row in
            try Record(row, from: table.columns)
        }
    }

    private func getTableNames() async throws -> [String] {
        let rows = try await db
            .select()
            .column("name")
            .from(SQLIdentifier("sqlite_master"))
            .where("type", .equal, "table")
            .where(SQLColumn("name"), .notLike, SQLLiteral.string("sqlite_%"))
            .orderBy("name")
            .all()

        return try rows.compactMap { row in
            try row.decode(column: "name", as: String.self)
        }
    }

    private func getEntity<T: Entity>(
        _ description: NSEntityDescription,
        tables: [String],
        tableName: String
    ) async throws -> T {
        var tableColumns = try await getColumns(from: tableName)
        let recordCount = try await getRecordCount(tableName)
        
        // Build a map of Core Data relationships for foreign key detection
        var relationshipMap: [String: (destinationEntity: String, inverseRelationship: String?)] = [:]
        for (relationshipName, relationship) in description.relationshipsByName {
            if let destinationEntity = relationship.destinationEntity?.name {
                relationshipMap[relationshipName] = (
                    destinationEntity: destinationEntity,
                    inverseRelationship: relationship.inverseRelationship?.name
                )
            }
        }
        
        // Update columns with Core Data relationship information
        tableColumns = tableColumns.map { column in
            // Check if this column represents a relationship
            var columnName = column.name.lowercased()
            if columnName.hasPrefix("z") {
                columnName.removeFirst()
            }
            
            // Look for matching relationship
            for (relationshipName, relationshipInfo) in relationshipMap {
                if columnName == relationshipName.lowercased() {
                    // Create a foreign key reference for this relationship
                    let fk = SQLiteColumn.ForeignKey(
                        table: relationshipInfo.destinationEntity,
                        column: "Z_PK"
                    )
                    return SQLiteColumn(
                        name: column.name,
                        datatype: column.datatype,
                        notNull: column.notNull,
                        pk: column.pk,
                        foreignKey: fk
                    )
                }
            }
            
            return column
        }

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
        
        // Add properties for relationships (as foreign key columns)
        for (relationshipName, relationship) in description.relationshipsByName {
            // Only add to-one relationships (not to-many)
            guard !relationship.isToMany else { continue }
            
            // Find the column that represents this relationship
            guard let column = tableColumns.first(where: {
                var columnName = $0.name.lowercased()
                if columnName.hasPrefix("z") {
                    columnName.removeFirst()
                }
                return columnName == relationshipName.lowercased()
            }) else {
                continue
            }
            
            // Create a property for this relationship column with formatted name
            // Use the relationship description to get proper naming and type info
            properties[relationshipName] = Property(relationship: relationship, column: column)
        }

        guard let name = description.name else {
            throw URLError(.badURL, userInfo: [NSLocalizedDescriptionKey: "Missing entity name"])
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
        let rows = try await db
            .raw("PRAGMA table_info(\(SQLLiteral.string(tableName)));")
            .all()

        // Fetch foreign key information
        let foreignKeyRows = try await db
            .raw("PRAGMA foreign_key_list(\(SQLLiteral.string(tableName)));")
            .all()
        
        // Build a map of column name to foreign key info
        var foreignKeys: [String: SQLiteColumn.ForeignKey] = [:]
        
        for fkRow in foreignKeyRows {
            do {
                let from = try fkRow.decode(column: "from", as: String.self)
                let table = try fkRow.decode(column: "table", as: String.self)
                let to = try fkRow.decode(column: "to", as: String.self)
                
                foreignKeys[from] = SQLiteColumn.ForeignKey(table: table, column: to)
            } catch {
                print("Can't decode foreign key for table \(tableName): \(error.localizedDescription)")
            }
        }

        return rows.compactMap { row in
            do {
                let name = try row.decode(column: "name", as: String.self)
                let dataType = try row.decode(column: "type", as: String.self)
                let notNull = try row.decode(column: "notnull", as: Bool.self)
                let pk = try row.decode(column: "pk", as: Int.self)

                return SQLiteColumn(
                    name: name,
                    datatype: dataType,
                    notNull: notNull,
                    pk: pk,
                    foreignKey: foreignKeys[name]
                )
            } catch {
                print("Can't decode table \(tableName): \(error.localizedDescription)")
                
                return nil
            }
        }
    }

    private func getRecordCount(_ tableName: String) async throws -> Int {
        let row = try await db
            .select()
            .column(SQLFunction("COUNT", args: SQLLiteral.all), as: "rowCount")
            .from(tableName)
            .first()

        return try row?.decode(column: "rowCount", as: Int.self) ?? 0
    }
}
