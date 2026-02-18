//
//  EditableTextField.swift
//  Index
//
//  Created by Axel Martinez on 17/2/26.
//

import AppKit

// Custom text field that stores its value type for syntax coloring
class EditableTextField: NSTextField {
    var valueType: Value = .null {
        didSet {
            // Update the cell's value type when it changes
            if let quotedCell = cell as? QuotedTextFieldCell {
                quotedCell.valueType = valueType
            }
        }
    }
    var isForeignKey: Bool = false
    var widthConstraint: NSLayoutConstraint?
    
    weak var foreignKeyButton: NSButton?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let cell = QuotedTextFieldCell(textCell: "")
        cell.valueType = self.valueType
        self.cell = cell
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        let cell = QuotedTextFieldCell(textCell: "")
        cell.valueType = self.valueType
        self.cell = cell
    }
    
    var syntaxColor: NSColor {
        // Color based on data type, not key type
        switch valueType {
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
        case .array:
            // Arrays use default label color (black) for brackets and mixed content
            return .labelColor
        case .timestamp, .image:
            return NSColor(XcodeThemeColors.type)
        }
    }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        
        if result {
            // Restore syntax color
            self.textColor = syntaxColor
            
            // Clear placeholder (handles both "NULL" and "null")
            if (self.stringValue.uppercased() == "NULL"), case .null = valueType {
                // Use async to ensure the field editor is set up
                DispatchQueue.main.async {
                    self.stringValue = ""
                }
            }
            
            // Hide foreign key button and deactivate width constraint when editing starts
            if isForeignKey {
                foreignKeyButton?.isHidden = true
                widthConstraint?.isActive = false
            }
        }
        
        return result
    }
}
