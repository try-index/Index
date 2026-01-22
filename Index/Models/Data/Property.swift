//
//  Record.swift
//  Index
//
//  Created by Axel Martinez on 4/4/25.
//

import CoreData
import SwiftUI

struct Property {
    let name: String
    let type: String
    let column: SQLiteColumn

    // Used to calculate column width, can't calculate it here
    // because Font is determined in the View
    var displayName: String {
        "\(name): \(type)"
    }
    
    init(attribute: NSAttributeDescription, column: SQLiteColumn) {
        self.name = attribute.name
        self.column = column
        
        var typeString = ""
        
        switch attribute.type {
        case .binaryData:
            typeString = "Data"
        case .boolean:
            typeString = "Bool"
        case .date:
            typeString = "Date"
        case .decimal:
            typeString = "Decimal"
        case .double:
            typeString = "Double"
        case .float:
            typeString = "Float"
        case .integer16, .integer32, .integer64:
            typeString = "Int"
        default :
            typeString = "String"
        }
      
        if attribute.isOptional {
            typeString.append("?")
        }
        
        self.type = typeString
    }
    
    init(column: SQLiteColumn) {
        self.name = column.name
        self.type = column.datatype
        self.column = column
    }
}
