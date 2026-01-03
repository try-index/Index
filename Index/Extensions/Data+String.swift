//
//  Data+String.swift
//  Data Inspector
//
//  Created by Axel Martinez on 8/4/25.
//

import Foundation

extension Data {
    func decodedString() -> String? {
        return String(data: self, encoding: .utf8) ?? String(data: self, encoding: .ascii)
    }
}
