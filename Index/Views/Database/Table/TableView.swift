//
//  TableView.swift
//  Index
//
//  Created by Axel Martinez on 16/2/26.
//

import SwiftUI
import AppKit

struct TableView: NSViewRepresentable {
    let records: [Record]
    let properties: [Property]
    let isReadOnly: Bool
    let displayMode: DisplayMode
    let newRecordIds: Set<UUID>
    
    @Binding var selectedRecords: Set<UUID>
    
    let scrollToRecordId: UUID?
    let onUpdate: (UUID, String, Value) -> Void
    let onForeignKeyClick: ((SQLiteColumn.ForeignKey, Value, Record) -> Void)?
    let onRowDeselected: ((UUID) -> Void)?
    let onEnterPressed: ((UUID) -> Void)?
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let tableView = NSTableView()
        
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.allowsMultipleSelection = true
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.style = .inset
        tableView.selectionHighlightStyle = .regular
        tableView.rowHeight = 32
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.gridStyleMask = [.solidHorizontalGridLineMask]
        tableView.gridColor = NSColor.separatorColor
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        
        // Create columns with styled headers
        for property in properties {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(property.name))
            column.headerCell = HeaderCell()
            
            // Create attributed string for column header with syntax coloring
            let headerText = NSMutableAttributedString()
            let nameAttr = NSAttributedString(
                string: property.name,
                attributes: [
                    .foregroundColor: NSColor(XcodeThemeColors.property),
                    .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
                ]
            )
            headerText.append(nameAttr)
            
            let separator = NSAttributedString(
                string: ": ",
                attributes: [
                    .foregroundColor: NSColor.labelColor,
                    .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
                ]
            )
            headerText.append(separator)
            
            let typeAttr = NSAttributedString(
                string: property.type,
                attributes: [
                    .foregroundColor: NSColor(XcodeThemeColors.type),
                    .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
                ]
            )
            headerText.append(typeAttr)
            
            // Add icons for primary key and foreign key
            if property.column.pk > 0 {
                // Create an attachment for the key icon
                let keyAttachment = NSTextAttachment()
                
                if let keyImage = NSImage(systemSymbolName: "key.fill", accessibilityDescription: nil) {
                    keyImage.isTemplate = true
                    keyAttachment.image = keyImage.withSymbolConfiguration(.init(pointSize: 12, weight: .regular))
                }
                
                let keyAttr = NSMutableAttributedString(attachment: keyAttachment)
                keyAttr.addAttribute(.foregroundColor, value: NSColor.systemYellow, range: NSRange(location: 0, length: keyAttr.length))
                keyAttr.addAttribute(.baselineOffset, value: 0, range: NSRange(location: 0, length: keyAttr.length))
                
                headerText.append(NSAttributedString(string: "  "))
                headerText.append(keyAttr)
            }
            
            if property.column.foreignKey != nil {
                // Create an attachment for the link icon
                let linkAttachment = NSTextAttachment()
                
                if let linkImage = NSImage(systemSymbolName: "link", accessibilityDescription: nil) {
                    linkImage.isTemplate = true
                    linkAttachment.image = linkImage.withSymbolConfiguration(.init(pointSize: 12, weight: .regular))
                }
                
                let linkAttr = NSMutableAttributedString(attachment: linkAttachment)
                linkAttr.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: NSRange(location: 0, length: linkAttr.length))
                linkAttr.addAttribute(.baselineOffset, value: 0, range: NSRange(location: 0, length: linkAttr.length))
                
                headerText.append(NSAttributedString(string: "  "))
                headerText.append(linkAttr)
            }
            
            column.headerCell.attributedStringValue = headerText
            column.minWidth = CGFloat(property.displayName.count * 8 + 30)
            
            tableView.addTableColumn(column)
        }
        
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        
        context.coordinator.tableView = tableView
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tableView = scrollView.documentView as? NSTableView else { return }
        
        context.coordinator.records = records
        context.coordinator.properties = properties
        context.coordinator.isReadOnly = isReadOnly
        context.coordinator.displayMode = displayMode
        context.coordinator.newRecordIds = newRecordIds
        context.coordinator.onUpdate = onUpdate
        context.coordinator.onForeignKeyClick = onForeignKeyClick
        context.coordinator.onRowDeselected = onRowDeselected
        context.coordinator.onEnterPressed = onEnterPressed
        
        tableView.reloadData()
        
        // Update selection
        let selectedIndexes = IndexSet(records.enumerated().compactMap { index, record in
            selectedRecords.contains(record.id) ? index : nil
        })
        
        tableView.selectRowIndexes(selectedIndexes, byExtendingSelection: false)
        
        // Scroll to record if specified
        if let scrollToId = scrollToRecordId,
           let index = records.firstIndex(where: { $0.id == scrollToId }) {
            tableView.scrollRowToVisible(index)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            records: records,
            properties: properties,
            isReadOnly: isReadOnly,
            displayMode: displayMode,
            newRecordIds: newRecordIds,
            selectedRecords: $selectedRecords,
            onUpdate: onUpdate,
            onForeignKeyClick: onForeignKeyClick,
            onRowDeselected: onRowDeselected,
            onEnterPressed: onEnterPressed
        )
    }
}
