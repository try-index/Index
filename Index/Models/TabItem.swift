//
//  TabItem.swift
//  Index
//
//  Created by Axel Martinez on 16/2/26.
//

import Foundation

struct TabItem<T: SQLiteTable>: Identifiable, Hashable {
    let id = UUID()
    let table: T
    let title: String
    let sqlQuery: String?
    let filterValue: Value?
    let filterColumn: String?
    
    init(table: T, title: String? = nil, sqlQuery: String? = nil, filterValue: Value? = nil, filterColumn: String? = nil) {
        self.table = table
        self.title = title ?? (table as? Entity)?.displayName ?? table.name
        self.sqlQuery = sqlQuery
        self.filterValue = filterValue
        self.filterColumn = filterColumn
    }
    
    static func == (lhs: TabItem<T>, rhs: TabItem<T>) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
