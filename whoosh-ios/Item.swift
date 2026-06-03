//
//  Item.swift
//  whoosh-ios
//
//  Created by Brayden Pelt on 6/2/26.
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
