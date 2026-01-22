//
//  Entity.swift
//  Index
//
//  Created by Axel Martinez on 18/11/24.
//

class Entity: SQLiteTable {
    let displayName: String
    let properties: [String: Property]
    
    required init(
        displayName: String,
        properties: [String: Property],
        tableName: String,
        tableColumns: [SQLiteColumn],
        recordCount: Int = 0
    ) {
        self.displayName = displayName
        self.properties = properties
        
        super.init(name: tableName, columns: tableColumns, recordCount: recordCount)
    }
    
    required init(from decoder: any Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
}
