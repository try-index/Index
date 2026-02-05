//
//  SimulatorsView.swift
//  Index
//
//  Created by Axel Martinez on 21/11/24.
//

import SwiftUI

struct SimulatorsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(DatabasesManager.self) var databasesManager
    @Environment(SimulatorsManager.self) var simManager

    @Binding var sidebarVisibility: NavigationSplitViewVisibility
    
    var onDatabaseOpened: (Database) -> Void
    var onClose: (() -> Void)?
    
    @State private var isHomeBookmarkInvalid = false
    @State private var isFolderDialogOpen = false
    @State private var simulators = [Simulator]()
    @State private var homeURL: URL?
    @State private var selectedSimulatorURL: URL?
    @State private var selectedFileInfo: FileInfo?
    @State private var openAsReadOnly = false
    
    var userDirectory: URL? {
        if let userDirectory = FileManager.default.urls(for: .userDirectory, in: .localDomainMask).first {
            return userDirectory.appendingPathComponent(NSUserName())
        }
        
        return nil
    }
    
    var groupedSimulators: [(key: String, value: [Array<Simulator>.Element])] {
        Dictionary(grouping: simulators, by: { $0.runtime }).sorted(by: { $0.key > $1.key })
    }
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSimulatorURL) {
                HStack {
                    Spacer()
                    
                    Text("Simulators")
                        .font(.title2)
                    
                    Spacer()
                }
                
                ForEach(groupedSimulators, id: \.key) { runtime, simSet in
                    Section(header: Text(runtime)) {
                        ForEach(simSet) { simulator in
                            Text(simulator.name)
                                .tag(simulator.url)
                        }
                    }
                }
            }
            .frame(minWidth: 250)
        } detail: {
            if let selectedSimulatorURL {
                SimulatorFilesView(
                    selectedFileInfo: $selectedFileInfo,
                    openFile: { fileInfo, forceReadOnly in
                        try await openFile(fileInfo: fileInfo, forceReadOnly: forceReadOnly)
                    },
                    simulatorURL: selectedSimulatorURL
                )
            } else {
                ContentUnavailableView("Select a simulator", systemImage: "macbook.and.iphone")
            }
        }
        .frame(width: 800, height: 500)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    if let onClose {
                        onClose()
                    } else {
                        dismiss()
                    }
                }
            }

            ToolbarItem(placement: .principal) {
                Toggle("Open as Read-Only", isOn: $openAsReadOnly)
                    .toggleStyle(.checkbox)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Open") {
                    if let selectedFileInfo {
                        Task(priority: .userInitiated) {
                            do {
                                try await self.openFile(fileInfo: selectedFileInfo, forceReadOnly: openAsReadOnly)
                            } catch {
                                fatalError(error.localizedDescription)
                            }
                        }
                    }
                }
                .disabled(self.selectedFileInfo == nil)
            }
        }
        .fileImporter(
            isPresented: $isFolderDialogOpen,
            allowedContentTypes: [.folder],
            onCompletion: { folder in
                switch folder {
                case .success(let folderPath):
                    if folderPath.startAccessingSecurityScopedResource() {
                        do {
                            let bookmark = try folderPath.bookmarkData(options: .withSecurityScope)
                            let homeURL = try URL(
                                resolvingBookmarkData: bookmark,
                                options: .withSecurityScope,
                                bookmarkDataIsStale: &isHomeBookmarkInvalid
                            )
                            
                            UserDefaults.standard.set(bookmark, forKey: "homeBookmark")
                            
                            self.simulators = simManager.loadSimulators(from: homeURL)
                        } catch {
                            print("Error saving home folder bookmark.")
                        }
                        
                        folderPath.stopAccessingSecurityScopedResource()
                    }
                case .failure(let error):
                    fatalError(error.localizedDescription)
                }
            }
        )
        .fileDialogMessage("Allow access to your home directory to load simulators")
        .fileDialogConfirmationLabel("Grant Access")
        .fileDialogDefaultDirectory(userDirectory)
        .onAppear {
            do {
                if let homeBookmark = UserDefaults.standard.data(forKey: "homeBookmark") {
                    self.homeURL = try URL(
                        resolvingBookmarkData: homeBookmark,
                        options: .withSecurityScope,
                        bookmarkDataIsStale: &isHomeBookmarkInvalid
                    )
                    
                    if let homeURL, homeURL.startAccessingSecurityScopedResource() {
                        if isHomeBookmarkInvalid {
                            self.isFolderDialogOpen.toggle()
                        } else {
                            self.simulators = simManager.loadSimulators(from: homeURL)
                            self.sidebarVisibility = .all
                        }
                    }
                } else {
                    self.isFolderDialogOpen.toggle()
                }
            } catch {
                print("Error loading home bookmark")
            }
        }
        .onDisappear {
            if let homeURL {
                homeURL.stopAccessingSecurityScopedResource()
            }
        }
    }
    
    func openFile(fileInfo: FileInfo, forceReadOnly: Bool = false) async throws {
        // Add to recent databases
        databasesManager.addDatabase(from: fileInfo.url)

        // Find the newly added database
        if let database = databasesManager.recentDatabases.first(where: { $0.filePath == fileInfo.url.path }) {
            await MainActor.run {
                onDatabaseOpened(database)
                
                if let onClose {
                    onClose()
                } else {
                    dismiss()
                }
            }
        }
    }
}
