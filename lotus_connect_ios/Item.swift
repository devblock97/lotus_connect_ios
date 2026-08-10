//
//  Item.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 10/8/26.
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
