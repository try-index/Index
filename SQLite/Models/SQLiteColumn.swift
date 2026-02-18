//
//  SQLiteColumn.swift
//  Index
//
//  Created by Axel Martinez on 13/3/25.
//

import Foundation
import SQLiteKit

class SQLiteColumn: Hashable {
    let name: String
    let datatype: String
    let notNull: Bool
    let pk: Int
    let foreignKey: ForeignKey?
    
    struct ForeignKey: Hashable {
        let table: String
        let column: String
    }
    
    init(name: String, datatype: String, notNull: Bool, pk: Int, foreignKey: ForeignKey? = nil) {
        self.name = name
        self.datatype = datatype
        self.notNull = notNull
        self.pk = pk
        self.foreignKey = foreignKey
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(datatype)
        hasher.combine(notNull)
        hasher.combine(pk)
        hasher.combine(foreignKey)
    }
    
    static func == (lhs: SQLiteColumn, rhs: SQLiteColumn) -> Bool {
        lhs.name == rhs.name &&
        lhs.datatype == rhs.datatype &&
        lhs.notNull == rhs.notNull &&
        lhs.pk == rhs.pk &&
        lhs.foreignKey == rhs.foreignKey
    }
}
