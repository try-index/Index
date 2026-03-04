//
//  DatabaseRow.swift
//  Index
//
//  Created by Axel Martinez on 27/1/26.
//

import SwiftUI

struct DatabaseRow: View {
    let database: Database
    let isSelected: Bool
    let onOpen: () -> Void
    let onEdit: () -> Void

    @State private var isHovered = false

    private var lastOpenedText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        
        return formatter.localizedString(for: database.lastOpened, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: databaseFileIcon(for: database))
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(database.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Text(database.filePath)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            HStack(spacing: 8) {
                if database.readOnly {
                    Text("READ ONLY")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
                ZStack {
                    Text(lastOpenedText)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .opacity(isHovered ? 0 : 1)

                    Button("Open") {
                        onOpen()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .opacity(isHovered ? 1 : 0)
                }
                .frame(minWidth: 70, alignment: .trailing)

                Button(action: onEdit) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
