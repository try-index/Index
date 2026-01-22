//
//  SQLiteStorageClass.swift
//  Index
//
//  Created by Axel Martinez on 13/3/25.
//

public enum SQLiteStorageClass {
    case smallint
    case integer
    case float
    case real
    case text
    case blob
    case null
    case timestamp
}

extension SQLiteStorageClass: Decodable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)
        let trimmedValue: String
        
        if let range = stringValue.range(of: "(") {
            trimmedValue = String(stringValue[..<range.lowerBound])
        } else {
            trimmedValue = stringValue
        }

        switch trimmedValue {
        case "SMALLINT":
            self = .smallint
        case "INTEGER":
            self = .integer
        case "BIGINT", "FLOAT":
            self = .float
        case "TEXT", "VARCHAR", "NVARCHAR":
            self = .text
        case "REAL":
            self = .real
        case "BLOB":
            self = .blob
        case "TIMESTAMP":
            self = .timestamp
        default:
            self = .null
        }
    }
}
