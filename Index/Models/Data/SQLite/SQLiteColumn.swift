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
    
    init(name: String, datatype: String, notNull: Bool, pk: Int) {
        self.name = name
        self.datatype = datatype
        self.notNull = notNull
        self.pk = pk
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(datatype)
        hasher.combine(notNull)
        hasher.combine(pk)
    }
    
    static func == (lhs: SQLiteColumn, rhs: SQLiteColumn) -> Bool {
        lhs.name == rhs.name &&
        lhs.datatype == rhs.datatype &&
        lhs.notNull == rhs.notNull &&
        lhs.pk == rhs.pk
    }
}
