//
//  File.swift
//  StockTracker
//
//  Created by gareth15 on 28/04/2025.
//

import SwiftData
import Foundation

@Model
final class TrackedStock {
    @Attribute(.unique) // Ensures 'symbol' must be unique in the database
    var symbol: String
    var addedDate: Date // Good practice to store when it was added

    init(symbol: String, addedDate: Date = Date()) {
        // Normalize symbol on creation
        self.symbol = symbol.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.addedDate = addedDate
    }
}
