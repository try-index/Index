//
//  Record.swift
//  Index
//
//  Created by Axel Martinez on 14/11/24.
//

import Foundation
import SQLiteKit
import SwiftUI

struct Record: Identifiable, Equatable, Hashable {
    var id: UUID
    var rowId: Int?
    var values: [String: Value]
    
    init(_ row: any SQLRow, from columns: [SQLiteColumn]) throws {
        self.id = UUID()
        self.rowId = try? row.decode(column: "rowId", as: Int.self)
        self.values = [String: Value]()
        
        for column in columns {
            switch column.datatype {
            case "SMALLINT":
                if let value = try? row.decode(column: column.name, as: Int16.self) {
                    values[column.name] = .smallint(value)
                }
            case "INTEGER":
                if let value = try? row.decode(column: column.name, as: Int.self) {
                    values[column.name] = .integer(value)
                }
            case "BIGINT", "FLOAT":
                if let value = try? row.decode(column: column.name, as: Float.self) {
                    values[column.name] = .float(value)
                }
            case "TEXT", "VARCHAR", "NVARCHAR":
                if let value = try? row.decode(column: column.name, as: String.self) {
                    values[column.name] = .text("\"\(value)\"")
                }
            case "REAL":
                if let value = try? row.decode(column: column.name, as: Double.self) {
                    values[column.name] = .real(value)
                }
            case "BLOB":
                if let data = try? row.decode(column: column.name, as: Data.self) {
                    values[column.name] = extractValue(from: data)
                }
            case "TIMESTAMP":
                if let value = try? row.decode(column: column.name, as: Date.self) {
                    values[column.name] = .timestamp(value)
                }
            default:
                break
            }
  
            if values[column.name] == nil {
                values[column.name] = .null
            }
        }
    }
    
    func decodeImage(from data: Data) -> Value {
        guard let image = NSImage(data: data) else {
            return .null
        }
        
        return .image(image)
    }
    
    func decodeText(from data: Data) -> Value {
        guard var string = data.decodedString() else {
            return .null
        }
        
           /* if str.hasPrefix("<?xml") {
                return "XML document"
            } else if str.hasPrefix("{") || str.hasPrefix("[") {
                return "JSON data"
            } else if str.hasPrefix("<!DOCTYPE html") || str.hasPrefix("<html") {
                return "HTML document"
            } else if str.hasPrefix("<!DOCTYPE") {
                return "SGML/XML document"
            } else if str.contains("BEGIN:VCALENDAR") {
                return "iCalendar file"
            } else if str.contains("BEGIN:VCARD") {
                return "vCard file"
            } else if str.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("#!") {
                return "Shell script"
            }*/
        
        if string.hasPrefix("[") && string.hasSuffix("]") {
            string.removeFirst()
            string.removeLast()
                // If all lines look like array elements (e.g., start with quotes, or don't contain special characters)
                // this is a heuristic and might need adjustment for your specific case
           let elements = string.components(separatedBy: ",").map({
                if ($0.hasPrefix("\"") && $0.hasSuffix("\"")) ||
                    ($0.hasPrefix("'") && $0.hasSuffix("'")) {
                    return Value.text($0)
                } else {
                    guard let integer = Int($0) else {
                        return .null
                    }
                    
                    return Value.integer(integer)
                }
            })

            return .array(elements)
        }

        return .text(string)
    }
    
    func extractValue(from data: Data) -> Value {
        // Dictionary of common file signatures (magic bytes) and their corresponding file types
        let fileSignatures: [Data: Value] = [
            Data([0xFF, 0xD8, 0xFF]): decodeImage(from: data), // "JPEG image"
            Data([0x89, 0x50, 0x4E, 0x47]): decodeImage(from: data), //"PNG image"
            Data([0x47, 0x49, 0x46, 0x38]): decodeImage(from: data),//"GIF image"
            Data([0x42, 0x4D]): decodeImage(from: data) //"BMP image"
            /*Data([0x25, 0x50, 0x44, 0x46]): "PDF document",
            Data([0x50, 0x4B, 0x03, 0x04]): "ZIP archive or Office document",
            Data([0x1F, 0x8B]): "GZIP archive",
            Data([0x52, 0x61, 0x72, 0x21]): "RAR archive",
            Data([0x7B, 0x5C, 0x72, 0x74]): "RTF document",
            Data([0x49, 0x44, 0x33]): "MP3 audio (ID3)",
            Data([0xFF, 0xFB]): "MP3 audio (without ID3)",
            Data([0x66, 0x74, 0x79, 0x70]): "MP4 video",
            Data([0x38, 0x42, 0x50, 0x53]): "Photoshop document",
            Data([0x00, 0x00, 0x00, 0x0C, 0x6A, 0x50, 0x20]): "JPEG 2000",
            Data([0x4F, 0x67, 0x67, 0x53]): "OGG audio/video",
            Data([0x1A, 0x45, 0xDF, 0xA3]): "WebM/MKV video",
            Data([0x00, 0x00, 0x00, 0x14, 0x66, 0x74, 0x79, 0x70]): "MOV video"*/
        ]
        
        // Check each signature against the start of the data
        for (signature, fileType) in fileSignatures {
            if data.count >= signature.count {
                let dataPrefix = data.prefix(signature.count)
                if dataPrefix == signature {
                    return fileType
                }
            }
        }
        
        /*/ Special case for MP4/ISO files which might have the "ftyp" marker at byte 4
        if data.count > 8 {
            let range = 4..<8
            if data[range] == Data([0x66, 0x74, 0x79, 0x70]) {
                return "MP4/ISO media"
            }
        } */
        
        // Try to decode as a property list (plist)
        if let plistArray = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String] {
            return .text(plistArray.joined(separator: ","))
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
