//
//  SQLiteColumnDescription.swift
//  Index
//
//  Created by Axel Martinez on 13/3/25.
//

import SQLiteKit

struct SQLiteColumnDescription: Decodable, Equatable, Hashable {
    let name: String
    let datatype: String
    let notNull: Bool
    let pk: Int
}
