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
        
        var typeString = ""
        var attributeType: SQLiteColumn.AttributeType? = nil
        
        // Check if this is an external storage attribute (stores file references)
        if attribute.allowsExternalBinaryDataStorage {
            typeString = "Data"
            attributeType = .externalStorage
        }
        // First, check if this is a UUID regardless of the declared type
        else if let className = attribute.attributeValueClassName,
           (className == "NSUUID" || className == "UUID" || className.hasSuffix(".UUID")) {
            typeString = "UUID"
            attributeType = .uuid
        } else {
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
            case .string:
                typeString = "String"
            case .transformable:
                typeString = "Transformable"
                if let transformer = attribute.valueTransformerName {
                    attributeType = .transformable(transformer)
                } else {
                    attributeType = .transformable(nil)
                }
            case .objectID:
                typeString = "ObjectID"
            case .undefined:
                typeString = "Undefined"
            case .composite:
                // Composite types are typically enums or custom types in SwiftData
                // Try to get the actual type name from the value class
                if let className = attribute.attributeValueClassName {
                    // Extract the enum name from the full class path
                    // e.g., "MyApp.MyEnum" -> "MyEnum"
                    if let enumName = className.split(separator: ".").last {
                        let enumNameStr = String(enumName)
                        // NSDictionary is the storage type for composite enums, use generic "Enum" label
                        if enumNameStr == "NSDictionary" {
                            typeString = "Enum"
                        } else {
                            typeString = enumNameStr
                        }
                    } else {
                        typeString = className == "NSDictionary" ? "Enum" : className
                    }
                } else {
                    typeString = "Enum"
                }
                attributeType = .composite
            default:
                typeString = "String"
            }
        }
      
        if attribute.isOptional {
            typeString.append("?")
        }
        
        self.type = typeString
        
        // Create new column with attribute type information
        self.column = SQLiteColumn(
            name: column.name,
            datatype: column.datatype,
            notNull: column.notNull,
            pk: column.pk,
            foreignKey: column.foreignKey,
            attributeType: attributeType
        )
    }
    
    init(column: SQLiteColumn) {
        self.name = column.name
        self.type = column.datatype
        self.column = column
    }
    
    init(relationship: NSRelationshipDescription, column: SQLiteColumn) {
        self.name = relationship.name
        self.column = column
        
        // Format type based on destination entity and optionality
        var typeString = relationship.destinationEntity?.name ?? "Unknown"
        if relationship.isOptional {
            typeString.append("?")
        }
        
        self.type = typeString
    }
    
    init(toManyRelationship relationship: NSRelationshipDescription) {
        self.name = relationship.name
        
        // For to-many relationships, we need to find the inverse relationship column
        // The inverse relationship tells us which column in the destination table points back to this entity
        let inverseColumnName: String
        if let inverseName = relationship.inverseRelationship?.name {
            // Convert to CoreData column format (add Z prefix and uppercase)
            inverseColumnName = "Z\(inverseName.uppercased())"
        } else {
            // Fallback if no inverse relationship is defined
            inverseColumnName = "Z_PK"
        }
        
        // Create a virtual column for to-many relationships
        // These don't have physical SQLite columns but need to be represented
        self.column = SQLiteColumn(
            name: relationship.name,
            datatype: "RELATIONSHIP",
            notNull: false,
            pk: 0,
            foreignKey: relationship.destinationEntity?.name.map {
                SQLiteColumn.ForeignKey(table: $0, column: inverseColumnName)
            }
        )
        
        // Format type as array of destination entity
        let destinationName = relationship.destinationEntity?.name ?? "Unknown"
        self.type = "[\(destinationName)]"
    }
}
