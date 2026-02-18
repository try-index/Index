//
//  Record.swift
//  Index
//
//  Created by Axel Martinez on 14/11/24.
//

import Foundation
import AppKit
import SQLiteKit

struct Record: Identifiable, Equatable, Hashable {
    var id: UUID
    var rowId: Int?
    var values: [String: Value]
    var relationshipPreviews: [String: RelationshipPreview] = [:]
    
    init(id: UUID = UUID(), rowId: Int? = nil, values: [String: Value], relationshipPreviews: [String: RelationshipPreview] = [:]) {
        self.id = id
        self.rowId = rowId
        self.values = values
        self.relationshipPreviews = relationshipPreviews
    }
    
    struct RelationshipPreview: Hashable {
        let count: Int
        let firstValue: String?
    }
    
    init(_ row: any SQLRow, from columns: [SQLiteColumn]) throws {
        self.id = UUID()
        self.rowId = try? row.decode(column: "rowId", as: Int.self)
        self.values = [String: Value]()
        
        for column in columns {
            let datatype = column.datatype.uppercased()
            
            // Skip virtual columns for to-many relationships - they don't have values in the database
            if datatype == "RELATIONSHIP" {
                values[column.name] = .undefined  // Placeholder for inverse relationships
                continue
            }
            
            // Check for special attribute types from CoreData/SwiftData metadata first
            if let attributeType = column.attributeType {
                switch attributeType {
                case .uuid:
                    // Try to decode UUID from BLOB
                    if let data = try? row.decode(column: column.name, as: Data.self) {
                        if let decodedValue = decodeBlobData(data) {
                            values[column.name] = decodedValue
                        }
                    }
                    // If that didn't work, continue to regular processing
                    if values[column.name] != nil {
                        continue
                    }
                case .externalStorage:
                    // External storage can store file references as strings or BLOBs
                    // Try as string first
                    if let value = try? row.decode(column: column.name, as: String.self) {
                        values[column.name] = .data(value)
                    }
                    // If not a string, try as BLOB
                    else if let data = try? row.decode(column: column.name, as: Data.self) {
                        if let decodedValue = decodeBlobData(data) {
                            // Convert any .text() to .data() for external storage
                            if case .text(let str) = decodedValue {
                                values[column.name] = .data(str)
                            } else {
                                values[column.name] = decodedValue
                            }
                        } else {
                            let extracted = extractValue(from: data)
                            // Convert any .text() to .data() for external storage
                            if case .text(let str) = extracted {
                                values[column.name] = .data(str)
                            } else {
                                values[column.name] = extracted
                            }
                        }
                    }
                    if values[column.name] != nil {
                        continue
                    }
                case .transformable:
                    // Transformable types are stored as BLOB
                    if let data = try? row.decode(column: column.name, as: Data.self) {
                        if let decodedValue = decodeBlobData(data) {
                            values[column.name] = decodedValue
                        } else {
                            values[column.name] = extractValue(from: data)
                        }
                    }
                    if values[column.name] != nil {
                        continue
                    }
                case .composite:
                    // Composite types (enums) are typically stored as INTEGER or BLOB
                    // Try INTEGER first (most common for enums with raw values)
                    if let intValue = try? row.decode(column: column.name, as: Int.self) {
                        values[column.name] = .enumValue("\(intValue)")
                    }
                    // Try BLOB (for enums conforming to Codable)
                    else if let data = try? row.decode(column: column.name, as: Data.self) {
                        if let decodedValue = decodeBlobData(data) {
                            // Convert to enum value for proper display
                            if case .text(let str) = decodedValue {
                                values[column.name] = .enumValue(str)
                            } else {
                                values[column.name] = decodedValue
                            }
                        } else {
                            values[column.name] = extractValue(from: data)
                        }
                    }
                    // Try STRING (for string-based enums)
                    else if let stringValue = try? row.decode(column: column.name, as: String.self) {
                        values[column.name] = .enumValue(stringValue)
                    }
                    if values[column.name] != nil {
                        continue
                    }
                }
            }
            
            // Match datatype by prefix/contains to handle type specifications like VARCHAR(255)
            if datatype.hasPrefix("SMALLINT") {
                if let value = try? row.decode(column: column.name, as: Int16.self) {
                    values[column.name] = .smallint(value)
                }
            } else if datatype.hasPrefix("INTEGER") || datatype.hasPrefix("INT") {
                if let value = try? row.decode(column: column.name, as: Int.self) {
                    values[column.name] = .integer(value)
                }
            } else if datatype.hasPrefix("BIGINT") || datatype.hasPrefix("FLOAT") {
                if let value = try? row.decode(column: column.name, as: Float.self) {
                    values[column.name] = .float(value)
                }
            } else if datatype.hasPrefix("TEXT") || datatype.hasPrefix("VARCHAR") || 
                      datatype.hasPrefix("NVARCHAR") || datatype.hasPrefix("CHAR") ||
                      datatype.hasPrefix("CLOB") {
                if let value = try? row.decode(column: column.name, as: String.self) {
                    values[column.name] = .text(value)
                }
            } else if datatype.hasPrefix("REAL") || datatype.hasPrefix("DOUBLE") || 
                      datatype.hasPrefix("NUMERIC") || datatype.hasPrefix("DECIMAL") {
                if let value = try? row.decode(column: column.name, as: Double.self) {
                    values[column.name] = .real(value)
                }
            } else if datatype.hasPrefix("BLOB") {
                if let data = try? row.decode(column: column.name, as: Data.self) {
                    // Try to decode as various formats
                    if let decodedValue = decodeBlobData(data) {
                        values[column.name] = decodedValue
                    } else {
                        values[column.name] = extractValue(from: data)
                    }
                }
            } else if datatype.hasPrefix("TIMESTAMP") || datatype.hasPrefix("DATETIME") || 
                      datatype.hasPrefix("DATE") {
                if let value = try? row.decode(column: column.name, as: Date.self) {
                    values[column.name] = .timestamp(value)
                }
            }
  
            if values[column.name] == nil {
                values[column.name] = .null
            }
        }
    }
    
    func decodeBlobData(_ data: Data) -> Value? {
        // Don't try to decode very large blobs as text (likely images/files)
        guard data.count < 10000 else { return nil }
        
        // Try as raw UUID bytes (16 bytes) - most common case for identifiers
        if data.count == 16 {
            let uuid = UUID(uuid: (
                data[0], data[1], data[2], data[3],
                data[4], data[5], data[6], data[7],
                data[8], data[9], data[10], data[11],
                data[12], data[13], data[14], data[15]
            ))
            return .uuid(uuid)
        }
        
        // Try UTF-8 string for small data
        if data.count < 1000, let stringValue = String(data: data, encoding: .utf8), !stringValue.isEmpty {
            // Quick check - if it contains null bytes, it's binary
            if !stringValue.contains("\0") {
                // Check if it's a UUID string
                if UUID(uuidString: stringValue) != nil {
                    return .data(stringValue)
                }
                // Check if it looks like a file path or reference
                if stringValue.hasPrefix("/") || stringValue.hasPrefix("file://") {
                    return .data(stringValue)
                }
                return .text(stringValue)
            }
        }
        
        return nil
    }
    
    func decodeImage(from data: Data) -> Value {
        guard let image = NSImage(data: data) else {
            return .null
        }
        
        return .image(image)
    }
    
    func decodeText(from data: Data) -> Value {
        guard let string = data.decodedString() else {
            return .null
        }
        
        // Check for common text file formats
        if string.hasPrefix("<?xml") {
            return .data("<XML document>")
        } else if string.hasPrefix("{") || string.hasPrefix("[") {
            // Could be JSON, check if it's an array format we parse
            if string.hasPrefix("[") && string.hasSuffix("]") {
                // Try to parse as simple array
                var arrayContent = string
                arrayContent.removeFirst()
                arrayContent.removeLast()
                
                let elements = arrayContent.components(separatedBy: ",").map { element in
                    let trimmed = element.trimmingCharacters(in: .whitespaces)
                    if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
                       (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
                        return Value.text(trimmed)
                    } else if let integer = Int(trimmed) {
                        return Value.integer(integer)
                    } else {
                        return .null
                    }
                }
                
                return .array(elements)
            }
            return .data("<JSON data>")
        } else if string.hasPrefix("<!DOCTYPE html") || string.hasPrefix("<html") {
            return .data("<HTML document>")
        } else if string.hasPrefix("<!DOCTYPE") {
            return .data("<SGML/XML document>")
        } else if string.contains("BEGIN:VCALENDAR") {
            return .data("<iCalendar file>")
        } else if string.contains("BEGIN:VCARD") {
            return .data("<vCard file>")
        } else if string.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("#!") {
            return .data("<Shell script>")
        }
        
        return .text(string)
    }
    
    func extractValue(from data: Data) -> Value {
        // Check for images first (decode the actual image)
        if data.count >= 3 && data.starts(with: Data([0xFF, 0xD8, 0xFF])) {
            return decodeImage(from: data) // JPEG
        }
        if data.count >= 4 && data.starts(with: Data([0x89, 0x50, 0x4E, 0x47])) {
            return decodeImage(from: data) // PNG
        }
        if data.count >= 4 && data.starts(with: Data([0x47, 0x49, 0x46, 0x38])) {
            return decodeImage(from: data) // GIF
        }
        if data.count >= 2 && data.starts(with: Data([0x42, 0x4D])) {
            return decodeImage(from: data) // BMP
        }
        
        // Dictionary of other file signatures (magic bytes) and their type descriptions
        let fileSignatures: [(signature: Data, description: String)] = [
            (Data([0x25, 0x50, 0x44, 0x46]), "PDF document"),
            (Data([0x50, 0x4B, 0x03, 0x04]), "ZIP archive or Office document"),
            (Data([0x1F, 0x8B]), "GZIP archive"),
            (Data([0x52, 0x61, 0x72, 0x21]), "RAR archive"),
            (Data([0x7B, 0x5C, 0x72, 0x74]), "RTF document"),
            (Data([0x49, 0x44, 0x33]), "MP3 audio (ID3)"),
            (Data([0xFF, 0xFB]), "MP3 audio (without ID3)"),
            (Data([0x66, 0x74, 0x79, 0x70]), "MP4 video"),
            (Data([0x38, 0x42, 0x50, 0x53]), "Photoshop document"),
            (Data([0x00, 0x00, 0x00, 0x0C, 0x6A, 0x50, 0x20]), "JPEG 2000"),
            (Data([0x4F, 0x67, 0x67, 0x53]), "OGG audio/video"),
            (Data([0x1A, 0x45, 0xDF, 0xA3]), "WebM/MKV video"),
            (Data([0x00, 0x00, 0x00, 0x14, 0x66, 0x74, 0x79, 0x70]), "MOV video")
        ]
        
        // Check each signature against the start of the data
        for (signature, description) in fileSignatures {
            if data.count >= signature.count && data.starts(with: signature) {
                return .data("<\(description)>")
            }
        }
        
        // Special case for MP4/ISO files which might have the "ftyp" marker at byte 4
        if data.count > 8 {
            let range = 4..<8
            if data[range] == Data([0x66, 0x74, 0x79, 0x70]) {
                return .data("MP4/ISO media")
            }
        }
        
        // Try to decode as a property list (plist)
        if let plistArray = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String] {
            return .data(plistArray.joined(separator: ","))
        }
        
        // Try to decode as text
        return decodeText(from: data)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Record, rhs: Record) -> Bool {
        lhs.id == rhs.id
    }
    
}
