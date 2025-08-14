//
//  Item.swift
//  PropertyManager
//
//  Created by Jake Gibbons on 14/08/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
