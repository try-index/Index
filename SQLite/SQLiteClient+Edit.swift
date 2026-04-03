//
//  SQLiteClient+Edit.swift
//  Index
//
//  Created by Axel Martinez on 6/3/25.
//

import Foundation
import SQLiteKit

extension SQLiteClient {
    func addRecord(_ record: Record, to table: SQLiteTable) async throws {
        var columnNames: [String] = []
        var values: [any SQLExpression] = []

        for column in table.columns {
            if let value = record.values[column.name] {
                columnNames.append(column.name)
                values.append(sqlExpression(for: value))
            }
        }

        try await db
            .insert(into: table.name)
            .columns(columnNames)
            .values(values)
            .run()
    }

    func deleteRecords(_ records: [Record], from table: SQLiteTable) async throws {
        for record in records {
            var delete = try db.delete(from: table.name)

            if let whereExpression = buildWhereExpression(for: record, in: table) {
                delete = delete.where(whereExpression)
            }

            try await delete.run()
        }
    }

    func updateRecord(
        _ record: Record,
        newRecord: Record,
        for columnName: String,
        from table: SQLiteTable
    ) async throws {
        guard let value = newRecord.values[columnName] else { return }

        var update = try db
            .update(table.name)
            .set(columnName, to: sqlExpression(for: value))

        // Use original record for WHERE clause so we match the row before the update
        if let whereExpression = buildWhereExpression(for: record, in: table) {
            update = update.where(whereExpression)
        }

        try await update.run()
    }

    func updateRecord(
        _ record: Record,
        from table: SQLiteTable
    ) async throws {
        var update = try db.update(table.name)

        for column in table.columns {
            if let value = record.values[column.name] {
                update = update.set(column.name, to: sqlExpression(for: value))
            }
        }

        if let whereExpression = buildWhereExpression(for: record, in: table) {
            update = update.where(whereExpression)
        }

        try await update.run()
    }

    private func sqlExpression(for value: Value) -> any SQLExpression {
        switch value {
        case .null, .undefined:
            return SQLLiteral.null
        case .smallint(let int16):
            return SQLLiteral.numeric("\(int16)")
        case .integer(let int):
            return SQLLiteral.numeric("\(int)")
        case .float(let float):
            return SQLLiteral.numeric("\(float)")
        case .real(let double):
            return SQLLiteral.numeric("\(double)")
        case .text(let string):
            return SQLLiteral.string(string)
        case .uuid(let uuid):
            // Store UUID as BLOB with raw bytes
            let uuidBytes = withUnsafePointer(to: uuid.uuid) {
                Data(bytes: $0, count: MemoryLayout.size(ofValue: uuid.uuid))
            }
            return SQLBind(uuidBytes)
        case .data(let string):
            // Data is stored as string representation (read-only)
            return SQLLiteral.string(string)
        case .enumValue(let caseName):
            // Try to parse as integer first (for Int-backed enums)
            if let intValue = Int(caseName) {
                return SQLLiteral.numeric("\(intValue)")
            } else {
                // Otherwise store as string (for String-backed enums)
                return SQLLiteral.string(caseName)
            }
        case .timestamp(let date):
            return SQLLiteral.numeric("\(date.timeIntervalSince1970)")
        case .array, .image:
            return SQLLiteral.null
        }
    }

    private func buildWhereExpression(for record: Record, in table: SQLiteTable) -> (any SQLExpression)? {
        let pkColumns = table.columns.filter { $0.pk > 0 }

        if !pkColumns.isEmpty {
            var expressions: [any SQLExpression] = []

            for column in pkColumns {
                if let value = record.values[column.name] {
                    let condition = SQLBinaryExpression(
                        left: SQLColumn(column.name),
                        op: SQLBinaryOperator.equal,
                        right: sqlExpression(for: value)
                    )
                    expressions.append(condition)
                }
            }

            if expressions.isEmpty {
                return nil
            }

            return expressions.dropFirst().reduce(expressions.first!) { result, expr in
                SQLBinaryExpression(left: result, op: SQLBinaryOperator.and, right: expr)
            }
        }

        if let rowId = record.rowId {
            return SQLBinaryExpression(
                left: SQLColumn("rowid"),
                op: SQLBinaryOperator.equal,
                right: SQLLiteral.numeric("\(rowId)")
            )
        }

        return nil
    }
}
