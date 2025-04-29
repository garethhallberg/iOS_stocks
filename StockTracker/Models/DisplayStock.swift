//
//  DisplayStock.swift
//  StockTracker
//
//  Created by gareth15 on 29/04/2025.
//

import Foundation

/// A struct representing the combined data needed to display a single stock row in the UI.
/// Includes persisted data (symbol, quantity) and live/calculated data (quote, value).
struct DisplayStock: Identifiable {
    let id: String
    let symbol: String
    var targetProportion: Double // User's desired allocation (0.0 to 1.0)
    var quote: StockQuote?
    var managedValue: Double?    // Value based on managedTotalValue * targetProportion
    var currentValue: Double?    // Value based on implied quantity * current price
    var impliedQuantity: Double? // Quantity needed for managedValue at current price
    var fetchError: Bool = false

    /// Initializer calculating values based on the managed total.
    init(trackedStock: TrackedStock, managedTotalValue: Double, quote: StockQuote? = nil, fetchError: Bool = false) {
        self.id = trackedStock.symbol
        self.symbol = trackedStock.symbol
        self.targetProportion = trackedStock.targetProportion
        self.quote = quote
        self.fetchError = fetchError

        // Calculate value based on the fixed managed total and proportion
        self.managedValue = managedTotalValue * targetProportion

        // Calculate implied quantity and current market value if price is available
        if let price = quote?.price, price > 0 {
            let priceAsDouble = Double(price)
            // Implied quantity needed to achieve the managedValue at the current price
            self.impliedQuantity = (self.managedValue ?? 0) / priceAsDouble
            // Current market value = implied quantity * current price
            // This might differ slightly from managedValue due to rounding or if price is exactly 0
            self.currentValue = (self.impliedQuantity ?? 0) * priceAsDouble
        } else {
            self.impliedQuantity = nil
            self.currentValue = nil // Cannot calculate without price
        }
    }
}
