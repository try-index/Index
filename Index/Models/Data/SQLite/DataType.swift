//
//  FileType.swift
//  Index
//
//  Created by Axel Martinez on 7/4/25.
//

struct FileType {
    let description: String
    let value: Value
    
    init(_ description: String, _ value: Value) {
        self.description = description
        self.value = value
    }
}
