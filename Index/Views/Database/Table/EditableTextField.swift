//
//  EditableTextField.swift
//  Index
//
//  Created by Axel Martinez on 17/2/26.
//

import AppKit

// Custom text field that stores its value type for syntax coloring
class EditableTextField: NSTextField {
    var valueType: Value = .null
    var isForeignKey: Bool = false
    var widthConstraint: NSLayoutConstraint?
    
    weak var foreignKeyButton: NSButton?
    
    var syntaxColor: NSColor {
        // Color based on data type, not key type
        switch valueType {
        case .text:
            return NSColor(XcodeThemeColors.string)
        case .integer, .smallint, .real, .float:
            return NSColor(XcodeThemeColors.number)
        case .null:
            return NSColor(XcodeThemeColors.keyword)
        default:
            return .labelColor
        }
    }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        
        if result {
            // Restore syntax color
            self.textColor = syntaxColor
            
            // Clear placeholder
            if self.stringValue == "NULL", case .null = valueType {
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
