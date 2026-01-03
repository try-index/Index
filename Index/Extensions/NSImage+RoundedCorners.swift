//
//  NSImage+RoundedCorners.swift
//  Data Inspector
//
//  Created by Axel Martinez on 27/11/24.
//

import SwiftUI

extension NSImage {
    /// Creates a new NSImage with rounded corners
    /// - Parameters:
    ///   - cornerRadius: The radius of the corners
    ///   - borderWidth: Optional border width around the image
    ///   - borderColor: Optional border color
    /// - Returns: A new NSImage with rounded corners
    func withRoundedCorners(
        cornerRadius: CGFloat,
        borderWidth: CGFloat = 0,
        borderColor: NSColor = .clear
    ) -> NSImage {
        let imageSize = self.size
        
        // Create a new image with rounded corners
        let newImage = NSImage(size: imageSize, flipped: false) { rect in
            // Create a bezier path with rounded corners
            let path = NSBezierPath(
                roundedRect: rect,
                xRadius: cornerRadius,
                yRadius: cornerRadius
            )
            path.addClip()
            
            // Draw the original image
            self.draw(in: rect)
            
            // Add border if specified
            if borderWidth > 0 {
                borderColor.setStroke()
                path.lineWidth = borderWidth * 2
                path.stroke()
            }
            
            return true
        }
        
        return newImage
    }
}
