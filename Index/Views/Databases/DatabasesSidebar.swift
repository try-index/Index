//
//  DatabasesSidebar.swift
//  Index
//
//  Created by Axel Martinez on 27/1/26.
//

import SwiftUI

struct DatabasesSidebar: View {
    @EnvironmentObject var databasesManager: DatabasesManager

    @Binding var selectedSidebarItem: SidebarItem?

    let onAddGroup: () -> Void
    let onDeleteGroup: () -> Void

    private var canDeleteSelectedGroup: Bool {
        if case .group = selectedSidebarItem {
            return true
        }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedSidebarItem) {
                // All Databases
                Label("All Databases", systemImage: "cylinder.split.1x2")
                    .tag(SidebarItem.allDatabases)

                // Groups section
                if !databasesManager.groups.isEmpty {
                    ForEach(databasesManager.groups) { group in
                        Label(group.name, systemImage: "folder")
                            .tag(SidebarItem.group(group))
                            .contextMenu {
                                Button("Delete Group", role: .destructive) {
                                    databasesManager.removeGroup(group)
                                }
                            }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            // Bottom toolbar for groups
            HStack(spacing: 4) {
                Button(action: onAddGroup) {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help("Add Group")

                Button(action: onDeleteGroup) {
                    Image(systemName: "minus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .disabled(!canDeleteSelectedGroup)
                .help("Delete Group")

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(minWidth: 180)
    }
}
