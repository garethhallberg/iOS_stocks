//
//  YahooFinanceService.swift
//  StockTracker
//
//  Created by gareth15 on 28/04/2025.
//

import SwiftYFinance
import Foundation



class YahooFinanceService: FinanceServiceProtocol {
    private var cache: [String: (data: StockQuote, timestamp: Date)] = [:]
    private let cacheDuration: TimeInterval = 60 // Cache for 1 minute

    func fetchQuote(symbol: String) async throws -> StockQuote {
        let upperSymbol = symbol.uppercased()

        // Check cache (remains the same)
        if let cached = cache[upperSymbol], Date().timeIntervalSince(cached.timestamp) < cacheDuration {
            print("Using cache for \(upperSymbol)")
            return cached.data
        }
        print("Fetching \(upperSymbol) from API...")

        // --- Correction Start ---
        // Wrap the callback function using withCheckedThrowingContinuation
        let recentData: RecentStockData = try await withCheckedThrowingContinuation { continuation in
            SwiftYFinance.recentDataBy(identifier: upperSymbol) { data, error in
                if let error = error {
                    // If the API call resulted in an error, resume the continuation by throwing the error
                    continuation.resume(throwing: error)
                } else if let data = data {
                    // If the API call succeeded and returned data, resume the continuation by returning the data
                    continuation.resume(returning: data)
                } else {
                    // If both data and error are nil (should be rare, but handle it)
                    // Resume by throwing a custom error
                    let unknownError = NSError(domain: "YahooFinanceService", code: 2, userInfo: [NSLocalizedDescriptionKey: "API returned nil data and nil error for \(upperSymbol)"])
                    continuation.resume(throwing: unknownError)
                }
            }
        }
        // --- Correction End ---

        // Now 'recentData' holds the result if the continuation resumed normally
        // Process the 'recentData' as before
        let price = recentData.regularMarketPrice
        let prevClose = recentData.chartPreviousClose
        var change: Float? = nil
        var changePercent: Float? = nil

        if let price = price, let prevClose = prevClose, prevClose != 0 {
            change = price - prevClose
            changePercent = (change! / prevClose) * 100.0
        }

        let quote = StockQuote(symbol: upperSymbol,
                               shortName: recentData.exchangeName,
                               price: price,
                               change: change,
                               changePercent: changePercent)

        // Update cache
        cache[upperSymbol] = (data: quote, timestamp: Date())
        return quote
    }
}
