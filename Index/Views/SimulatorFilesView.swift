//
//  SimulatorFilesView.swift
//  Data Inspector
//
//  Created by Axel Martinez on 21/11/24.
//

import SwiftUI

struct SimulatorFilesView: View {
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var sqlManager: SQLiteManager
    @EnvironmentObject var simManager: SimulatorManager
    
    @Binding var selectedFileInfo: FileInfo?
    
    @State private var isLoading: Bool = false
    @State private var applications: [AppInfo] = []
    
    let openFile: (FileInfo, Bool) async throws -> Void
    let simulatorURL: URL
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if applications.isEmpty {
                ContentUnavailableView("No database files found", image: "database.xmark")
            } else {
               List(selection: $selectedFileInfo) {
                    ForEach(applications) { appInfo in
                        ForEach(appInfo.fileURLs, id: \.self) { fileUrl in
                            HStack {
                                AppLabel(appInfo: appInfo)
                                Spacer()
                                Text(fileUrl.lastPathComponent)
                            }
                            .tag(FileInfo(url: fileUrl, appInfo: appInfo))
                        }
                   }
                }
                .contextMenu(forSelectionType: FileInfo.self, menu: { _ in }) { fileSet in
                    if let file = fileSet.first {
                        Task(priority: .userInitiated) {
                            try? await self.openFile(file, false)
                        }
                    }
                }
            }
        }
        .onAppear(perform: loadApps)
        .onChange(of: simulatorURL, loadApps)
    }
    
    func loadApps() {
        self.isLoading = true
        
        self.applications = self.simManager.getSimulatorApps(at: simulatorURL)
        
        self.isLoading = false
    }
}
