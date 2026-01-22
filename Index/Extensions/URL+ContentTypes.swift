//
//  URL+ContentTypes.swift
//  Index
//
//  Created by Axel Martinez on 27/11/24.
//

import Foundation
import UniformTypeIdentifiers

extension URL {
    static var sqlLiteContentTypes: [UTType] { [
        .init(filenameExtension: "db")!,
        .init(filenameExtension: "sqlite")!,
        .init(filenameExtension: "sqlite3")!,
        .init(filenameExtension: "store")!
    ]}
    
    func isSQLiteURL() -> Bool {
        return URL.sqlLiteContentTypes.contains(where: {
            self.pathExtension.lowercased() == $0.preferredFilenameExtension?.lowercased()
        })
    }
}
