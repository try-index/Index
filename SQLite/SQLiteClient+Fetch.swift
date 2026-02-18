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
        let columns = entity.properties.values.map { $0.column }
        
        var records = try rows.compactMap { row in
            try Record(row, from: columns)
        }
        
        // Get all table names for looking up relationship tables
        let allTableNames = try await getTableNames()
        
        // Fetch relationship previews for all relationships (to-one and to-many)
        for i in 0..<records.count {
            var previews: [String: Record.RelationshipPreview] = [:]
            
            // Find all relationships
            for property in entity.properties.values {
                if let fk = property.column.foreignKey {
                    // Find the actual table name for the destination entity
                    guard let actualTableName = allTableNames.first(where: { 
                        $0.uppercased().contains(fk.table.uppercased())
                    }) else {
                        continue
                    }
                    
                    if property.column.datatype == "RELATIONSHIP" {
                        // To-many relationship - use Z_PK to find related records
                        guard let pkValue = records[i].values["Z_PK"] else { continue }
                        let preview = try await fetchRelationshipPreview(
                            tableName: actualTableName,
                            foreignKeyColumn: fk.column,
                            foreignKeyValue: pkValue,
                            destinationEntityName: fk.table
                        )
                        previews[property.name] = preview
                    } else {
                        // To-one relationship - use the foreign key value directly
                        guard let fkValue = records[i].values[property.column.name] else {
                            continue
                        }
                        
                        // Skip if the value is null
                        if case .null = fkValue {
                            continue
                        }
                        let preview = try await fetchToOneRelationshipPreview(
                            tableName: actualTableName,
                            primaryKeyValue: fkValue,
                            destinationEntityName: fk.table
                        )
                        previews[property.name] = preview
                    }
                }
            }
            
            records[i].relationshipPreviews = previews
        }
        
        return records
    }
    
    private func fetchRelationshipPreview(
        tableName: String,
        foreignKeyColumn: String,
        foreignKeyValue: Value,
        destinationEntityName: String
    ) async throws -> Record.RelationshipPreview {
        // Build WHERE clause based on value type
        let valueExpr: any SQLExpression
        switch foreignKeyValue {
        case .integer(let int):
            valueExpr = SQLLiteral.numeric("\(int)")
        case .smallint(let int):
            valueExpr = SQLLiteral.numeric("\(int)")
        case .text(let str):
            valueExpr = SQLLiteral.string(str)
        default:
            valueExpr = SQLLiteral.null
        }
        
        // Get count
        let countRow = try await db
            .select()
            .column(SQLFunction("COUNT", args: SQLLiteral.all), as: "count")
            .from(tableName)
            .where(SQLColumn(foreignKeyColumn), .equal, valueExpr)
            .first()
        
        let count = try countRow?.decode(column: "count", as: Int.self) ?? 0
        
        guard count > 0 else {
            return Record.RelationshipPreview(count: 0, firstValue: nil)
        }
        
        // Get first record's first displayable column
        let firstRow = try await db
            .select()
            .column(SQLLiteral.all)
            .from(tableName)
            .where(SQLColumn(foreignKeyColumn), .equal, valueExpr)
            .limit(1)
            .first()
        
        var firstValue: String? = nil
        if let row = firstRow {
            var propertyStrings: [String] = []
            var totalLength = 0
            let maxLength = 50  // Character limit before truncation
            
            // Get entity description from model to find proper property names
            if let entityDesc = model?.entitiesByName[destinationEntityName] {
                // Use the same property order as displayed in the table (sorted alphabetically)
                let sortedAttributes = entityDesc.attributesByName.filter { !$0.key.hasPrefix("_") }.sorted { $0.key < $1.key }
                
                for (attributeName, _) in sortedAttributes {
                    // Skip internal attributes
                    if attributeName.hasPrefix("_") { continue }
                    
                    // Try to match column name (CoreData uses Z prefix + uppercase)
                    let columnName = "Z\(attributeName.uppercased())"
                    
                    var propertyString: String? = nil
                    
                    if let value = try? row.decode(column: columnName, as: String.self), !value.isEmpty {
                        let truncated = value.count > 15 ? String(value.prefix(15)) + "..." : value
                        propertyString = "\(attributeName): \"\(truncated)\""
                    } else if let value = try? row.decode(column: columnName, as: Int.self) {
                        propertyString = "\(attributeName): \(value)"
                    } else if let value = try? row.decode(column: columnName, as: Double.self) {
                        propertyString = "\(attributeName): \(value)"
                    } else if let value = try? row.decode(column: columnName, as: Bool.self) {
                        propertyString = "\(attributeName): \(value)"
                    }
                    
                    if let propertyString = propertyString {
                        let newLength = totalLength + propertyString.count + (propertyStrings.isEmpty ? 0 : 2) // +2 for ", "
                        if newLength > maxLength && !propertyStrings.isEmpty {
                            break
                        }
                        propertyStrings.append(propertyString)
                        totalLength = newLength
                    }
                }
            }
            
            // Fallback to column-based approach if metadata not available
            if propertyStrings.isEmpty {
                let allColumns = try await getColumns(from: tableName)
                let sortedColumns = allColumns.filter { !$0.name.hasPrefix("Z_") || $0.name == "Z_PK" }.sorted { $0.name < $1.name }
                
                for column in sortedColumns {
                    let propertyName = column.name.lowercased().hasPrefix("z") ? 
                        String(column.name.dropFirst()).lowercased() : 
                        column.name.lowercased()
                    
                    var propertyString: String? = nil
                    
                    if let value = try? row.decode(column: column.name, as: String.self), !value.isEmpty {
                        let truncated = value.count > 15 ? String(value.prefix(15)) + "..." : value
                        propertyString = "\(propertyName): \"\(truncated)\""
                    } else if let value = try? row.decode(column: column.name, as: Int.self) {
                        propertyString = "\(propertyName): \(value)"
                    } else if let value = try? row.decode(column: column.name, as: Double.self) {
                        propertyString = "\(propertyName): \(value)"
                    }
                    
                    if let propertyString = propertyString {
                        let newLength = totalLength + propertyString.count + (propertyStrings.isEmpty ? 0 : 2)
                        if newLength > maxLength && !propertyStrings.isEmpty {
                            break
                        }
                        propertyStrings.append(propertyString)
                        totalLength = newLength
                    }
                }
            }
            
            firstValue = propertyStrings.isEmpty ? nil : propertyStrings.joined(separator: ", ")
        }
        
        return Record.RelationshipPreview(count: count, firstValue: firstValue)
    }
    
    private func fetchToOneRelationshipPreview(
        tableName: String,
        primaryKeyValue: Value,
        destinationEntityName: String
    ) async throws -> Record.RelationshipPreview {
        // Build WHERE clause for Z_PK
        let valueExpr: any SQLExpression
        switch primaryKeyValue {
        case .integer(let int):
            valueExpr = SQLLiteral.numeric("\(int)")
        case .smallint(let int):
            valueExpr = SQLLiteral.numeric("\(int)")
        case .text(let str):
            valueExpr = SQLLiteral.string(str)
        default:
            return Record.RelationshipPreview(count: 0, firstValue: nil)
        }
        
        // Get the related record
        let row = try await db
            .select()
            .column(SQLLiteral.all)
            .from(tableName)
            .where(SQLColumn("Z_PK"), .equal, valueExpr)
            .first()
        
        guard let row = row else {
            return Record.RelationshipPreview(count: 0, firstValue: nil)
        }
        
        var propertyStrings: [String] = []
        var totalLength = 0
        let maxLength = 50  // Character limit before truncation
        
        // Get entity description from model to find proper property names
        if let entityDesc = model?.entitiesByName[destinationEntityName] {
            // Sort attributes alphabetically for deterministic order
            let sortedAttributes = entityDesc.attributesByName.sorted { $0.key < $1.key }
            
            for (attributeName, _) in sortedAttributes {
                // Skip internal attributes
                if attributeName.hasPrefix("_") { continue }
                
                // Try to match column name (CoreData uses Z prefix + uppercase)
                let columnName = "Z\(attributeName.uppercased())"
                
                var propertyString: String? = nil
                
                if let value = try? row.decode(column: columnName, as: String.self), !value.isEmpty {
                    let truncated = value.count > 15 ? String(value.prefix(15)) + "..." : value
                    propertyString = "\(attributeName): \"\(truncated)\""
                } else if let value = try? row.decode(column: columnName, as: Int.self) {
                    propertyString = "\(attributeName): \(value)"
                } else if let value = try? row.decode(column: columnName, as: Double.self) {
                    propertyString = "\(attributeName): \(value)"
                } else if let value = try? row.decode(column: columnName, as: Bool.self) {
                    propertyString = "\(attributeName): \(value)"
                }
                
                if let propertyString = propertyString {
                    let newLength = totalLength + propertyString.count + (propertyStrings.isEmpty ? 0 : 2) // +2 for ", "
                    if newLength > maxLength && !propertyStrings.isEmpty {
                        break
                    }
                    propertyStrings.append(propertyString)
                    totalLength = newLength
                }
            }
        }
        
        // Fallback to column-based approach if metadata not available
        if propertyStrings.isEmpty {
            let allColumns = try await getColumns(from: tableName)
            let sortedColumns = allColumns.filter { !$0.name.hasPrefix("Z_") || $0.name == "Z_PK" }.sorted { $0.name < $1.name }
            
            for column in sortedColumns {
                let propertyName = column.name.lowercased().hasPrefix("z") ? 
                    String(column.name.dropFirst()).lowercased() : 
                    column.name.lowercased()
                
                var propertyString: String? = nil
                
                if let value = try? row.decode(column: column.name, as: String.self), !value.isEmpty {
                    let truncated = value.count > 15 ? String(value.prefix(15)) + "..." : value
                    propertyString = "\(propertyName): \"\(truncated)\""
                } else if let value = try? row.decode(column: column.name, as: Int.self) {
                    propertyString = "\(propertyName): \(value)"
                } else if let value = try? row.decode(column: column.name, as: Double.self) {
                    propertyString = "\(propertyName): \(value)"
                }
                
                if let propertyString = propertyString {
                    let newLength = totalLength + propertyString.count + (propertyStrings.isEmpty ? 0 : 2)
                    if newLength > maxLength && !propertyStrings.isEmpty {
                        break
                    }
                    propertyStrings.append(propertyString)
                    totalLength = newLength
                }
            }
        }
        
        let firstValue = propertyStrings.isEmpty ? nil : propertyStrings.joined(separator: ", ")
        
        return Record.RelationshipPreview(count: 1, firstValue: firstValue)
    }

    func getRecords(from table: SQLiteTable) async throws -> [Record] {
        let rows = try await db
            .select()
            .column(SQLLiteral.all)
            .column(SQLAlias(SQLColumn("ROWID"), as: SQLIdentifier("rowId")))
            .from(table.name)
            .all()

        // If this is a Model (SwiftData), use columns from properties (which have metadata)
        let columns: [SQLiteColumn]
        let properties: [Property]?
        if let model = table as? Model {
            columns = model.properties.values.map { $0.column }
            properties = Array(model.properties.values)
        } else {
            columns = table.columns
            properties = nil
        }

        var records = try rows.compactMap { row in
            try Record(row, from: columns)
        }
        
        // Fetch relationship previews for Models (same as Entity)
        if let properties = properties {
            // Get all table names for looking up relationship tables
            let allTableNames = try await getTableNames()
            
            for i in 0..<records.count {
                var previews: [String: Record.RelationshipPreview] = [:]
                
                // Find all relationships
                for property in properties {
                    if let fk = property.column.foreignKey {
                        // Find the actual table name for the destination entity
                        guard let actualTableName = allTableNames.first(where: { 
                            $0.uppercased().contains(fk.table.uppercased())
                        }) else {
                            continue
                        }
                        
                        if property.column.datatype == "RELATIONSHIP" {
                            // To-many relationship - use primary key to find related records
                            // CoreData uses Z_PK, but we might need to find the PK differently
                            var pkValue: Value? = records[i].values["Z_PK"]
                            
                            // If Z_PK not found, try to find PK column from properties
                            if pkValue == nil {
                                // Look for a column marked as primary key
                                if let pkColumn = properties.first(where: { $0.column.pk > 0 }) {
                                    pkValue = records[i].values[pkColumn.column.name]
                                }
                                // If still not found, try rowId
                                if pkValue == nil, let rowId = records[i].rowId {
                                    pkValue = .integer(rowId)
                                }
                            }
                            
                            guard let pkValue = pkValue else {
                                continue
                            }
                            let preview = try await fetchRelationshipPreview(
                                tableName: actualTableName,
                                foreignKeyColumn: fk.column,
                                foreignKeyValue: pkValue,
                                destinationEntityName: fk.table
                            )
                            previews[property.name] = preview
                        } else {
                            // To-one relationship - use the foreign key value directly
                            guard let fkValue = records[i].values[property.column.name] else {
                                continue
                            }
                            
                            // Skip if the value is null
                            if case .null = fkValue {
                                continue
                            }
                            let preview = try await fetchToOneRelationshipPreview(
                                tableName: actualTableName,
                                primaryKeyValue: fkValue,
                                destinationEntityName: fk.table
                            )
                            previews[property.name] = preview
                        }
                    }
                }
                
                records[i].relationshipPreviews = previews
            }
        }
        
        return records
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
