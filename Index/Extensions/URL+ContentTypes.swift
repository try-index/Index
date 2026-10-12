//
//  URL+ContentTypes.swift
//  Index
//
//  Created by Axel Martinez on 27/11/24.
//

import Foundation
import UniformTypeIdentifiers

extension URL {
    static var sqlLiteContentTypes: [UTType] {
        ["db", "sqlite", "sqlite3", "store"].compactMap { UTType(filenameExtension: $0) }
    }

    func isSQLiteURL() -> Bool {
        URL.sqlLiteContentTypes.contains(where: {
            self.pathExtension.lowercased() == $0.preferredFilenameExtension?.lowercased()
        })
    }
}
