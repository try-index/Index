//
//  Coordinator.swift
//  Index
//
//  Created by Axel Martinez on 17/2/26.
//

import AppKit
import SwiftUI

extension TableView {
    final class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate {
        var records: [Record]
        var properties: [Property]
        var isReadOnly: Bool
        var newRecordIds: Set<UUID>
        var selectedRecords: Binding<Set<UUID>>
        var onUpdate: (UUID, String, Value) -> Void
        var onForeignKeyClick: ((SQLiteColumn.ForeignKey, Value, Record) -> Void)?
        var onRowDeselected: ((UUID) -> Void)?
        var onEnterPressed: ((UUID) -> Void)?
        
        weak var tableView: NSTableView?
        
        init(
            records: [Record],
            properties: [Property],
            isReadOnly: Bool,
            newRecordIds: Set<UUID>,
            selectedRecords: Binding<Set<UUID>>,
            onUpdate: @escaping (UUID, String, Value) -> Void,
            onForeignKeyClick: ((SQLiteColumn.ForeignKey, Value, Record) -> Void)?,
            onRowDeselected: ((UUID) -> Void)?,
            onEnterPressed: ((UUID) -> Void)?) {
            self.records = records
            self.properties = properties
            self.isReadOnly = isReadOnly
            self.newRecordIds = newRecordIds
            self.selectedRecords = selectedRecords
            self.onUpdate = onUpdate
            self.onForeignKeyClick = onForeignKeyClick
            self.onRowDeselected = onRowDeselected
            self.onEnterPressed = onEnterPressed
        }
        
        func numberOfRows(in tableView: NSTableView) -> Int {
            return records.count
        }
        
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let columnId = tableColumn?.identifier,
                  let property = properties.first(where: { $0.name == columnId.rawValue }),
                  row < records.count else {
                return nil
            }
            
            let record = records[row]
            
            guard let value = record.values[property.column.name] else {
                return nil
            }
            
            // Create custom cell view that responds to selection
            let cellView = TableCell()
            
            var leadingConstant: CGFloat = 4
            
            // Show indicator for new unsaved records (only first column and in editable mode)
            if !isReadOnly && newRecordIds.contains(record.id) && properties.first?.name == property.name {
                let indicator = NSImageView()
                indicator.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)
                indicator.contentTintColor = .systemOrange
                indicator.translatesAutoresizingMaskIntoConstraints = false
                cellView.addSubview(indicator)
                
                NSLayoutConstraint.activate([
                    indicator.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                    indicator.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                    indicator.widthAnchor.constraint(equalToConstant: 6),
                    indicator.heightAnchor.constraint(equalToConstant: 6)
                ])
                
                leadingConstant = 14
            }
            
            // Check if this is a foreign key column
            if property.column.foreignKey != nil {
                // Create a stack view for text + icon
                let stackView = NSStackView()
                stackView.orientation = .horizontal
                stackView.spacing = 2
                stackView.alignment = .centerY
                stackView.distribution = .fillProportionally
                stackView.translatesAutoresizingMaskIntoConstraints = false
                
                // Text field (editable for foreign keys, but styled differently)
                let textField = EditableTextField()
                textField.isBordered = false
                textField.backgroundColor = .clear
                textField.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
                textField.translatesAutoresizingMaskIntoConstraints = false
                textField.lineBreakMode = .byClipping
                textField.usesSingleLineMode = true
                textField.cell?.wraps = false
                textField.cell?.isScrollable = true
                
                let stringValue = valueToString(value)
                
                textField.stringValue = stringValue
                textField.drawsBackground = false
                textField.valueType = value
                textField.isForeignKey = true // Mark as foreign key for button/width handling
                
                // Make editable if not read-only
                if !isReadOnly {
                    textField.isEditable = true
                    textField.delegate = self
                    textField.allowsEditingTextAttributes = false
                    textField.importsGraphics = false
                    
                    // Store metadata for editing
                    textField.identifier = NSUserInterfaceItemIdentifier("\(record.id.uuidString)|\(property.column.name)")
                } else {
                    textField.isEditable = false
                    textField.isSelectable = false
                }
                
                // Arrow button
                let button = NSButton()
                let buttonImage = NSImage(systemSymbolName: "arrow.right.circle", accessibilityDescription: nil)
                if let image = buttonImage?.withSymbolConfiguration(.init(pointSize: 12, weight: .regular)) {
                    button.image = image
                }
                button.bezelStyle = .inline
                button.isBordered = false
                button.imageScaling = .scaleProportionallyDown
                button.imagePosition = .imageOnly
                button.target = self
                button.action = #selector(foreignKeyButtonClicked(_:))
                button.tag = row
                button.identifier = NSUserInterfaceItemIdentifier(property.column.name)
                button.translatesAutoresizingMaskIntoConstraints = false
                button.contentTintColor = .systemBlue
                
                // Calculate preferred width based on text content
                let textWidth = (stringValue as NSString).size(withAttributes: [
                    .font: textField.font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
                ]).width
                let preferredWidth = max(textWidth + 5, 15)
                
                // Create width constraint for text field
                let textFieldWidthConstraint = textField.widthAnchor.constraint(equalToConstant: preferredWidth)
                textFieldWidthConstraint.priority = .defaultHigh
                textFieldWidthConstraint.isActive = true
                
                // Store constraint reference so it can be toggled during editing
                textField.widthConstraint = textFieldWidthConstraint
                
                stackView.addArrangedSubview(textField)
                stackView.addArrangedSubview(button)
                
                cellView.addSubview(stackView)
                
                // Set priorities - button stays fixed, text field can grow if needed
                textField.setContentHuggingPriority(.init(249), for: .horizontal)
                textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                
                button.setContentHuggingPriority(.required, for: .horizontal)
                button.setContentCompressionResistancePriority(.required, for: .horizontal)
                
                NSLayoutConstraint.activate([
                    stackView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: leadingConstant),
                    stackView.trailingAnchor.constraint(lessThanOrEqualTo: cellView.trailingAnchor, constant: -4),
                    stackView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                    button.widthAnchor.constraint(equalToConstant: 16),
                    button.heightAnchor.constraint(equalToConstant: 16)
                ])
                
                // Important: Set the textField property so updateColors() works
                cellView.textField = textField
                
                // Store button reference in textField so we can hide/show it during editing
                textField.foreignKeyButton = button
            } else {
                let textField = EditableTextField()
                textField.isBordered = false
                textField.backgroundColor = .clear
                textField.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
                textField.stringValue = valueToString(value)
                textField.drawsBackground = false
                textField.valueType = value
                
                // Make editable if not read-only
                if !isReadOnly {
                    textField.isEditable = true
                    textField.delegate = self
                    textField.allowsEditingTextAttributes = false
                    textField.importsGraphics = false
                    
                    // Store metadata for editing
                    textField.identifier = NSUserInterfaceItemIdentifier("\(record.id.uuidString)|\(property.column.name)")
                } else {
                    textField.isEditable = false
                    textField.isSelectable = false
                }
                
                cellView.addSubview(textField)
                textField.translatesAutoresizingMaskIntoConstraints = false
                
                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: leadingConstant),
                    textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                    textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
                ])
                
                cellView.textField = textField
            }
            
            cellView.updateColors()
            
            return cellView
        }
        
        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let tableView = notification.object as? NSTableView else {
                return
            }
            
            let selectedIndexes = tableView.selectedRowIndexes
            let newSelection = Set(selectedIndexes.compactMap { index in
                index < records.count ? records[index].id : nil
            })
            
            // Get previously selected records
            let previousSelection = self.selectedRecords.wrappedValue
            
            // Find records that were deselected
            let deselectedRecords = previousSelection.subtracting(newSelection)
            
            // Defer state change to avoid modifying state during view update
            DispatchQueue.main.async {
                self.selectedRecords.wrappedValue = newSelection
                
                // Notify row deselected (user clicked away from the row)
                for deselectedId in deselectedRecords {
                    self.onRowDeselected?(deselectedId)
                }
            }
        }
        
        @objc func foreignKeyButtonClicked(_ sender: NSButton) {
            let row = sender.tag
            
            guard row < records.count,
                  let columnName = sender.identifier?.rawValue,
                  let property = properties.first(where: { $0.name == columnName }),
                  let fk = property.column.foreignKey,
                  let value = records[row].values[columnName],
                  let callback = onForeignKeyClick else {
                return
            }
            
            callback(fk, value, records[row])
        }
        
        func controlTextDidBeginEditing(_ obj: Notification) {
            // Clear NULL placeholder when user starts editing an empty field
            guard let textField = obj.object as? EditableTextField else {
                return
            }
            
            // If the field contains "NULL" and has null value type, clear it
            if textField.stringValue == "NULL", case .null = textField.valueType {
                textField.stringValue = ""
            }
        }
        

        func controlTextDidEndEditing(_ obj: Notification) {
            // Restore transparent background when editing ends
            if let textField = obj.object as? EditableTextField {
                textField.drawsBackground = false
                textField.backgroundColor = .clear
                
                // For foreign key fields, update constraint BEFORE showing button
                if textField.isForeignKey {
                    // Recalculate and update width constraint based on new text
                    if let widthConstraint = textField.widthConstraint {
                        let newTextWidth = (textField.stringValue as NSString).size(withAttributes: [
                            .font: textField.font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
                        ]).width
                        let newPreferredWidth = max(newTextWidth + 5, 15)
                        
                        widthConstraint.constant = newPreferredWidth
                        widthConstraint.isActive = true
                        
                        // Force layout update before showing button
                        textField.superview?.layoutSubtreeIfNeeded()
                    }
                    
                    // Now show the button after layout is complete
                    textField.foreignKeyButton?.isHidden = false
                }
                
                // Update colors based on selection state
                if let cellView = textField.superview as? TableCell {
                    cellView.updateColors()
                }
            }
            
            guard let textField = obj.object as? NSTextField,
                  let identifier = textField.identifier?.rawValue else {
                return
            }
            
            let components = identifier.split(separator: "|")
            
            guard components.count == 2,
                  let recordId = UUID(uuidString: String(components[0])),
                  let record = records.first(where: { $0.id == recordId }),
                  let value = record.values[String(components[1])] else {
                return
            }
            
            let columnName = String(components[1])
            let newText = textField.stringValue
            
            // Convert text to appropriate value type
            if let newValue = stringToValue(newText, originalValue: value) {
                onUpdate(recordId, columnName, newValue)
            }
            
            // Check if user pressed Return/Enter - this ends editing but keeps selection
            // We detect this by checking the movement type
            if let movement = obj.userInfo?["NSTextMovement"] as? Int,
               movement == NSReturnTextMovement {
                onEnterPressed?(recordId)
            }
        }
        
        private func stringToValue(_ string: String, originalValue: Value) -> Value? {
            switch originalValue {
            case .null:
                if string.uppercased() == "NULL" || string.isEmpty {
                    return .null
                }
                return .text(string)
            case .integer:
                if let int = Int(string) {
                    return .integer(int)
                }
                return nil
            case .smallint:
                if let int = Int16(string) {
                    return .smallint(int)
                }
                return nil
            case .real:
                if let double = Double(string) {
                    return .real(double)
                }
                return nil
            case .float:
                if let float = Float(string) {
                    return .float(float)
                }
                return nil
            case .text:
                return .text(string)
            case .timestamp:
                if let date = try? Date(string, strategy: .iso8601) {
                    return .timestamp(date)
                }
                return nil
            case .array, .image:
                return nil
            }
        }
        
        private func valueToString(_ value: Value) -> String {
            switch value {
            case .null:
                return "NULL"
            case .integer(let int):
                return "\(int)"
            case .smallint(let int):
                return "\(int)"
            case .real(let double):
                return "\(double)"
            case .float(let float):
                return "\(float)"
            case .text(let string):
                return string
            case .timestamp(let date):
                return date.ISO8601Format()
            case .array, .image:
                return "<DATA>"
            }
        }
    }
}
