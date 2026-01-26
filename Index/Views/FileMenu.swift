//
//  FileMenu.swift
//  Index
//
//  Created by Axel Martinez on 20/11/24.
//

import SwiftUI
import SQLiteNIO

struct FileMenu: View {
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var sqlManager: SQLiteManager
    
    @Binding var sidebarVisibility: NavigationSplitViewVisibility
    @Binding var isFileDialogOpen: Bool
    @Binding var isSimulatorsDialogOpen: Bool
    
    @State private var error: SQLiteError? = nil
    @State private var showAlert = false
    
    var body: some View {
        HStack(spacing: 5) {
            if let fileURL = sqlManager.openFileURL {
                if let appInfo = sqlManager.openAppInfo,
                   let appIcon = appInfo.icon {
                    menuView(text: appInfo.name, content: {
                        Button("Open File…") { self.isFileDialogOpen.toggle() }
                        Button("Browse Simulators…") { self.isSimulatorsDialogOpen.toggle() }
                    }, label: { text in
                        Label { Text(text) } icon: { Image(nsImage: appIcon) }
                    })
                } else {
                    menuView(text: fileURL.deletingLastPathComponent().lastPathComponent, content: {
                        Button("Open File…") { self.isFileDialogOpen.toggle() }
                        Button("Browse Simulators…") { self.isSimulatorsDialogOpen.toggle() }
                    }, label: {
                        Label($0, systemImage: "folder")
                            .labelStyle(.titleAndIcon)
                    })
                }

                Image(systemName: "chevron.forward")

                if sqlManager.openAppInfo?.fileURLs.count ?? 0 > 1 {
                    menuView(text: fileURL.lastPathComponent, content: {
                        if let fileURLs = self.sqlManager.openAppInfo?.fileURLs {
                            ForEach(fileURLs, id: \.self) { fileURL in
                                if fileURL != self.sqlManager.openFileURL {
                                    Button(fileURL.lastPathComponent) {
                                        loadFile(from: fileURL)
                                    }
                                }
                            }
                        }
                    }, label: {
                        Label($0, systemImage: "square.stack.3d.up")
                            .labelStyle(.titleAndIcon)
                    })
                } else {
                    Label(fileURL.lastPathComponent, systemImage: "square.stack.3d.up")
                        .labelStyle(.titleAndIcon)
                }

                if sqlManager.isReadOnly {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                        .help("Opened as read-only")
                }
            }
        }
        .sheet(isPresented: $isSimulatorsDialogOpen, content: {
            SimulatorsView(sidebarVisibility: $sidebarVisibility)
                .frame(width:800, height: 600)
        })
        .alert(isPresented: $showAlert, error: error) { _ in
            Button("OK") {
                self.showAlert = false
            }
        } message: { error in
            Text(error.recoverySuggestion ?? "Try opening a different file")
        }
    }
    
    @ViewBuilder
    private func menuView(
        text: String,
        @ViewBuilder content: @escaping () -> some View,
        @ViewBuilder label: @escaping (_ text: String) -> some View
    ) -> some View {
        Menu(content: content, label: {
            HStack {
                label(text)
            }
            .padding(5)
        })
        .frame(width: text.estimatedWidth(
            using: .systemFont(ofSize: 13),
            padding: 40
        ), height: 20)
        .menuIndicator(.hidden)
    }
    
    private func loadFile(from fileURL: URL) {
        Task(priority: .userInitiated) {
            if let homeBookmark = UserDefaults.standard.data(forKey: "homeBookmark") {
                var isHomeBookmarkInvalid = false
                
                let homeURL = try URL(
                    resolvingBookmarkData: homeBookmark,
                    options: .withSecurityScope,
                    bookmarkDataIsStale: &isHomeBookmarkInvalid
                )
                
                if !isHomeBookmarkInvalid, homeURL.startAccessingSecurityScopedResource() {
                    do {
                        try await self.sqlManager.connect(
                            fileURL: fileURL,
                            appInfo: self.sqlManager.openAppInfo
                        )
                    } catch let error as SQLiteError {
                        self.error = error
                        self.showAlert = true
                    }
                    
                    homeURL.stopAccessingSecurityScopedResource()
                }
            }
        }
    }
    
}
