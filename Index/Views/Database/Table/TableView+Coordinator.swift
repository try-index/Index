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
        
        weak var tableView: NSTableView?
        
        init(
            records: [Record],
            properties: [Property],
            isReadOnly: Bool,
            newRecordIds: Set<UUID>,
            selectedRecords: Binding<Set<UUID>>,
            onUpdate: @escaping (UUID, String, Value) -> Void,
            onForeignKeyClick: ((SQLiteColumn.ForeignKey, Value, Record
                                ) -> Void)?) {
            self.records = records
            self.properties = properties
            self.isReadOnly = isReadOnly
            self.newRecordIds = newRecordIds
            self.selectedRecords = selectedRecords
            self.onUpdate = onUpdate
            self.onForeignKeyClick = onForeignKeyClick
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
                stackView.spacing = 4
                stackView.alignment = .centerY
                stackView.translatesAutoresizingMaskIntoConstraints = false
                
                // Text field (non-editable for foreign keys)
                let textField = EditableTextField()
                textField.isBordered = false
                textField.backgroundColor = .clear
                textField.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
                
                let stringValue = valueToString(value)
                
                textField.stringValue = stringValue
                textField.drawsBackground = false
                textField.valueType = value
                textField.isEditable = false
                textField.isSelectable = false
                textField.textColor = .systemBlue
                
                // Arrow button
                let button = NSButton()
                button.image = NSImage(systemSymbolName: "arrow.right.circle", accessibilityDescription: nil)
                button.bezelStyle = .inline
                button.isBordered = false
                button.imageScaling = .scaleProportionallyDown
                button.target = self
                button.action = #selector(foreignKeyButtonClicked(_:))
                button.tag = row
                button.identifier = NSUserInterfaceItemIdentifier(property.column.name)
                
                if let image = button.image {
                    button.image = image.withSymbolConfiguration(.init(pointSize: 10, weight: .regular))
                }
                
                stackView.addArrangedSubview(textField)
                stackView.addArrangedSubview(button)
                
                cellView.addSubview(stackView)
                
                NSLayoutConstraint.activate([
                    stackView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: leadingConstant),
                    stackView.trailingAnchor.constraint(lessThanOrEqualTo: cellView.trailingAnchor, constant: -4),
                    stackView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
                ])
                
                cellView.textField = textField
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
            
            // Defer state change to avoid modifying state during view update
            DispatchQueue.main.async {
                self.selectedRecords.wrappedValue = newSelection
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
        
        func controlTextDidEndEditing(_ obj: Notification) {
            // Restore transparent background when editing ends
            if let textField = obj.object as? EditableTextField {
                textField.drawsBackground = false
                textField.backgroundColor = .clear
                
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
