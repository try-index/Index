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
        let rows = try await db
            .select()
            .column(SQLLiteral.all)
            .column(SQLAlias(SQLColumn("ROWID"), as: SQLIdentifier("rowId")))
            .from(entity.name)
            .all()
        
        // Use columns from properties (which have metadata) instead of raw table columns
        // Also include Z_PK if present, as it's needed for relationship filtering
        var columns = entity.properties.values.map { $0.column }
        
        if let pkColumn = entity.columns.first(where: { $0.name == "Z_PK" }),
           !columns.contains(where: { $0.name == "Z_PK" }) {
            columns.append(pkColumn)
        }
        
        var records = try rows.compactMap { row in
            try Record(row, from: columns)
        }
        
        try await fetchRelationshipPreviews(
            for: &records,
            properties: Array(entity.properties.values)
        )
        
        return records
    }
    
    func getRecords(from table: SQLiteTable) async throws -> [Record] {
        let rows = try await db
            .select()
            .column(SQLLiteral.all)
            .column(SQLAlias(SQLColumn("ROWID"), as: SQLIdentifier("rowId")))
            .from(table.name)
            .all()
        
        // If this is a Model (SwiftData), use columns from properties (which have metadata)
        // Also include Z_PK if present, as it's needed for relationship filtering
        var columns: [SQLiteColumn]
        let properties: [Property]?
        
        if let model = table as? Model {
            columns = model.properties.values.map { $0.column }
            
            if let pkColumn = table.columns.first(where: { $0.name == "Z_PK" }),
               !columns.contains(where: { $0.name == "Z_PK" }) {
                columns.append(pkColumn)
            }
            
            properties = Array(model.properties.values)
        } else {
            columns = table.columns
            properties = nil
        }
        
        var records = try rows.compactMap { row in
            try Record(row, from: columns)
        }
        
        if let properties = properties {
            try await fetchRelationshipPreviews(for: &records, properties: properties)
        }
        
        return records
    }
    
    // MARK: - Relationship Previews
    
    private func fetchRelationshipPreviews(
        for records: inout [Record],
        properties: [Property]
    ) async throws {
        let allTableNames = try await getTableNames()
        
        for i in 0..<records.count {
            var previews: [String: Record.RelationshipPreview] = [:]
            
            for property in properties {
                guard let fk = property.column.foreignKey,
                      let actualTableName = allTableNames.first(where: {
                          $0.uppercased().contains(fk.table.uppercased())
                      }) else {
                    continue
                }
                
                if property.column.datatype == "RELATIONSHIP" {
                    // To-many relationship - resolve primary key
                    let pkValue = resolvePrimaryKey(for: records[i], properties: properties)
                    guard let pkValue = pkValue else { continue }
                    
                    previews[property.name] = try await fetchPreview(
                        tableName: actualTableName,
                        column: fk.column,
                        value: pkValue,
                        destinationEntityName: fk.table
                    )
                } else {
                    // To-one relationship
                    guard let fkValue = records[i].values[property.column.name],
                          !fkValue.isNull else {
                        continue
                    }
                    
                    previews[property.name] = try await fetchPreview(
                        tableName: actualTableName,
                        column: "Z_PK",
                        value: fkValue,
                        destinationEntityName: fk.table
                    )
                }
            }
            
            records[i].relationshipPreviews = previews
        }
    }
    
    private func resolvePrimaryKey(for record: Record, properties: [Property]) -> Value? {
        if let pk = record.values["Z_PK"] { return pk }
        if let pkColumn = properties.first(where: { $0.column.pk > 0 }),
           let pk = record.values[pkColumn.column.name] { return pk }
        if let rowId = record.rowId { return .integer(rowId) }
        
        return nil
    }
    
    private func sqlExpression(for value: Value) -> (any SQLExpression)? {
        switch value {
        case .integer(let int): return SQLLiteral.numeric("\(int)")
        case .smallint(let int): return SQLLiteral.numeric("\(int)")
        case .text(let str): return SQLLiteral.string(str)
        default: return nil
        }
    }
    
    private func fetchPreview(
        tableName: String,
        column: String,
        value: Value,
        destinationEntityName: String
    ) async throws -> Record.RelationshipPreview {
        guard let valueExpr = sqlExpression(for: value) else {
            return Record.RelationshipPreview(count: 0, firstValue: nil, propertyCount: 0)
        }
        
        // Get count
        let countRow = try await db
            .select()
            .column(SQLFunction("COUNT", args: SQLLiteral.all), as: "count")
            .from(tableName)
            .where(SQLColumn(column), .equal, valueExpr)
            .first()
        
        let count = try countRow?.decode(column: "count", as: Int.self) ?? 0
        
        guard count > 0 else {
            return Record.RelationshipPreview(count: 0, firstValue: nil, propertyCount: 0)
        }
        
        // Get first record for preview
        let row = try await db
            .select()
            .column(SQLLiteral.all)
            .from(tableName)
            .where(SQLColumn(column), .equal, valueExpr)
            .limit(1)
            .first()
        
        guard let row = row else {
            return Record.RelationshipPreview(count: count, firstValue: nil, propertyCount: 0)
        }
        
        let (firstValue, propertyCount) = try await buildPreviewString(
            from: row,
            tableName: tableName,
            destinationEntityName: destinationEntityName
        )
        
        return Record.RelationshipPreview(count: count, firstValue: firstValue, propertyCount: propertyCount)
    }
    
    private func buildPreviewString(
        from row: any SQLRow,
        tableName: String,
        destinationEntityName: String
    ) async throws -> (firstValue: String?, propertyCount: Int) {
        let maxLength = 50
        
        // Try entity metadata first
        if let entityDesc = model?.entitiesByName[destinationEntityName] {
            let sortedAttributes = entityDesc.attributesByName
                .filter { !$0.key.hasPrefix("_") }
                .sorted { $0.key < $1.key }
            
            let pairs = collectPropertyStrings(from: row, attributes: sortedAttributes, maxLength: maxLength)
            
            if !pairs.isEmpty {
                return (pairs.joined(separator: ", "), sortedAttributes.count)
            }
        }
        
        // Fallback to column-based approach
        let allColumns = try await getColumns(from: tableName)
        let sortedColumns = allColumns
            .filter { !$0.name.hasPrefix("Z_") || $0.name == "Z_PK" }
            .sorted { $0.name < $1.name }
        
        let pairs = collectPropertyStrings(from: row, columns: sortedColumns, maxLength: maxLength)
        let result = pairs.isEmpty ? nil : pairs.joined(separator: ", ")
        
        return (result, sortedColumns.count)
    }
    
    private func collectPropertyStrings(
        from row: any SQLRow,
        attributes: [(key: String, value: NSAttributeDescription)],
        maxLength: Int
    ) -> [String] {
        var strings: [String] = []
        var totalLength = 0
        
        for (attributeName, _) in attributes {
            if attributeName.hasPrefix("_") { continue }
            let columnName = "Z\(attributeName.uppercased())"
            
            guard let pair = decodePropertyString(from: row, propertyName: attributeName, columnName: columnName) else {
                continue
            }
            
            let newLength = totalLength + pair.count + (strings.isEmpty ? 0 : 2)
            if newLength > maxLength && !strings.isEmpty { break }
            strings.append(pair)
            totalLength = newLength
        }
        
        return strings
    }
    
    private func collectPropertyStrings(
        from row: any SQLRow,
        columns: [SQLiteColumn],
        maxLength: Int
    ) -> [String] {
        var strings: [String] = []
        var totalLength = 0
        
        for column in columns {
            let propertyName = column.name.lowercased().hasPrefix("z")
                ? String(column.name.dropFirst()).lowercased()
                : column.name.lowercased()
            
            guard let pair = decodePropertyString(from: row, propertyName: propertyName, columnName: column.name) else {
                continue
            }
            
            let newLength = totalLength + pair.count + (strings.isEmpty ? 0 : 2)
            if newLength > maxLength && !strings.isEmpty { break }
            strings.append(pair)
            totalLength = newLength
        }
        
        return strings
    }
    
    private func decodePropertyString(from row: any SQLRow, propertyName: String, columnName: String) -> String? {
        if let value = try? row.decode(column: columnName, as: String.self), !value.isEmpty {
            let truncated = value.count > 15 ? String(value.prefix(15)) + "..." : value
            return "\(propertyName): \"\(truncated)\""
        } else if let value = try? row.decode(column: columnName, as: Int.self) {
            return "\(propertyName): \(value)"
        } else if let value = try? row.decode(column: columnName, as: Double.self) {
            return "\(propertyName): \(value)"
        } else if let value = try? row.decode(column: columnName, as: Bool.self) {
            return "\(propertyName): \(value)"
        }
        return nil
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
            // Skip internal/transient attributes that aren't part of the model
            // SwiftData uses persistent identifiers and other metadata we don't want to show
            let attributeName = attribute.key
            
            if attributeName.hasPrefix("_") ||
                attributeName == "persistentModelID" ||
                attribute.value.isTransient {
                continue
            }
            
            guard let column = tableColumns.first(where: {
                var columnName = $0.name.lowercased()
                
                // Only remove "z" prefix if it exists (CoreData convention)
                if columnName.hasPrefix("z") {
                    columnName.removeFirst()
                }
                
                return attribute.key.lowercased() == columnName
            }) else {
                continue
            }
            
            properties[attribute.value.name] = Property(attribute: attribute.value, column: column)
        }
        
        // Add properties for to-one relationships (foreign key columns)
        for (relationshipName, relationship) in description.relationshipsByName {
            // Skip internal/private relationships
            if relationshipName.hasPrefix("_") {
                continue
            }
            
            // Skip to-many relationships for now, handle them separately below
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
        
        // Add to-many relationships (inverse relationships)
        // These don't have physical columns but are important for CoreData/SwiftData representation
        for (relationshipName, relationship) in description.relationshipsByName {
            // Skip internal/private relationships
            if relationshipName.hasPrefix("_") {
                continue
            }
            
            guard relationship.isToMany else { continue }
            
            // Create a virtual property for to-many relationships
            // Use a placeholder column since there's no actual SQLite column for inverse relationships
            properties[relationshipName] = Property(toManyRelationship: relationship)
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
