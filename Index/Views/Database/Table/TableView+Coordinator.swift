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
        var displayMode: DisplayMode
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
            displayMode: DisplayMode,
            newRecordIds: Set<UUID>,
            selectedRecords: Binding<Set<UUID>>,
            onUpdate: @escaping (UUID, String, Value) -> Void,
            onForeignKeyClick: ((SQLiteColumn.ForeignKey, Value, Record) -> Void)?,
            onRowDeselected: ((UUID) -> Void)?,
            onEnterPressed: ((UUID) -> Void)?) {
            self.records = records
            self.properties = properties
            self.isReadOnly = isReadOnly
            self.displayMode = displayMode
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
            
            // Get the value, defaulting to .undefined for properties without values
            let value = record.values[property.column.name] ?? .undefined
            
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
                textField.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
                textField.translatesAutoresizingMaskIntoConstraints = false
                textField.lineBreakMode = .byTruncatingTail
                textField.usesSingleLineMode = true
                textField.cell?.wraps = false
                textField.cell?.isScrollable = false
                textField.cell?.truncatesLastVisibleLine = true
                
                let stringValue: String
                var useAttributedString = false
                
                // Use attributed string for arrays to color elements differently
                if case .array(let values) = value {
                    textField.attributedStringValue = attributedStringForArray(values, font: textField.font ?? .monospacedSystemFont(ofSize: 13, weight: .regular))
                    stringValue = "" // Not used for arrays
                    useAttributedString = true
                } else if (displayMode == .CoreData || displayMode == .SwiftData), 
                          let fk = property.column.foreignKey {
                    // For CoreData/SwiftData relationships, use attributed strings
                    if case .undefined = value {
                        // To-many relationship - show preview if available
                        if let preview = record.relationshipPreviews[property.name] {
                            if preview.count == 0 {
                                stringValue = "nil"
                            } else if let firstValue = preview.firstValue {
                                // Always show as array with brackets for to-many relationships
                                let result = NSMutableAttributedString()
                                result.append(NSAttributedString(string: "[", attributes: [
                                    .foregroundColor: NSColor.labelColor,
                                    .font: textField.font ?? .monospacedSystemFont(ofSize: 13, weight: .regular)
                                ]))
                                result.append(attributedStringForRelationship(
                                    typeName: fk.table,
                                    properties: firstValue,
                                    font: textField.font ?? .monospacedSystemFont(ofSize: 13, weight: .regular)
                                ))
                                if preview.count > 1 {
                                    result.append(NSAttributedString(string: ", ...]", attributes: [
                                        .foregroundColor: NSColor.labelColor,
                                        .font: textField.font ?? .monospacedSystemFont(ofSize: 13, weight: .regular)
                                    ]))
                                } else {
                                    result.append(NSAttributedString(string: "]", attributes: [
                                        .foregroundColor: NSColor.labelColor,
                                        .font: textField.font ?? .monospacedSystemFont(ofSize: 13, weight: .regular)
                                    ]))
                                }
                                textField.attributedStringValue = result
                                stringValue = ""
                                useAttributedString = true
                            } else {
                                // Has items but no first value
                                stringValue = "[\(fk.table)(...), ...]"
                            }
                        } else {
                            stringValue = "nil"
                        }
                    } else {
                        // To-one relationship - show object reference or null
                        if case .null = value {
                            stringValue = "null"
                        } else if let preview = record.relationshipPreviews[property.name],
                                  let firstValue = preview.firstValue {
                            // Show preview with property info using attributed string
                            textField.attributedStringValue = attributedStringForRelationship(
                                typeName: fk.table,
                                properties: firstValue,
                                font: textField.font ?? .monospacedSystemFont(ofSize: 13, weight: .regular)
                            )
                            stringValue = ""
                            useAttributedString = true
                        } else {
                            // Fallback to showing ID
                            let idValue = valueToString(value)
                            stringValue = "\(fk.table)(id: \(idValue))"
                        }
                    }
                } else {
                    stringValue = valueToString(value)
                }
                
                if !useAttributedString {
                    textField.stringValue = stringValue
                }
                
                textField.drawsBackground = false
                textField.valueType = value
                textField.isForeignKey = true // Mark as foreign key for button/width handling
                
                // Make editable if not read-only and not a data type (array/image)
                // For CoreData/SwiftData, foreign keys are not editable
                let isDataType = { () -> Bool in
                    if case .array = value { return true }
                    if case .image = value { return true }
                    return false
                }()
                
                let isCoreDataForeignKey = (displayMode == .CoreData || displayMode == .SwiftData) && property.column.foreignKey != nil
                
                if !isReadOnly && !isDataType && !isCoreDataForeignKey {
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
                let textWidth: CGFloat
                if useAttributedString {
                    textWidth = textField.attributedStringValue.size().width
                } else {
                    textWidth = (stringValue as NSString).size(withAttributes: [
                        .font: textField.font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
                    ]).width
                }
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
                textField.translatesAutoresizingMaskIntoConstraints = false
                textField.lineBreakMode = .byTruncatingTail
                textField.usesSingleLineMode = true
                textField.cell?.wraps = false
                textField.cell?.isScrollable = false
                textField.cell?.truncatesLastVisibleLine = true
                
                // Use attributed string for arrays to color elements differently
                if case .array(let values) = value {
                    textField.attributedStringValue = attributedStringForArray(values, font: textField.font ?? .monospacedSystemFont(ofSize: 13, weight: .regular))
                } else if (displayMode == .CoreData || displayMode == .SwiftData), 
                          let fk = property.column.foreignKey {
                    // For CoreData/SwiftData relationships, use attributed strings
                    if case .undefined = value {
                        // To-many relationship - show preview if available
                        if let preview = record.relationshipPreviews[property.name] {
                            if preview.count == 0 {
                                textField.stringValue = "nil"
                            } else if let firstValue = preview.firstValue {
                                // Always show as array with brackets for to-many relationships
                                let result = NSMutableAttributedString()
                                result.append(NSAttributedString(string: "[", attributes: [
                                    .foregroundColor: NSColor.labelColor,
                                    .font: textField.font ?? .monospacedSystemFont(ofSize: 13, weight: .regular)
                                ]))
                                result.append(attributedStringForRelationship(
                                    typeName: fk.table,
                                    properties: firstValue,
                                    font: textField.font ?? .monospacedSystemFont(ofSize: 13, weight: .regular)
                                ))
                                if preview.count > 1 {
                                    result.append(NSAttributedString(string: ", ...]", attributes: [
                                        .foregroundColor: NSColor.labelColor,
                                        .font: textField.font ?? .monospacedSystemFont(ofSize: 13, weight: .regular)
                                    ]))
                                } else {
                                    result.append(NSAttributedString(string: "]", attributes: [
                                        .foregroundColor: NSColor.labelColor,
                                        .font: textField.font ?? .monospacedSystemFont(ofSize: 13, weight: .regular)
                                    ]))
                                }
                                textField.attributedStringValue = result
                            } else {
                                // Has items but no first value
                                textField.stringValue = "[\(fk.table)(...), ...]"
                            }
                        } else {
                            textField.stringValue = "nil"
                        }
                    } else {
                        // To-one relationship - show object reference or null
                        if case .null = value {
                            textField.stringValue = "null"
                        } else if let preview = record.relationshipPreviews[property.name],
                                  let firstValue = preview.firstValue {
                            // Show preview with property info using attributed string
                            textField.attributedStringValue = attributedStringForRelationship(
                                typeName: fk.table,
                                properties: firstValue,
                                font: textField.font ?? .monospacedSystemFont(ofSize: 13, weight: .regular)
                            )
                        } else {
                            // Fallback to showing ID
                            let idValue = valueToString(value)
                            textField.stringValue = "\(fk.table)(id: \(idValue))"
                        }
                    }
                } else {
                    textField.stringValue = valueToString(value)
                }
                
                textField.drawsBackground = false
                textField.valueType = value
                
                // Make editable if not read-only and not a data type (array/image)
                // For CoreData/SwiftData, foreign keys are not editable
                let isDataType = { () -> Bool in
                    if case .array = value { return true }
                    if case .image = value { return true }
                    return false
                }()
                
                let isCoreDataForeignKey = (displayMode == .CoreData || displayMode == .SwiftData) && property.column.foreignKey != nil
                
                if !isReadOnly && !isDataType && !isCoreDataForeignKey {
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
                  let property = properties.first(where: { $0.column.name == columnName }),
                  let fk = property.column.foreignKey,
                  let callback = onForeignKeyClick else {
                return
            }
            
            let record = records[row]
            
            // Get value for the foreign key
            // For to-many relationships (inverse relationships), use the current record's Z_PK
            // For to-one relationships, use the actual foreign key value
            let value: Value
            if let actualValue = record.values[columnName] {
                value = actualValue
            } else {
                // This is likely a to-many relationship - get the current record's primary key
                if let pkValue = record.values["Z_PK"] {
                    value = pkValue
                } else {
                    value = .null
                }
            }
            
            callback(fk, value, record)
        }
        
        func controlTextDidBeginEditing(_ obj: Notification) {
            // Clear NULL placeholder when user starts editing an empty field
            guard let textField = obj.object as? EditableTextField else {
                return
            }
            
            // If the field contains "NULL" or "null" and has null value type, clear it
            if textField.stringValue.uppercased() == "NULL", case .null = textField.valueType {
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
                  let record = records.first(where: { $0.id == recordId }) else {
                return
            }
            
            let columnName = String(components[1])
            
            // Get value, defaulting to .null for properties without values (like to-many relationships)
            let value = record.values[columnName] ?? .null
            
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
            case .undefined:
                // Undefined values are not editable
                return nil
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
            case .uuid:
                if let uuid = UUID(uuidString: string) {
                    return .uuid(uuid)
                }
                return nil
            case .data:
                // Data values are not editable
                return nil
            case .enumValue:
                // Enum values can be edited - remove leading dot if present
                let cleanedString = string.hasPrefix(".") ? String(string.dropFirst()) : string
                return .enumValue(cleanedString)
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
                // Use lowercase "null" for CoreData/SwiftData to match code style
                return (displayMode == .CoreData || displayMode == .SwiftData) ? "null" : "NULL"
            case .undefined:
                return ""
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
            case .uuid(let uuid):
                return uuid.uuidString
            case .data(let string):
                return string
            case .enumValue(let caseName):
                // Display as Swift enum case with dot prefix
                return ".\(caseName)"
            case .timestamp(let date):
                return date.ISO8601Format()
            case .array(let values):
                // Convert array to JSON-like representation
                let stringValues = values.map { valueToString($0) }
                return "[\(stringValues.joined(separator: ", "))]"
            case .image:
                return "<IMAGE>"
            }
        }
        
        private func colorForValue(_ value: Value) -> NSColor {
            switch value {
            case .text:
                return NSColor(XcodeThemeColors.string)
            case .uuid, .data, .enumValue:
                return NSColor(XcodeThemeColors.type)
            case .integer, .smallint, .real, .float:
                return NSColor(XcodeThemeColors.number)
            case .null:
                return NSColor(XcodeThemeColors.keyword)
            case .undefined:
                return .placeholderTextColor
            case .timestamp, .image:
                return NSColor(XcodeThemeColors.type)
            case .array:
                return .labelColor
            }
        }
        
        private func attributedStringForArray(_ values: [Value], font: NSFont) -> NSAttributedString {
            let result = NSMutableAttributedString()
            
            // Opening bracket in black
            result.append(NSAttributedString(string: "[", attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: font
            ]))
            
            // Array elements with their respective colors
            for (index, value) in values.enumerated() {
                let stringValue = valueToString(value)
                let color = colorForValue(value)
                
                result.append(NSAttributedString(string: stringValue, attributes: [
                    .foregroundColor: color,
                    .font: font
                ]))
                
                // Add comma and space between elements
                if index < values.count - 1 {
                    result.append(NSAttributedString(string: ", ", attributes: [
                        .foregroundColor: NSColor.labelColor,
                        .font: font
                    ]))
                }
            }
            
            // Closing bracket in black
            result.append(NSAttributedString(string: "]", attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: font
            ]))
            
            return result
        }
        
        private func attributedStringForRelationship(
            typeName: String,
            properties: String?,
            font: NSFont
        ) -> NSAttributedString {
            let result = NSMutableAttributedString()
            
            // Type name in type color (cyan/teal)
            result.append(NSAttributedString(string: typeName, attributes: [
                .foregroundColor: NSColor(XcodeThemeColors.type),
                .font: font
            ]))
            
            // Opening parenthesis in default color
            result.append(NSAttributedString(string: "(", attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: font
            ]))
            
            // Properties with syntax coloring
            if let properties = properties {
                // Split by ", " to get individual properties
                let propertyPairs = properties.components(separatedBy: ", ")
                
                for (index, pair) in propertyPairs.enumerated() {
                    // Split by ": " to get property name and value
                    let components = pair.components(separatedBy: ": ")
                    
                    if components.count == 2 {
                        let propertyName = components[0]
                        let propertyValue = components[1]
                        
                        // Property name in property color (blue)
                        result.append(NSAttributedString(string: propertyName, attributes: [
                            .foregroundColor: NSColor(XcodeThemeColors.property),
                            .font: font
                        ]))
                        
                        // Colon and space in default color
                        result.append(NSAttributedString(string: ": ", attributes: [
                            .foregroundColor: NSColor.labelColor,
                            .font: font
                        ]))
                        
                        // Value with appropriate color
                        let valueColor: NSColor
                        if propertyValue.hasPrefix("\"") && propertyValue.hasSuffix("\"") {
                            // String value
                            valueColor = NSColor(XcodeThemeColors.string)
                        } else if Int(propertyValue) != nil || Double(propertyValue) != nil {
                            // Number value
                            valueColor = NSColor(XcodeThemeColors.number)
                        } else if propertyValue == "true" || propertyValue == "false" || propertyValue == "nil" {
                            // Keyword value
                            valueColor = NSColor(XcodeThemeColors.keyword)
                        } else {
                            // Default color for other values
                            valueColor = .labelColor
                        }
                        
                        result.append(NSAttributedString(string: propertyValue, attributes: [
                            .foregroundColor: valueColor,
                            .font: font
                        ]))
                        
                        // Add comma and space between properties
                        if index < propertyPairs.count - 1 {
                            result.append(NSAttributedString(string: ", ", attributes: [
                                .foregroundColor: NSColor.labelColor,
                                .font: font
                            ]))
                        }
                    } else {
                        // Fallback if parsing fails
                        result.append(NSAttributedString(string: pair, attributes: [
                            .foregroundColor: NSColor.labelColor,
                            .font: font
                        ]))
                        
                        if index < propertyPairs.count - 1 {
                            result.append(NSAttributedString(string: ", ", attributes: [
                                .foregroundColor: NSColor.labelColor,
                                .font: font
                            ]))
                        }
                    }
                }
            } else {
                // No properties - show "..."
                result.append(NSAttributedString(string: "...", attributes: [
                    .foregroundColor: NSColor.labelColor,
                    .font: font
                ]))
            }
            
            // Closing parenthesis in default color
            result.append(NSAttributedString(string: ")", attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: font
            ]))
            
            return result
        }
    }
}
