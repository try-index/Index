//
//  SettingsView.swift
//  Index
//
//  Created by Axel Martinez on 16/2/26.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("tabBehavior") private var tabBehaviorRaw: String = TabBehavior.reuseCurrentTab.rawValue
    
    private var tabBehavior: Binding<TabBehavior> {
        Binding(
            get: { TabBehavior(rawValue: tabBehaviorRaw) ?? .reuseCurrentTab },
            set: { tabBehaviorRaw = $0.rawValue }
        )
    }
    
    var body: some View {
        Form {
            Section {
                Picker("When clicking a table:", selection: tabBehavior) {
                    ForEach(TabBehavior.allCases) { behavior in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(behavior.displayName)
                            Text(behavior.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(behavior)
                    }
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text("Tab Behavior")
            } footer: {
                Text("This setting controls how tables open when clicked in the sidebar. Foreign key links and right-click 'Open in New Tab' always create new tabs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 200)
    }
}

#Preview {
    SettingsView()
}
