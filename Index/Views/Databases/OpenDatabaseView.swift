//
//  OpenDatabaseView.swift
//  Index
//
//  Created by Axel Martinez on 27/01/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct OpenDatabaseView: View {
    @Environment(\.dismiss) private var dismiss

    let onFileSelected: (URL, Bool) -> Void
    let onBrowseSimulators: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)

                Text("Open Database")
                    .font(.headline)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)

            Divider()

            // Options
            VStack(spacing: 1) {
                DatabaseOptionButton(
                    title: "Open SQLite File",
                    subtitle: "Browse for .db, .sqlite, .sqlite3, or .store files",
                    icon: "cylinder.split.1x2",
                    isEnabled: true
                ) {
                    openFilePicker()
                }

                DatabaseOptionButton(
                    title: "Browse Simulators",
                    subtitle: "Open databases from iOS Simulator apps",
                    icon: "iphone",
                    isEnabled: true
                ) {
                    dismiss()
                    onBrowseSimulators()
                }

                DatabaseOptionButton(
                    title: "FDB Record Layer",
                    subtitle: "Connect to FoundationDB Record Layer",
                    icon: "square.stack.3d.up",
                    isEnabled: false,
                    action: {
                        // Disabled
                    },
                    badge: "Coming Soon"
                )

                DatabaseOptionButton(
                    title: "FDB Document Layer",
                    subtitle: "Connect to FoundationDB Document Layer",
                    icon: "network",
                    isEnabled: false,
                    action: {
                        // Disabled
                    },
                    badge: "Coming Soon"
                )
            }
            .padding(.vertical, 12)

            Spacer()

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(16)
        }
        .frame(width: 380, height: 400)
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = URL.sqlLiteContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        let checkbox = NSButton(checkboxWithTitle: "Open as Read-Only", target: nil, action: nil)
        checkbox.state = .off
        panel.accessoryView = checkbox

        if panel.runModal() == .OK, let url = panel.url {
            dismiss()
            onFileSelected(url, checkbox.state == .on)
        }
    }
}

