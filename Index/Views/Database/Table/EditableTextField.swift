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
    
    var syntaxColor: NSColor {
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
    
    override func mouseDown(with event: NSEvent) {
        self.textColor = syntaxColor
        
        super.mouseDown(with: event)
    }
    
    override func keyDown(with event: NSEvent) {
        // Handle keyboard entry (like pressing Enter or Return to edit)
        self.textColor = syntaxColor
        
        super.keyDown(with: event)
    }
}
