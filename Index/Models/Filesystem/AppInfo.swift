//
//  Application.swift
//  Data Inspector
//
//  Created by Axel Martinez on 25/11/24.
//

import SwiftUI

struct AppInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let fileURLs: [URL]
    let icon: NSImage?
}
