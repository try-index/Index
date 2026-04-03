//
//  TabBehavior.swift
//  Index
//
//  Created by Axel Martinez on 16/2/26.
//

import Foundation

enum TabBehavior: String, CaseIterable, Identifiable {
    case reuseCurrentTab = "reuse"
    case alwaysNewTab = "new"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .reuseCurrentTab:
            return "Reuse Current Tab"
        case .alwaysNewTab:
            return "Always Open in New Tab"
        }
    }
    
    var description: String {
        switch self {
        case .reuseCurrentTab:
            return "Clicking a table replaces the current tab content"
        case .alwaysNewTab:
            return "Clicking a table always opens a new tab"
        }
    }
}

extension UserDefaults {
    private enum Keys {
        static let tabBehavior = "tabBehavior"
    }
    
    var tabBehavior: TabBehavior {
        get {
            guard let rawValue = string(forKey: Keys.tabBehavior),
                  let behavior = TabBehavior(rawValue: rawValue) else {
                return .reuseCurrentTab // Default behavior
            }
            return behavior
        }
        set {
            set(newValue.rawValue, forKey: Keys.tabBehavior)
        }
    }
}
