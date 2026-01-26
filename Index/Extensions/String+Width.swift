//
//  String+Width.swift
//  Index
//
//  Created by Axel Martinez on 12/4/25.
//

import SwiftUI

extension String {
    func estimatedWidth(using font: NSFont, padding: CGFloat = 20) -> CGFloat {
        let fontAttributes = [NSAttributedString.Key.font: font]
        let size = (self as NSString).size(withAttributes: fontAttributes)
        return size.width + padding // Add some padding
    }
}
