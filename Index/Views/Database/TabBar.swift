//
//  TabBar.swift
//  Index
//
//  Created by Axel Martinez on 16/02/26.
//

import SwiftUI

struct TabBar<Item: Identifiable & Equatable>: View {
    let tabs: [Item]
    
    @Binding var selectedTab: Item?
    
    let tabTitle: (Item) -> String
    let onClose: (Item) -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 1) {
            ForEach(tabs) { tab in
                TabItemView(
                    tab: tab,
                    isSelected: selectedTab?.id == tab.id,
                    title: tabTitle(tab),
                    onSelect: {
                        selectedTab = tab
                    },
                    onClose: {
                        onClose(tab)
                    }
                )
            }
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 2.2)
        .padding(.top, 1)
        .background(.quinary)
        .cornerRadius(15)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private struct TabItemView<Item: Identifiable>: View {
    let tab: Item
    let isSelected: Bool
    let title: String
    let onSelect: () -> Void
    let onClose: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        ZStack(alignment: .leading) {

            Text(title)
                .font(.system(size: 11))
                .lineLimit(1)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            if isHovering {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 14, height: 14)
                }
                .padding(.leading, -5)
                .buttonStyle(.plain)
                .help("Close Tab")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color(nsColor: .controlBackgroundColor))
                }

                if isHovering {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                        .padding(1)
                }
            }
            .shadow(color: isSelected ? Color.black.opacity(0.1) : Color.clear, radius: 1, x: 0, y: 0)
        )
        .contentShape(Ellipse())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

#Preview {
    struct PreviewItem: Identifiable, Equatable {
        let id = UUID()
        let title: String
    }
    
    struct PreviewWrapper: View {
        @State private var tabs = [
            PreviewItem(title: "Table 1"),
            PreviewItem(title: "Table 2"),
            PreviewItem(title: "Table 3")
        ]
        @State private var selectedTab: PreviewItem?
        
        var body: some View {
            VStack(spacing: 0) {
                TabBar(
                    tabs: tabs,
                    selectedTab: $selectedTab,
                    tabTitle: { $0.title },
                    onClose: { tab in
                        if let index = tabs.firstIndex(of: tab) {
                            tabs.remove(at: index)
                            if selectedTab?.id == tab.id {
                                selectedTab = tabs.first
                            }
                        }
                    }
                )
                
                Spacer()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor))
            }
            .frame(width: 600, height: 400)
            .onAppear {
                selectedTab = tabs.first
            }
        }
    }
    
    return PreviewWrapper()
}
