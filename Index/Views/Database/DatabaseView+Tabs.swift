//
//  DatabaseView+Tabs.swift
//  Index
//
//  Created by Axel Martinez on 18/2/26.
//

import SwiftUI

extension DatabaseView {
    
    func openTab(for table: T, filterColumn: String? = nil, filterValue: Value? = nil, forceNewTab: Bool = false) {
        // Check if tab already exists
        if let existingTab = tabs.first(where: {
            $0.table.name == table.name &&
            $0.filterColumn == filterColumn &&
            $0.filterValue == filterValue
        }) {
            selectedTab = existingTab
            return
        }
        
        // Generate SQL query for display
        let sqlQuery = generateSQLQuery(for: table, filterColumn: filterColumn, filterValue: filterValue)
        
        // Create title
        var title = (table as? Entity)?.displayName ?? table.name
        
        if let filterColumn = filterColumn, let filterValue = filterValue {
            let valueString = formatValueForDisplay(filterValue)
            let displayColumn = formatColumnForDisplay(filterColumn, table: table)
            title += " (\(displayColumn) = \(valueString))"
        }
        
        let newTab = TabItem(
            table: table,
            title: title,
            sqlQuery: sqlQuery,
            filterValue: filterValue,
            filterColumn: filterColumn
        )
        
        // Get user preference for tab behavior
        let tabBehavior = UserDefaults.standard.tabBehavior
        
        // Determine if we should reuse current tab
        let shouldReuseTab: Bool
        
        if forceNewTab {
            // Always create new tab when explicitly requested (FK links)
            shouldReuseTab = false
        } else if filterColumn != nil || filterValue != nil {
            // Never reuse for filtered views
            shouldReuseTab = false
        } else if tabBehavior == .alwaysNewTab {
            // User preference: always new tab
            shouldReuseTab = false
        } else if tabs.isEmpty {
            // No tabs exist yet
            shouldReuseTab = false
        } else if let selectedTab = selectedTab {
            // Reuse the currently selected tab
            if let index = tabs.firstIndex(where: { $0.id == selectedTab.id }) {
                tabs[index] = newTab
                self.selectedTab = newTab
                return
            }
            shouldReuseTab = false
        } else {
            shouldReuseTab = false
        }
        
        if shouldReuseTab {
            // This shouldn't happen but handle it anyway
            if !tabs.isEmpty {
                tabs[0] = newTab
                selectedTab = newTab
            } else {
                tabs.append(newTab)
                selectedTab = newTab
            }
        } else {
            tabs.append(newTab)
            selectedTab = newTab
        }
    }
    
    func closeTab(_ tab: TabItem<T>) {
        guard let index = tabs.firstIndex(of: tab) else {
            return
        }
        
        tabs.remove(at: index)
        
        // Select another tab if the closed one was selected
        if selectedTab?.id == tab.id {
            if !tabs.isEmpty {
                selectedTab = index < tabs.count ? tabs[index] : tabs[index - 1]
            } else {
                selectedTab = nil
            }
        }
    }
    
    func openRelatedTable(table: T, column: String, value: Value) {
        // Always open foreign key links in a new tab
        openTab(for: table, filterColumn: column, filterValue: value, forceNewTab: true)
    }
    
    private func formatColumnForDisplay(_ column: String, table: T) -> String {
        // For CoreData/SwiftData entities, try to find the property name that matches this column
        if table is Entity {
            // Z_PK is the internal primary key for CoreData/SwiftData
            if column == "Z_PK" {
                return "id"
            }
            if let entity = table as? Entity,
               let property = entity.properties.values.first(where: { $0.column.name == column }) {
                return property.name
            }
        }
        return column
    }
    
    private func generateSQLQuery(for table: T, filterColumn: String?, filterValue: Value?) -> String {
        var query = "SELECT * FROM \(table.name)"
        
        if let filterColumn = filterColumn, let filterValue = filterValue {
            let valueString = formatValueForSQL(filterValue)
            query += "\nWHERE \(filterColumn) = \(valueString)"
        }
        
        query += ";"
        return query
    }
   
    private func formatValueForSQL(_ value: Value) -> String {
        switch value {
        case .null:
            return "NULL"
        case .undefined:
            return "NULL"
        case .integer(let int):
            return "\(int)"
        case .smallint(let int):
            return "\(int)"
        case .real(let double):
            return "\(double)"
        case .float(let float):
            return "\(float)"
        case .text(let string):
            return "'\(string.replacingOccurrences(of: "'", with: "''"))'"
        case .uuid(let uuid):
            return "<UUID: \(uuid.uuidString)>"
        case .data(let string):
            return string
        case .enumValue(let caseName):
            // Try to parse as integer first
            if let _ = Int(caseName) {
                return caseName
            } else {
                return "'\(caseName.replacingOccurrences(of: "'", with: "''"))'"
            }
        case .timestamp(let date):
            return "'\(date.ISO8601Format())'"
        case .array, .image:
            return "<BLOB>"
        }
    }
    
    private func formatValueForDisplay(_ value: Value) -> String {
        switch value {
        case .null:
            return "NULL"
        case .undefined:
            return ""
        case .integer(let int):
            return "\(int)"
        case .smallint(let int):
            return "\(int)"
        case .real(let double):
            return "\(double)"
        case .float(let float):
            return "\(float)"
        case .text(let string):
            return string
        case .uuid(let uuid):
            return uuid.uuidString
        case .data(let string):
            return string
        case .enumValue(let caseName):
            return ".\(caseName)"
        case .timestamp(let date):
            return date.ISO8601Format()
        case .array, .image:
            return "<DATA>"
        }
    }
}
