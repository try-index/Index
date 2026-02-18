//
//  StatusBar.swift
//  Index
//
//  Created by Axel Martinez on 16/2/26.
//

import SwiftUI

struct StatusBar: View {
    let recordCount: Int
    let filteredCount: Int
    let tableName: String
    let unsavedCount: Int
    var isReadOnly: Bool = false
    
    @Binding var isUtilityExpanded: Bool
    
    var body: some View {
        HStack(spacing: 16) {

            // Record count
            HStack(spacing: 4) {
                Text("\(filteredCount) of \(recordCount) records")
                    .font(.system(size: 11))
            }
            .foregroundStyle(.secondary)
            
            // Unsaved records indicator (only in editable mode)
            if !isReadOnly && unsavedCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(.orange)
                    Text("\(unsavedCount) unsaved")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
                
                Button {
                    NotificationCenter.default.post(name: .saveRecordsRequested, object: nil)
                } label: {
                    Text("Save")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Save unsaved records (⌘S)")
            }
            
            Spacer()
            
            // SQL Console toggle button
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    isUtilityExpanded.toggle()
                }
            } label: {
                Image(systemName: isUtilityExpanded ? "inset.filled.bottomthird.square" : "inset.filled.topthird.square")
                    .font(.system(size: 14))
                    .foregroundStyle(isUtilityExpanded ? .primary : .secondary)
            }
            .buttonStyle(.plain)
            .help(isUtilityExpanded ? "Hide SQL Console" : "Show SQL Console")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    @Previewable @State var isExpanded = false
    
    StatusBar(
        recordCount: 150,
        filteredCount: 150,
        tableName: "users",
        unsavedCount: 2,
        isUtilityExpanded: $isExpanded
    )
    .frame(height: 24)
}
