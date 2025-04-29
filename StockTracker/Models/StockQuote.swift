//
//  YahooFinanceService.swift
//  StockTracker
//
//  Created by gareth15 on 28/04/2025.
//

import Foundation
import SwiftYFinance

// Struct to hold the live quote data temporarily
struct StockQuote: Identifiable {
    let id = UUID() // Useful if we ever list quotes directly
    let symbol: String
    let shortName: String?
    let price: Float?
    let change: Float?
    let changePercent: Float?
}


