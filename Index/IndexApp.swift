//
//  IndexApp.swift
//  Index
//
//  Created by Axel Martinez on 12/12/24.
//

import SwiftUI

@main
struct IndexApp: App {
    @State var isFileDialogOpen = false
    @State var isSimulatorsDialogOpen = false

    var body: some Scene {
        Window("Main", id: "main") {
            MainView(
                isFileDialogOpen: $isFileDialogOpen,
                isSimulatorsDialogOpen: $isSimulatorsDialogOpen
            )
            .onAppear {
                NSWindow.allowsAutomaticWindowTabbing = false
            }
        }
        .commands {
            CommandGroup(before: .newItem) {
                Button("Open file...") { self.isFileDialogOpen.toggle() }
                Button("Browse Simulators...") { self.isSimulatorsDialogOpen.toggle() }
            }
        }
    }
}
