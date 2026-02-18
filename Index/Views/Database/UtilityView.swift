//
//  UtilityView.swift
//  Index
//
//  Created by Axel Martinez on 16/2/26.
//

import SwiftUI

struct UtilityView: View {
    let sqlQuery: String?
    
    @Binding var isExpanded: Bool
    @State private var consoleHeight: CGFloat = 150
    @State private var isDragging: Bool = false
    
    private let minHeight: CGFloat = 80
    private let maxHeight: CGFloat = 500
    
    var body: some View {
        if isExpanded {
            VStack(spacing: 0) {
                // Drag handle
                ZStack {
                    Divider()
                    
                    // Visible drag indicator
                    HStack {
                        Spacer()
                        Capsule()
                            .fill(isDragging ? Color.accentColor : Color.secondary.opacity(0.5))
                            .frame(width: 40, height: 4)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .frame(height: 16)
                .background(.ultraThinMaterial)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            let newHeight = consoleHeight - value.translation.height
                            consoleHeight = min(max(newHeight, minHeight), maxHeight)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
                .onHover { hovering in
                    if hovering {
                        NSCursor.resizeUpDown.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                
                // Header
                HStack {
                    Image(systemName: "terminal")
                        .foregroundStyle(.secondary)
                    
                    Text("SQL Query")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                
                // SQL content
                ScrollView {
                    Text(sqlQuery ?? "No query available")
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(height: consoleHeight)
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
    }
}

#Preview {
    @Previewable @State var isExpanded = true
    
    UtilityView(
        sqlQuery: "SELECT * FROM users WHERE id = 1;",
        isExpanded: $isExpanded
    )
    .frame(height: 200)
}
