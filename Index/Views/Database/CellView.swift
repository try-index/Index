//
//  CellView.swift
//  Index
//
//  Created by Axel Martinez on 13/3/25.
//

import SQLiteKit
import SwiftUI

struct CellView: View {
    let value: Value
    
    var body: some View {
        switch value {
        case .array(let array):
            Text("[\(displayArray(array))]")
        default:
            content(from: value)
        }
    }
    
    func displayArray(_ array: [Value]) -> Text {
        return array.map({content(from: $0)}).reduce(Text(""), {
            if $0 == Text("") { return $1 }
            return Text("\($0),\($1)")
        })
    }
                                              
    func content(from innerValue: Value) -> Text {
        switch innerValue {
        case .text(let text):
            return Text(text)
                .foregroundStyle(Color(XcodeThemeColors.string))
        case .integer(let integer):
            return Text(integer.description)
                .foregroundStyle(Color(XcodeThemeColors.number))
        case .null:
            return Text("nil")
                .foregroundStyle(Color(XcodeThemeColors.keyword))
                .fontWeight(.semibold)
        case .image(let image):
            return Text(image.description)
        case .timestamp(let date):
            return Text(date.ISO8601Format())
        default:
            return Text("")
        }
    }
}
