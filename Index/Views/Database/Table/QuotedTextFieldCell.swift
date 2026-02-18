//
//  QuotedTextFieldCell.swift
//  Index
//
//  Created by Axel Martinez on 18/2/26.
//

import AppKit

// Custom text field cell that displays quotes around text values
class QuotedTextFieldCell: NSTextFieldCell {
    var valueType: Value = .null
    
    private var originalStringValue: String = ""
    private var isCurrentlyEditing: Bool = false
    
    override var stringValue: String {
        get {
            // When editing or getting the value, return the original with newlines
            if isCurrentlyEditing {
                return originalStringValue
            }
            return super.stringValue
        }
        set {
            // Store the original value
            originalStringValue = newValue
            
            // Process the value for display only
            var processedValue = newValue
            
            // Replace newlines with spaces for display
            if processedValue.contains("\n") || processedValue.contains("\r") {
                processedValue = processedValue.replacingOccurrences(of: "\r\n", with: " ")
                processedValue = processedValue.replacingOccurrences(of: "\n", with: " ")
                processedValue = processedValue.replacingOccurrences(of: "\r", with: " ")
                
                // Collapse multiple consecutive spaces
                while processedValue.contains("  ") {
                    processedValue = processedValue.replacingOccurrences(of: "  ", with: " ")
                }
                
                processedValue = processedValue.trimmingCharacters(in: .whitespaces)
            }
            
            super.stringValue = processedValue
        }
    }
    
    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        // Check if currently editing by seeing if there's an active field editor
        if let window = controlView.window,
           let fieldEditor = window.fieldEditor(false, for: controlView),
           fieldEditor.delegate === controlView {
            isCurrentlyEditing = true
        } else {
            isCurrentlyEditing = false
        }
        
        if isCurrentlyEditing {
            // When editing, show newlines as literal \n characters
            let currentValue = super.stringValue
            
            var editingValue = originalStringValue
            editingValue = editingValue.replacingOccurrences(of: "\r\n", with: "\\n")
            editingValue = editingValue.replacingOccurrences(of: "\n", with: "\\n")
            editingValue = editingValue.replacingOccurrences(of: "\r", with: "\\n")
            
            super.stringValue = editingValue
            super.drawInterior(withFrame: cellFrame, in: controlView)
            super.stringValue = currentValue
        } else {
            // When not editing, add quotes for text values
            if case .text = valueType {
                let currentValue = super.stringValue
                super.stringValue = "\"\(currentValue)\""
                super.drawInterior(withFrame: cellFrame, in: controlView)
                super.stringValue = currentValue
            } else {
                super.drawInterior(withFrame: cellFrame, in: controlView)
            }
        }
    }
    
    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        isCurrentlyEditing = true
        // Convert actual newlines to literal \n for editing
        var editableString = originalStringValue
        editableString = editableString.replacingOccurrences(of: "\r\n", with: "\\n")
        editableString = editableString.replacingOccurrences(of: "\n", with: "\\n")
        editableString = editableString.replacingOccurrences(of: "\r", with: "\\n")
        
        super.stringValue = editableString
        super.edit(withFrame: rect, in: controlView, editor: textObj, delegate: delegate, event: event)
    }
    
    override func endEditing(_ textObj: NSText) {
        // Convert literal \n back to actual newlines
        var editedString = textObj.string
        editedString = editedString.replacingOccurrences(of: "\\n", with: "\n")
        
        // Update the original value
        originalStringValue = editedString
        isCurrentlyEditing = false
        super.endEditing(textObj)
    }
}
