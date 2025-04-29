//
//  StockListViewModelTests.swift
//  StockTrackerTests
//
//  Created by gareth15 on 28/04/2025.
//


import XCTest
import SwiftData
@testable import StockTracker // Import your main app module

@MainActor // Run tests accessing MainActor-isolated ViewModel on the main actor
final class StockListViewModelTests: XCTestCase {

    var viewModel: StockListViewModel!
    var mockFinanceService: MockFinanceService!
    var testModelContainer: ModelContainer! // To hold the in-memory store
    var testModelContext: ModelContext!    // The context to inject/use

    override func setUpWithError() throws {
        try super.setUpWithError()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        testModelContainer = try ModelContainer(for: TrackedStock.self, configurations: config)
        testModelContext = testModelContainer.mainContext
        mockFinanceService = MockFinanceService()

        // CORRECTED: Use the init that takes both context and service
        viewModel = StockListViewModel(modelContext: testModelContext, financeService: mockFinanceService)
    }

    override func tearDownWithError() throws {
        // Clean up
        viewModel = nil
        mockFinanceService = nil
        testModelContext = nil
        testModelContainer = nil
        try super.tearDownWithError()
    }

    // --- Example Test Cases ---

    func testFetchQuotesSuccess() async throws {
        // Arrange
        // a) Add some symbols to the *test* context (simulating @Query result)
        let stock1 = TrackedStock(symbol: "AAPL")
        let stock2 = TrackedStock(symbol: "GOOG")
        let stock3 = TrackedStock(symbol: "IBM")
        testModelContext.insert(stock1)
        testModelContext.insert(stock2)
        testModelContext.insert(stock3)
        try testModelContext.save() // Ensure they are saved before fetch

        let trackedStocksFromTestContext = try testModelContext.fetch(FetchDescriptor<TrackedStock>()) // Simulate View's @Query data


        // b) Configure the mock service to return success
        let mockQuoteAAPL = StockQuote(symbol: "AAPL", shortName: "Apple Inc.", price: 170.0, change: 1.0, changePercent: 0.59)
        let mockQuoteGOOG = StockQuote(symbol: "GOOG", shortName: "Alphabet Inc.", price: 2800.0, change: -10.0, changePercent: -0.36)
        let mockQuoteIBM = StockQuote(symbol: "IBM", shortName: "IBM Inc.", price: 2800.0, change: -10.0, changePercent: -0.36)
        // Setup mock to return specific quotes based on symbol (more advanced mock needed)
        // Or for simpler test, assume it returns a generic successful quote for any symbol called
         mockFinanceService.mockQuoteResult = .success(mockQuoteAAPL) // Simplistic example


        // Act
        await viewModel.fetchQuotes(for: trackedStocksFromTestContext) // Call the method under test

        // Assert
        XCTAssertFalse(viewModel.isLoading, "isLoading should be false after fetch completes")
        XCTAssertEqual(viewModel.displayStocks.count, 3, "Should have 3 display stocks")

         // Check specific data (requires more sophisticated mock setup)
         let aaplDisplay = viewModel.displayStocks.first { $0.symbol == "AAPL" }
         XCTAssertNotNil(aaplDisplay?.quote, "AAPL quote should not be nil")
         XCTAssertEqual(aaplDisplay?.quote?.price, 170.0, "AAPL price should match mock")
         XCTAssertFalse(aaplDisplay?.fetchError ?? true, "AAPL fetchError should be false")


        // Verify mock was called
          XCTAssertEqual(mockFinanceService.fetchQuoteCallCount, 3) // Check how many times API was called
    }

    func testFetchQuotesFailure() async throws {
        // Arrange
        let stock1 = TrackedStock(symbol: "FAIL")
        testModelContext.insert(stock1)
        try testModelContext.save()
         let trackedStocksFromTestContext = try testModelContext.fetch(FetchDescriptor<TrackedStock>())

        let fetchError = NSError(domain: "TestError", code: 123)
        mockFinanceService.mockQuoteResult = .failure(fetchError)

        // Act
        await viewModel.fetchQuotes(for: trackedStocksFromTestContext)

        // Assert
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.displayStocks.count, 1)
        let failDisplay = viewModel.displayStocks.first
        XCTAssertNil(failDisplay?.quote, "Quote should be nil on failure")
        XCTAssertTrue(failDisplay?.fetchError ?? false, "fetchError should be true")
    }

    // testAddStock (is now valid again)
    func testAddStock() throws {
        guard let viewModel = viewModel else { XCTFail("ViewModel not initialized"); return }
        let newSymbol = "TSLA"

        // Act: Call the add method on the ViewModel
        viewModel.addStock(symbol: newSymbol)

        // Assert: Fetch directly from the test context to see if it was added
        let fetchDescriptor = FetchDescriptor<TrackedStock>(predicate: #Predicate { $0.symbol == newSymbol })
        let results = try testModelContext.fetch(fetchDescriptor)
        XCTAssertEqual(results.count, 1, "Should find 1 stock with the new symbol")
        XCTAssertEqual(results.first?.symbol, newSymbol)

        // Add assertion for duplicate prevention
        viewModel.addStock(symbol: newSymbol) // Try adding again
        let resultsAfterDuplicate = try testModelContext.fetch(fetchDescriptor)
         XCTAssertEqual(resultsAfterDuplicate.count, 1, "Count should still be 1 after trying to add duplicate")

    }

    // testDeleteStock becomes relevant too
    func testDeleteStock() throws {
        guard let viewModel = viewModel else { XCTFail("ViewModel not initialized"); return }
        let symbolToDelete = "AAPL"
        let stockToDelete = TrackedStock(symbol: symbolToDelete)

        // Arrange: Add item first using the test context directly or via VM
        testModelContext.insert(stockToDelete)
        try testModelContext.save() // Make sure it's saved before delete

        // Act: Call delete method on ViewModel
        viewModel.deleteStock(stock: stockToDelete)

        // Assert: Fetch from test context to verify deletion
        let fetchDescriptor = FetchDescriptor<TrackedStock>(predicate: #Predicate { $0.symbol == symbolToDelete })
        let results = try testModelContext.fetch(fetchDescriptor)
        XCTAssertEqual(results.count, 0, "Stock should have been deleted")
    }
}

 // Hypothetical extension to ViewModel if it handles context internally
 extension StockListViewModel {
     func addStockUsingContext(symbol: String) {
         // This function would live in the real ViewModel if it handles persistence
         let cleanedSymbol = symbol.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
         guard !cleanedSymbol.isEmpty else { return }
         // Add duplicate check using context...
         let newStock = TrackedStock(symbol: cleanedSymbol)
        
     }
 }
