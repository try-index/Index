//
//  HeaderCell.swift
//  Index
//
//  Created by Axel Martinez on 17/2/26.
//

import AppKit

// Custom header cell for styled column headers
class HeaderCell: NSTableHeaderCell {
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        // Clear background (no grey fill)
        NSColor.clear.setFill()
        cellFrame.fill()
        
        // Use the same grid color as the table
        guard let tableView = (controlView as? NSTableHeaderView)?.tableView else {
            return
        }
        
        tableView.gridColor.setStroke()
        
        // Bottom border (full width) - at the bottom of the header
        let bottomPath = NSBezierPath()
        bottomPath.move(to: NSPoint(x: cellFrame.minX, y: cellFrame.maxY))
        bottomPath.line(to: NSPoint(x: cellFrame.maxX, y: cellFrame.maxY))
        bottomPath.lineWidth = 1
        bottomPath.stroke()
        
        // Right border (vertical separator) - small and subtle like SwiftUI
        let separatorHeight: CGFloat = 12
        let separatorY = (cellFrame.height - separatorHeight) / 2
        
        let rightPath = NSBezierPath()
        rightPath.move(to: NSPoint(x: cellFrame.maxX - 0.5, y: separatorY))
        rightPath.line(to: NSPoint(x: cellFrame.maxX - 0.5, y: separatorY + separatorHeight))
        rightPath.lineWidth = 0.5
        rightPath.stroke()
        
        // Draw text
        let textRect = NSRect(
            x: cellFrame.origin.x + 8,
            y: cellFrame.origin.y + (cellFrame.height - 20) / 2,
            width: cellFrame.width - 16,
            height: 20
        )
        
        attributedStringValue.draw(in: textRect)
    }
}
