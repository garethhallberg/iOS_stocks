//
//  MockFinanceService.swift
//  StockTrackerTests
//
//  Created by gareth15 on 28/04/2025.
//

import Foundation
@testable import StockTracker // Import your main app module
import Foundation

class MockFinanceService: FinanceServiceProtocol {
    // Control what the mock returns
    var mockQuoteResult: Result<StockQuote, Error>?
    var fetchQuoteCalledWithSymbol: String?
    var fetchQuoteCallCount = 0

    func fetchQuote(symbol: String) async throws -> StockQuote {
        fetchQuoteCallCount += 1
        fetchQuoteCalledWithSymbol = symbol

        guard let result = mockQuoteResult else {
            // Default behavior if mock result isn't set
            throw NSError(domain: "MockFinanceService", code: 99, userInfo: [NSLocalizedDescriptionKey: "Mock result not set"])
        }

        switch result {
        case .success(let quote):
            // Simulate delay if needed: try? await Task.sleep(nanoseconds: 100_000_000)
            return quote
        case .failure(let error):
            throw error
        }
    }
}
