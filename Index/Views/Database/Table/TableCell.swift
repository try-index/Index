//
//  SelectableTableCell.swift
//  Index
//
//  Created by Axel Martinez on 17/2/26.
//

import AppKit

// Custom table cell view that updates colors based on selection state
class TableCell: NSTableCellView {
    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            updateColors()
        }
    }

    func updateColors() {
        guard let textField = textField as? EditableTextField else {
            return
        }
        
        if backgroundStyle == .emphasized {
            // Row is selected - use white text for readability
            textField.textColor = .white
        } else {
            // Row is not selected - use syntax coloring
            textField.textColor = textField.syntaxColor
        }
    }
}
