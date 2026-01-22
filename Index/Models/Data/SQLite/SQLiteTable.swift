//
//  Table.swift
//  Index
//
//  Created by Axel Martinez on 11/3/25.
//

class SQLiteTable: Equatable, Hashable {
    var name: String
    var columns: [SQLiteColumn]
    var recordCount: Int

    init(name: String, columns: [SQLiteColumn], recordCount: Int) {
        self.name = name
        self.recordCount = recordCount
        self.columns = columns
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(columns)
        hasher.combine(recordCount)
    }
    
    static func == (lhs: SQLiteTable, rhs: SQLiteTable) -> Bool {
        lhs.name == rhs.name &&
        lhs.columns == rhs.columns &&
        lhs.recordCount == rhs.recordCount
    }
}
