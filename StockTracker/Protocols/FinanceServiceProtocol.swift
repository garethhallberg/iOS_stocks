//
//  FinanceServiceProtocol.swift
//  StockTracker
//
//  Created by gareth15 on 28/04/2025.
//

import Foundation

protocol FinanceServiceProtocol {
    // Define the function signature(s) needed by the ViewModel
    func fetchQuote(symbol: String) async throws -> StockQuote
    // Add other methods if needed later
}
