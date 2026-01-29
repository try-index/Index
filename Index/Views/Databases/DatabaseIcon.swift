//
//  DatabaseIcon.swift
//  Index
//
//  Created by Axel Martinez on 27/1/26.
//

import SwiftUI

struct DatabaseIcon: View {
    let database: Database
    let isSelected: Bool
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: fileIcon)
                    .font(.system(size: 40))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 64, height: 64)

                if isHovered {
                    Button(action: onEdit) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .offset(x: 16, y: -4)
                }
            }

            Text(database.displayName)
                .font(.system(size: 11))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 90)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected || isHovered ? Color.primary.opacity(0.05) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("Open") {
                onOpen()
            }

            Button("Edit...") {
                onEdit()
            }

            Divider()

            Button("Delete", role: .destructive) {
                onRemove()
            }
        }
    }

    private var fileIcon: String {
        databaseFileIcon(for: database)
    }
}
