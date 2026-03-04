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

    let onFileSelected: (URL, Bool, Bool) -> Void  // (url, readOnly, ignoreDataModel)
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

        let readOnlyCheckbox = NSButton(checkboxWithTitle: "Open Read-Only", target: nil, action: nil)
        readOnlyCheckbox.state = .off
        
        let rawSQLCheckbox = NSButton(checkboxWithTitle: "Open as SQLite database", target: nil, action: nil)
        rawSQLCheckbox.state = .off
        
        let stackView = NSStackView(views: [readOnlyCheckbox, rawSQLCheckbox])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 6
        
        // Wrap in a container with padding
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stackView.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])
        
        panel.accessoryView = container
        panel.isAccessoryViewDisclosed = true
        
        // Hide the disclosure "Options" button
        DispatchQueue.main.async {
            if let contentView = panel.contentView {
                Self.hideDisclosureButton(in: contentView)
            }
        }

        if panel.runModal() == .OK, let url = panel.url {
            dismiss()
            onFileSelected(url, readOnlyCheckbox.state == .on, rawSQLCheckbox.state == .on)
        }
    }
    
    private static func hideDisclosureButton(in view: NSView) {
        for subview in view.subviews {
            if let button = subview as? NSButton,
               button.bezelStyle == .disclosure {
                button.isHidden = true
                return
            }
            hideDisclosureButton(in: subview)
        }
    }
}

