//
//  MenuBarConfigurator.swift
//  Index
//
//  Created by Axel Martinez on 12/12/24.
//

import SwiftUI
import AppKit

extension App {
    static func renameFileMenuToDatabase() {
        guard let mainMenu = NSApplication.shared.mainMenu else { return }

        // Find the File menu (typically at index 1, after the app menu)
        for menuItem in mainMenu.items {
            if menuItem.submenu?.title == "File" {
                menuItem.submenu?.title = "Database"
                break
            }
        }
    }
}
