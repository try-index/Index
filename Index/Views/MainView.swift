//
//  MainView.swift
//  Data Inspector
//
//  Created by Axel Martinez on 13/11/24.
//

import Combine
import SwiftUI

struct MainView<T: SQLiteTable>: View {
    @StateObject var sqlManager: SQLiteManager = .init()
    @StateObject var simManager: SimulatorManager = .init()
    
    @Binding var isFileDialogOpen: Bool
    @Binding var isSimulatorsDialogOpen: Bool
    
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var selectedTable: T?
    @State private var searchText: String = ""
    @State private var refreshContent: PassthroughSubject<Void, Never> = .init()
    
    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            SidebarView(selection: $selectedTable)
                .toolbar(removing: selectedTable == nil ? .sidebarToggle : nil)
                .environmentObject(sqlManager)
        } detail: {
            if let selectedTable = selectedTable {
                ContentView(
                    searchText: $searchText,
                    dataObject: selectedTable,
                    refresh: refreshContent
                )
                .environmentObject(sqlManager)
                .environmentObject(simManager)
            } else {
                ContentUnavailableView {
                    Label {
                        Text("Open database")
                    } icon: {
                        Image("database.search")
                    }
                } description: {
                    Text("Open a database to load its content.")
                } actions: {
                    Button("Open file...") { self.isFileDialogOpen.toggle() }
                    Button("Browse simulators...") { self.isSimulatorsDialogOpen.toggle() }
                }
            }
        }
        .navigationTitle("")
        .searchable(text: $searchText)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                FileMenu(
                    sidebarVisibility: $sidebarVisibility,
                    isFileDialogOpen: $isFileDialogOpen,
                    isSimulatorsDialogOpen: $isSimulatorsDialogOpen
                )
                .environmentObject(sqlManager)
                .environmentObject(simManager)
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button("", systemImage: "arrow.clockwise", action: {
                    refreshContent.send()
                })
                .disabled(self.selectedTable == nil)
            }
        }
    }
}

#Preview {
    @Previewable @State var isFileDialogOpen = false
    @Previewable  @State var isSimulatorsDialogOpen = false
    
    MainView(
        isFileDialogOpen: $isFileDialogOpen,
        isSimulatorsDialogOpen: $isSimulatorsDialogOpen
    )
}
