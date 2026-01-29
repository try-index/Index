//
//  FileMenu.swift
//  Index
//
//  Created by Axel Martinez on 20/11/24.
//

import SwiftUI

struct FileMenu: View {
    let fileURL: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MenuButton(title: "Show in Finder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([fileURL])
            }

            MenuButton(title: "Copy Path", systemImage: "doc.on.doc") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(fileURL.path, forType: .string)
            }

            Divider()

            Text(fileURL.deletingLastPathComponent().path)
                .truncationMode(.middle)
        }
        .padding()
        .help(fileURL.path)
    }
}

private struct MenuButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(isHovering ? Color.accentColor.opacity(0.4) : Color.clear)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
