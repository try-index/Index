//
//  SQLiteClient+Edit.swift
//  Index
//
//  Created by Axel Martinez on 6/3/25.
//  Refactored to actor extension on 28/01/26.
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
        for columnName: String,
        from table: SQLiteTable
    ) async throws {
        guard let value = record.values[columnName] else { return }

        var update = try db
            .update(table.name)
            .set(columnName, to: sqlExpression(for: value))

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
        case .null:
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
