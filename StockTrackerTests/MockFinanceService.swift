@testable import StockTracker // Import main app module to access protocols/models
import Foundation

/// A mock implementation of `FinanceServiceProtocol` used for unit testing.
/// Allows controlling the results returned by `fetchQuote` without making real network calls.
class MockFinanceService: FinanceServiceProtocol {

    /// The result (success with a `StockQuote` or failure with an `Error`)
    /// that the `fetchQuote` method should return by default. Set this in your test setup.
    var mockQuoteResult: Result<StockQuote, Error>?

    /// Optional dictionary to provide specific results for specific symbols.
    /// If a symbol exists here, its result is used; otherwise, `mockQuoteResult` is used.
    var resultsBySymbol: [String: Result<StockQuote, Error>] = [:]

    /// Records the last symbol passed to `fetchQuote` for verification in tests.
    var fetchQuoteCalledWithSymbol: String?
    /// Counts how many times `fetchQuote` has been called.
    var fetchQuoteCallCount = 0

    /// Mock implementation of the protocol method.
    /// Checks `resultsBySymbol` first, then `mockQuoteResult` to determine the outcome.
    /// - Parameter symbol: The symbol passed by the caller (e.g., the ViewModel).
    /// - Returns: A `StockQuote` if configured for success.
    /// - Throws: An `Error` if configured for failure or if no result is set.
    func fetchQuote(symbol: String) async throws -> StockQuote {
        fetchQuoteCallCount += 1
        fetchQuoteCalledWithSymbol = symbol
        let upperSymbol = symbol.uppercased() // Use consistent casing for lookup

        // *** ADDED DETAILED DEBUGGING ***
        print("------------------------------------")
        print("MockFinanceService fetchQuote called for: \(upperSymbol)")
        print("Current resultsBySymbol keys: \(resultsBySymbol.keys.sorted())")
        print("Current mockQuoteResult is set: \(mockQuoteResult != nil)")
        print("Looking up key: '\(upperSymbol)' in resultsBySymbol...")
        // *** END DEBUGGING ***

        // 1. Check for symbol-specific result first
        if let symbolResult = resultsBySymbol[upperSymbol] {
            print("MockFinanceService found specific result for \(upperSymbol)")
            switch symbolResult {
            case .success(let quote):
                // Ensure the returned quote's symbol matches the requested one
                let consistentQuote = StockQuote(symbol: upperSymbol, shortName: quote.shortName, price: quote.price, change: quote.change, changePercent: quote.changePercent)
                 print("--> Returning SUCCESS for \(upperSymbol)")
                 print("------------------------------------")
                return consistentQuote
            case .failure(let error):
                 print("--> Throwing specific FAILURE for \(upperSymbol): \(error.localizedDescription)")
                 print("------------------------------------")
                throw error
            }
        }
        print("MockFinanceService did NOT find specific result for \(upperSymbol). Checking default...") // DEBUG

        // 2. Fallback to the general mock result
        guard let defaultResult = mockQuoteResult else {
            // If no specific result AND no default result, throw an error.
            let unsetError = NSError(domain: "MockFinanceService", code: 99, userInfo: [NSLocalizedDescriptionKey: "Mock result not set for symbol \(upperSymbol) and no default result provided."])
            print("--> Throwing FAILURE (No result configured) for \(upperSymbol)")
            print("------------------------------------")
            throw unsetError
        }

        // Process the default result
        print("MockFinanceService processing default result...") // DEBUG
        switch defaultResult {
        case .success(let quote):
             // Return a quote matching the requested symbol for consistency, even from default
             let symbolSpecificQuote = StockQuote(symbol: upperSymbol,
                                                shortName: quote.shortName,
                                                price: quote.price,
                                                change: quote.change,
                                                changePercent: quote.changePercent)
             print("--> Returning default SUCCESS for \(upperSymbol)")
             print("------------------------------------")
             // Optional: Simulate network delay
             // try? await Task.sleep(for: .milliseconds(50))
             return symbolSpecificQuote
        case .failure(let error):
            print("--> Throwing default FAILURE for \(upperSymbol): \(error.localizedDescription)")
            print("------------------------------------")
            throw error
        }
    }

    /// Helper function to reset the mock's state between tests.
    /// This ensures that results and call counts from one test do not affect the next.
    func reset() {
        mockQuoteResult = nil
        resultsBySymbol = [:]
        fetchQuoteCalledWithSymbol = nil
        fetchQuoteCallCount = 0
        print("------------------------------------")
        print("MockFinanceService reset.")
        print("------------------------------------")
    }
}
