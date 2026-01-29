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
                    pk: pk
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
