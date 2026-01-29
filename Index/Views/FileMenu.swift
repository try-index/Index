//
//  PathIndicator.swift
//  Index
//
//  Created by Axel Martinez on 20/11/24.
//

import SwiftUI

struct PathIndicator: View {
    let openFileURL: URL?

    var body: some View {
        if let fileURL = openFileURL {
            Menu {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(fileURL.path, forType: .string)
                } label: {
                    Label("Copy Path", systemImage: "doc.on.doc")
                }

                Divider()

                Text(fileURL.path)
                    .font(.caption)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "cylinder.split.1x2")
                        .foregroundStyle(.secondary)

                    Text(fileURL.lastPathComponent)
                        .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.bordered)
            .help(fileURL.path)
        }
    }
}
