//
//  Simulator.swift
//  Index
//
//  Created by Axel Martinez on 21/11/24.
//

import Foundation

struct Simulator: Identifiable, Hashable, Comparable {
    var id: String {
        url.path()
    }
    
    let name: String
    let runtime: String
    let url: URL
    
    static func < (lhs: Simulator, rhs: Simulator) -> Bool {
        lhs.name < rhs.name
    }
}
