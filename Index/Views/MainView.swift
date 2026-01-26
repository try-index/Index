//
//  MainView.swift
//  Index
//
//  Created by Axel Martinez on 13/11/24.
//

import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers
import SQLiteNIO

struct MainView<T: SQLiteTable>: View {
    @StateObject var sqlManager: SQLiteManager = .init()
    @StateObject var simManager: SimulatorManager = .init()
    
    @Binding var isFileDialogOpen: Bool
    @Binding var isSimulatorsDialogOpen: Bool
    
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var selectedTable: T?
    @State private var searchText: String = ""
    @State private var refreshContent: PassthroughSubject<Void, Never> = .init()
    @State private var fileOpenError: SQLiteError?
    @State private var showFileOpenError = false
    @State private var showFolderAccessPrompt = false
    @State private var pendingFileURL: URL?
    
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
                    Button("Open file...") { openFilePanel() }
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
        .alert(isPresented: $showFileOpenError, error: fileOpenError) { _ in
            Button("OK") { showFileOpenError = false }
        } message: { error in
            Text(error.recoverySuggestion ?? "Try opening a different file")
        }
        .alert("Read-Only Database", isPresented: $showFolderAccessPrompt) {
            Button("Grant Access") {
                openFolderPanel()
            }
            Button("Keep Read-Only", role: .cancel) {
                pendingFileURL = nil
            }
        } message: {
            Text("This database was opened in read-only mode. To enable editing, grant access to the folder containing the database file.")
        }
        .onChange(of: isFileDialogOpen) { _, newValue in
            if newValue {
                isFileDialogOpen = false
                openFilePanel()
            }
        }
    }

    private func openFilePanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = URL.sqlLiteContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        // Add read-only checkbox
        let checkbox = NSButton(checkboxWithTitle: "Open as Read-Only", target: nil, action: nil)
        checkbox.state = .off
        panel.accessoryView = checkbox

        if panel.runModal() == .OK, let url = panel.url {
            let forceReadOnly = checkbox.state == .on
            loadFile(url: url, forceReadOnly: forceReadOnly)
        }
    }

    private func openFolderPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.folder]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false

        if panel.runModal() == .OK, let url = panel.url {
            loadFileWithFolderAccess(result: .success(url))
        }
    }

    private func loadFile(url: URL, forceReadOnly: Bool = false) {
        Task(priority: .userInitiated) {
            guard url.startAccessingSecurityScopedResource() else { return }

            do {
                try await sqlManager.connect(fileURL: url, forceReadOnly: forceReadOnly)
                await MainActor.run {
                    sidebarVisibility = .all
                    // If opened as read-only (not by user choice), prompt for folder access
                    if sqlManager.isReadOnly && !forceReadOnly {
                        pendingFileURL = url
                        showFolderAccessPrompt = true
                    }
                }
            } catch let error as SQLiteError {
                await MainActor.run {
                    fileOpenError = error
                    showFileOpenError = true
                }
            }

            url.stopAccessingSecurityScopedResource()
        }
    }

    private func loadFileWithFolderAccess(result: Result<URL, any Error>) {
        switch result {
        case .success(let folderURL):
            guard let fileURL = pendingFileURL else { return }

            Task(priority: .userInitiated) {
                if folderURL.startAccessingSecurityScopedResource() {
                    do {
                        try await sqlManager.connect(fileURL: fileURL)

                        if !sqlManager.isReadOnly {
                            // Successfully opened read-write
                            sqlManager.setFolderAccess(folderURL)

                            // Store bookmark for future use
                            if let bookmark = try? folderURL.bookmarkData(options: .withSecurityScope) {
                                UserDefaults.standard.set(bookmark, forKey: "folderBookmark_\(fileURL.path)")
                            }
                        } else {
                            folderURL.stopAccessingSecurityScopedResource()
                        }
                    } catch let error as SQLiteError {
                        await MainActor.run {
                            fileOpenError = error
                            showFileOpenError = true
                        }
                        folderURL.stopAccessingSecurityScopedResource()
                    }
                }
            }

            pendingFileURL = nil

        case .failure:
            // User cancelled, keep read-only mode
            pendingFileURL = nil
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
