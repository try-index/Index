//
//  SQLManager+Edit.swift
//  Index
//
//  Created by Axel Martinez on 6/3/25.
//

extension SQLiteManager {
    func addRecord(_ record: Record, to table: SQLiteTable) async throws {
        // Prepare SQL query
        let columnNames = table.columns.map { $0.name }
        let insertClause = buildInsertClause(for: columnNames, in: record)
        let query = "INSERT INTO \(table.name) (\(insertClause)"
        
        // Execute query
        try await runQuery(query)
    }
    
    func deleteRecords(_ records: [Record], from table: SQLiteTable) async throws {
        var statements: [String] = []
        
        for record in records {
            statements.append(buildWhereClause(for: record, in: table))
        }
        
        let whereClause = statements.joined(separator: " OR ")
        
        // Prepare SQL query
        let query = "DELETE FROM \(table.name) WHERE \(whereClause)"
        
        // Execute query
        try await runQuery(query)
    }
    
    func updateRecord(
        _ record: Record,
        for columnName: String,
        from table: SQLiteTable
    ) async throws {
        let setClause = buildSetClause(for: [columnName], in: record)
        let whereClause = buildWhereClause(for: record, in: table)
        let query = "UPDATE \(table.name) SET \(setClause) WHERE \(whereClause)"
        
        try await runQuery(query)
    }
    
    func updateRecord(
        _ record: Record,
        from table: SQLiteTable
    ) async throws {
        let setClause = buildSetClause(for: table.columns.map { $0.name }, in: record)
        let whereClause = buildWhereClause(for: record, in: table)
        let query = "UPDATE \(table.name) SET \(setClause) WHERE \(whereClause)"
        
        try await runQuery(query)
    }

    private func buildInsertClause(for columnNames: [String], in record: Record) -> String {
        // Build insert query
        let columns = columnNames.joined(separator: ", ")
        let values = record.values.compactMap{
            switch record.values[$0.key] {
            case .text(let text):
                return text
            case .integer(let integer):
                return "\(integer)"
            default:
                return nil
            }
        }.joined(separator: ",")
        
        return "(\(columns)) VALUES (\(values))"
    }

    private func buildSetClause(for columnNames: [String], in record: Record) -> String {
        return columnNames.compactMap {
            switch record.values[$0] {
            case .text(let text):
                return "\($0) = '\(text)'"
            case .integer(let integer):
                return "\($0) = \(integer)"
            default:
                return nil
            }
        }.joined(separator: ",")
    }

    private func buildWhereClause(for record: Record, in table: SQLiteTable) -> String {
        var whereClause = table.columns.filter { $0.pk > 0 }.compactMap {
            if let value = record.values[$0.name] {
                return "\($0.name) = \(value)"
            }
            return nil
        }.joined(separator: ",")
        
        if whereClause.isEmpty {
            if let rowId = record.rowId {
                whereClause = "rowid = \(rowId)"
            } else {
                fatalError("Missing pk or rowId")
            }
        }
        
        return whereClause
    }
}
