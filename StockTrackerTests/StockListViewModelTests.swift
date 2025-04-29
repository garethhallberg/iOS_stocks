//
//  StockListViewModelTests.swift
//  StockTrackerTests
//
//  Created by gareth15 on 28/04/2025.
//


import XCTest
import SwiftData
@testable import StockTracker // Import your main app module


/// Unit tests for the `StockListViewModel`.
/// Uses an in-memory SwiftData store and a mock finance service.
@MainActor // Ensures tests run on the main actor, necessary for @MainActor isolated ViewModel methods.
final class StockListViewModelTests: XCTestCase {

    // MARK: - Test Dependencies
    var viewModel: StockListViewModel!
    var mockFinanceService: MockFinanceService!
    var testModelContainer: ModelContainer! // Holds the in-memory SwiftData store
    var testModelContext: ModelContext!    // The context used by the ViewModel during tests

    // MARK: - Test Setup & Teardown

    /// Sets up the testing environment before each test method runs.
    /// Creates an in-memory SwiftData container, a mock finance service,
    /// and initializes the ViewModel with these test dependencies.
    override func setUpWithError() throws {
        try super.setUpWithError()

        // 1. Configure SwiftData for in-memory storage ONLY.
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        // 2. Create the ModelContainer with the configuration and necessary model types.
        // Ensure all @Model classes used by the ViewModel are listed here.
        testModelContainer = try ModelContainer(for: TrackedStock.self, configurations: config)
        // 3. Get the ModelContext from the in-memory container.
        testModelContext = testModelContainer.mainContext // Use mainContext for simplicity
        // 4. Create an instance of the mock finance service.
        mockFinanceService = MockFinanceService()
        // 5. Initialize the ViewModel, injecting the test context and mock service.
        viewModel = StockListViewModel(modelContext: testModelContext, financeService: mockFinanceService)

        // Set a default managed total value for tests unless overridden
        viewModel.managedTotalValue = 1000.0
    }

    /// Cleans up the testing environment after each test method runs.
    /// Releases references to ensure a clean state for the next test.
    override func tearDownWithError() throws {
        // Reset mock state
        mockFinanceService.reset()

        // Release objects
        viewModel = nil
        mockFinanceService = nil
        testModelContext = nil
        // Important: Nil out the container to ensure the in-memory store is destroyed.
        testModelContainer = nil

        try super.tearDownWithError()
    }

    // MARK: - Processing & Fetching Tests

    /// Tests the successful processing of stocks and fetching of quotes.
    func testProcessTrackedStocksSuccess() async throws {
            // Arrange:
            // 1. Add a stock to the test context with specific proportions.
            let stockSymbol = "AAPL"
            let trackedStock = TrackedStock(symbol: stockSymbol, targetProportion: 0.5) // Start at 50%
            testModelContext.insert(trackedStock)
            let trackedStocksInput = [trackedStock] // This is what the View's @Query would provide

            // 2. Configure the mock service to return a successful quote for AAPL.
            let mockQuote = StockQuote(symbol: stockSymbol, shortName: "Apple Inc.", price: 170.0, change: 1.0, changePercent: 0.59)
            mockFinanceService.mockQuoteResult = .success(mockQuote) // Set default success

            // Act: Call the ViewModel method to process stocks (includes fetching).
            await viewModel.processTrackedStocks(trackedStocksInput)

            // Assert:
            // 1. Check loading state.
            XCTAssertFalse(viewModel.isLoading, "isLoading should be false after processing completes")
            // 2. Check that the displayStocks array is populated correctly.
            XCTAssertEqual(viewModel.displayStocks.count, 1)
            let displayStock = viewModel.displayStocks.first
            XCTAssertEqual(displayStock?.symbol, stockSymbol)
            // Check normalized proportion
            XCTAssertEqual(displayStock?.targetProportion ?? -1.0, 1.0, accuracy: 0.0001, "Proportion should be normalized to 1.0 for single stock")
            // 3. Check that the quote data was received and attached.
            XCTAssertNotNil(displayStock?.quote, "Quote should not be nil")
            XCTAssertEqual(displayStock?.quote?.price, 170.0)
            // 4. Check calculated values based on managedTotalValue (1000) and *normalized* proportion (1.0)
            // *** CORRECTED ASSERTION: Expect 1000.0 as managed value due to normalization ***
            XCTAssertEqual(displayStock?.managedValue ?? -1.0, 1000.0, accuracy: 0.01, "Managed value should be 1000 * 1.0 (normalized)")
            XCTAssertNotNil(displayStock?.impliedQuantity, "Implied quantity should be calculated")
            XCTAssertEqual(displayStock?.impliedQuantity ?? -1.0, 1000.0 / 170.0, accuracy: 0.001)
            XCTAssertNotNil(displayStock?.currentValue, "Current value should be calculated")
            XCTAssertEqual(displayStock?.currentValue ?? -1.0, (1000.0 / 170.0) * 170.0, accuracy: 0.01) // Should be close to 1000
            // 5. Check that the error flag is false.
            XCTAssertFalse(displayStock?.fetchError ?? true, "fetchError should be false") // Default true to fail if nil
            // 6. Verify the mock service was called correctly.
            XCTAssertEqual(mockFinanceService.fetchQuoteCallCount, 1)
            XCTAssertEqual(mockFinanceService.fetchQuoteCalledWithSymbol, stockSymbol)
            // 7. Check total actual value
            XCTAssertEqual(viewModel.actualTotalValue, displayStock?.currentValue ?? -1.0, accuracy: 0.01)
        }

    /// Tests the handling of quote fetching failures during processing.
    func testProcessTrackedStocksFailure() async throws {
        // Arrange:
        // 1. Add a stock to the test context.
        let stockSymbol = "FAIL"
        let trackedStock = TrackedStock(symbol: stockSymbol, targetProportion: 1.0) // 100%
        testModelContext.insert(trackedStock)
        let trackedStocksInput = [trackedStock]

        // 2. Configure the mock service to return an error.
        let fetchError = NSError(domain: "TestError", code: 123, userInfo: [NSLocalizedDescriptionKey: "Simulated fetch failure"])
        mockFinanceService.mockQuoteResult = .failure(fetchError)

        // Act: Call process stocks.
        // *** CORRECTED METHOD NAME ***
        await viewModel.processTrackedStocks(trackedStocksInput)

        // Assert:
        // 1. Check loading state.
        XCTAssertFalse(viewModel.isLoading)
        // 2. Check displayStocks array content.
        XCTAssertEqual(viewModel.displayStocks.count, 1)
        let displayStock = viewModel.displayStocks.first
        XCTAssertEqual(displayStock?.symbol, stockSymbol)
        XCTAssertEqual(displayStock?.targetProportion, 1.0)
        // 3. Check that the quote is nil and calculated values are nil.
        XCTAssertNil(displayStock?.quote, "Quote should be nil on failure")
        XCTAssertNil(displayStock?.impliedQuantity, "Implied quantity should be nil on failure")
        XCTAssertNil(displayStock?.currentValue, "Current value should be nil on failure")
        XCTAssertEqual(displayStock?.managedValue ?? -1.0, 1000.0 * 1.0, accuracy: 0.01) // Managed value still calculated
        // 4. Check that the error flag is true.
        XCTAssertTrue(displayStock?.fetchError ?? false, "fetchError should be true") // Default false to fail if nil
        // 5. Verify mock interaction.
        XCTAssertEqual(mockFinanceService.fetchQuoteCallCount, 1)
        XCTAssertEqual(mockFinanceService.fetchQuoteCalledWithSymbol, stockSymbol)
        // 6. Check total actual value is 0
        XCTAssertEqual(viewModel.actualTotalValue, 0.0, accuracy: 0.01)
    }

    /// Tests processing multiple stocks concurrently.
        func testProcessMultipleStocks() async throws {
            print("--- Starting testProcessMultipleStocks ---") // DEBUG
            // Arrange
            let symbol1 = "GOOG"
            let symbol2 = "MSFT"
            // Proportions should sum to 1.0
            let stock1 = TrackedStock(symbol: symbol1, targetProportion: 0.6)
            let stock2 = TrackedStock(symbol: symbol2, targetProportion: 0.4)
            testModelContext.insert(stock1)
            testModelContext.insert(stock2)
            let trackedStocksInput = [stock1, stock2]
            print("Test Arrange: Added \(symbol1) (0.6) and \(symbol2) (0.4) to context.") // DEBUG

            let quote1 = StockQuote(symbol: symbol1, shortName: "Alphabet", price: 2800.0, change: 10.0, changePercent: 0.35)
            let quote2 = StockQuote(symbol: symbol2, shortName: "Microsoft", price: 300.0, change: -2.0, changePercent: -0.66)
            // Use symbol-specific results in the mock
            mockFinanceService.resultsBySymbol = [
                symbol1: .success(quote1),
                symbol2: .success(quote2)
            ]
            print("Test Arrange: Configured mock service for \(symbol1) and \(symbol2).") // DEBUG

            // Act
            print("Test Act: Calling processTrackedStocks...") // DEBUG
            await viewModel.processTrackedStocks(trackedStocksInput)
            print("Test Act: processTrackedStocks finished.") // DEBUG
            // Add a tiny delay to ensure state updates propagate (shouldn't be needed with @MainActor usually)
            // try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds - uncomment if needed for debugging

            // Assert
            print("Test Assert: Checking assertions...") // DEBUG
            XCTAssertFalse(viewModel.isLoading)
            XCTAssertEqual(viewModel.displayStocks.count, 2)
            XCTAssertEqual(mockFinanceService.fetchQuoteCallCount, 2) // Ensure both were fetched

            // Check data for GOOG (60% of 1000 = 600)
            let googDisplay = viewModel.displayStocks.first { $0.symbol == symbol1 }
            // *** DEBUG PRINT ***
            print("Test Assert: Found googDisplay: \(googDisplay != nil), Quote: \(googDisplay?.quote != nil)")
            XCTAssertNotNil(googDisplay, "GOOG display stock should be found") // Added check if googDisplay itself is nil
            XCTAssertNotNil(googDisplay?.quote, "GOOG quote should not be nil") // Original failing assertion
            XCTAssertEqual(googDisplay?.targetProportion ?? -1.0, 0.6, accuracy: 0.0001)
            XCTAssertEqual(googDisplay?.managedValue ?? -1.0, 600.0, accuracy: 0.01)
            XCTAssertEqual(googDisplay?.quote?.price, 2800.0)
            XCTAssertFalse(googDisplay?.fetchError ?? true)
            let googCurrentValue = googDisplay?.currentValue ?? -1.0

            // Check data for MSFT (40% of 1000 = 400)
            let msftDisplay = viewModel.displayStocks.first { $0.symbol == symbol2 }
            // *** DEBUG PRINT ***
            print("Test Assert: Found msftDisplay: \(msftDisplay != nil), Quote: \(msftDisplay?.quote != nil)")
            XCTAssertNotNil(msftDisplay, "MSFT display stock should be found") // Added check
            XCTAssertNotNil(msftDisplay?.quote, "MSFT quote should not be nil")
            XCTAssertEqual(msftDisplay?.targetProportion ?? -1.0, 0.4, accuracy: 0.0001)
            XCTAssertEqual(msftDisplay?.managedValue ?? -1.0, 400.0, accuracy: 0.01)
            XCTAssertEqual(msftDisplay?.quote?.price, 300.0)
            XCTAssertFalse(msftDisplay?.fetchError ?? true)
            let msftCurrentValue = msftDisplay?.currentValue ?? -1.0

            // Check total actual value
            XCTAssertEqual(viewModel.actualTotalValue, googCurrentValue + msftCurrentValue, accuracy: 0.01)
            print("--- Finished testProcessMultipleStocks ---") // DEBUG
        }


    // MARK: - Persistence Tests (Add/Delete/Update)

    /// Tests adding a new stock successfully via the ViewModel.
    func testAddStock() throws {
        guard let viewModel = viewModel else { XCTFail("ViewModel not initialized"); return }
        let newSymbol = "TSLA"

        // Act: Call the add method on the ViewModel.
        viewModel.addStock(symbol: newSymbol)

        // Assert: Verify the stock was added to the *test context* with 0 proportion.
        let fetchDescriptor = FetchDescriptor<TrackedStock>(predicate: #Predicate { $0.symbol == newSymbol })
        let results = try testModelContext.fetch(fetchDescriptor)
        XCTAssertEqual(results.count, 1, "Should find 1 stock with the new symbol")
        let addedStock = results.first
        XCTAssertEqual(addedStock?.symbol, newSymbol)
        XCTAssertEqual(addedStock?.targetProportion, 0.0, "Newly added stock should have 0 proportion")
    }

    /// Tests that adding a duplicate stock symbol is prevented.
    func testAddStockDuplicate() throws {
        guard let viewModel = viewModel else { XCTFail("ViewModel not initialized"); return }
        let symbol = "MSFT"

        // Act:
        // 1. Add the stock the first time.
        viewModel.addStock(symbol: symbol)
        // 2. Try adding the same stock again.
        viewModel.addStock(symbol: symbol)

        // Assert: Verify only one instance exists in the test context.
        let fetchDescriptor = FetchDescriptor<TrackedStock>(predicate: #Predicate { $0.symbol == symbol })
        let results = try testModelContext.fetch(fetchDescriptor)
        XCTAssertEqual(results.count, 1, "Should only find 1 stock after trying to add duplicate")
    }

    /// Tests adding a stock with leading/trailing whitespace and incorrect case.
    func testAddStockNormalization() throws {
         guard let viewModel = viewModel else { XCTFail("ViewModel not initialized"); return }
         let inputSymbol = "  amzn\t"
         let expectedSymbol = "AMZN"

         // Act
         viewModel.addStock(symbol: inputSymbol)

         // Assert
         let fetchDescriptor = FetchDescriptor<TrackedStock>(predicate: #Predicate { $0.symbol == expectedSymbol })
         let results = try testModelContext.fetch(fetchDescriptor)
         XCTAssertEqual(results.count, 1, "Should find 1 stock with the normalized symbol")
         XCTAssertEqual(results.first?.symbol, expectedSymbol)
    }

    /// Tests deleting an existing stock via the ViewModel and checks proportion redistribution.
    func testDeleteStockAndRedistribute() throws {
        guard let viewModel = viewModel else { XCTFail("ViewModel not initialized"); return }
        // Arrange: Add multiple stocks with proportions summing to 1.0
        let stockToDelete = TrackedStock(symbol: "NVDA", targetProportion: 0.2) // 20%
        let stockToKeep1 = TrackedStock(symbol: "AMD", targetProportion: 0.3)  // 30%
        let stockToKeep2 = TrackedStock(symbol: "INTC", targetProportion: 0.5) // 50%
        testModelContext.insert(stockToDelete)
        testModelContext.insert(stockToKeep1)
        testModelContext.insert(stockToKeep2)
        // Update ViewModel's internal list to simulate @Query result before delete
        viewModel.currentTrackedStocks = [stockToDelete, stockToKeep1, stockToKeep2]

        // Act: Call the delete method on the ViewModel.
        viewModel.deleteStock(stockToDelete: stockToDelete)

        // Assert:
        // 1. Verify the stock was deleted from the context.
        let deleteFetch = FetchDescriptor<TrackedStock>(predicate: #Predicate { $0.symbol == "NVDA" })
        let deleteResults = try testModelContext.fetch(deleteFetch)
        XCTAssertEqual(deleteResults.count, 0, "Deleted stock should not be found")

        // 2. Verify the remaining stocks exist and their proportions were updated.
        let keepFetch1 = FetchDescriptor<TrackedStock>(predicate: #Predicate { $0.symbol == "AMD" })
        let keepResults1 = try testModelContext.fetch(keepFetch1)
        XCTAssertEqual(keepResults1.count, 1, "Kept stock 1 should exist")
        // Expected new proportion for AMD: 0.3 + (0.2 * (0.3 / (0.3 + 0.5))) = 0.3 + (0.2 * (0.3 / 0.8)) = 0.3 + (0.2 * 0.375) = 0.3 + 0.075 = 0.375
        XCTAssertEqual(keepResults1.first?.targetProportion ?? -1.0, 0.375, accuracy: 0.0001, "AMD proportion should be redistributed")

        let keepFetch2 = FetchDescriptor<TrackedStock>(predicate: #Predicate { $0.symbol == "INTC" })
        let keepResults2 = try testModelContext.fetch(keepFetch2)
        XCTAssertEqual(keepResults2.count, 1, "Kept stock 2 should exist")
        // Expected new proportion for INTC: 0.5 + (0.2 * (0.5 / (0.3 + 0.5))) = 0.5 + (0.2 * (0.5 / 0.8)) = 0.5 + (0.2 * 0.625) = 0.5 + 0.125 = 0.625
        XCTAssertEqual(keepResults2.first?.targetProportion ?? -1.0, 0.625, accuracy: 0.0001, "INTC proportion should be redistributed")

        // 3. Verify the sum of remaining proportions is 1.0
        let finalSum = (keepResults1.first?.targetProportion ?? 0) + (keepResults2.first?.targetProportion ?? 0)
        XCTAssertEqual(finalSum, 1.0, accuracy: 0.0001, "Final sum of proportions should be 1.0")
    }

    /// Tests updating a stock's proportion and checks redistribution.
    func testUpdateProportionAndRedistribute() throws {
         guard let viewModel = viewModel else { XCTFail("ViewModel not initialized"); return }
         // Arrange
         let stockToUpdate = TrackedStock(symbol: "AAPL", targetProportion: 0.5) // 50%
         let stockOther1 = TrackedStock(symbol: "GOOG", targetProportion: 0.3)  // 30%
         let stockOther2 = TrackedStock(symbol: "MSFT", targetProportion: 0.2)  // 20%
         testModelContext.insert(stockToUpdate)
         testModelContext.insert(stockOther1)
         testModelContext.insert(stockOther2)
         viewModel.currentTrackedStocks = [stockToUpdate, stockOther1, stockOther2] // Simulate @Query

         let newProportionForAAPL: Double = 0.7 // Update AAPL to 70%

         // Act
         viewModel.updateProportionAndRedistribute(trackedStock: stockToUpdate, newProportionInput: newProportionForAAPL)

         // Assert
         // 1. Check updated stock
         XCTAssertEqual(stockToUpdate.targetProportion, 0.7, accuracy: 0.0001)

         // 2. Check other stocks (total proportion was 0.3 + 0.2 = 0.5)
         // Delta was 0.7 - 0.5 = +0.2. This needs to be removed from others.
         // GOOG adjustment: -0.2 * (0.3 / 0.5) = -0.2 * 0.6 = -0.12. New GOOG = 0.3 - 0.12 = 0.18
         XCTAssertEqual(stockOther1.targetProportion, 0.18, accuracy: 0.0001)
         // MSFT adjustment: -0.2 * (0.2 / 0.5) = -0.2 * 0.4 = -0.08. New MSFT = 0.2 - 0.08 = 0.12
         XCTAssertEqual(stockOther2.targetProportion, 0.12, accuracy: 0.0001)

         // 3. Check sum is 1.0
         let finalSum = stockToUpdate.targetProportion + stockOther1.targetProportion + stockOther2.targetProportion
         XCTAssertEqual(finalSum, 1.0, accuracy: 0.0001)
    }

     /// Tests updating proportion when other stocks have zero proportion.
     func testUpdateProportionWithZeros() throws {
         guard let viewModel = viewModel else { XCTFail("ViewModel not initialized"); return }
         // Arrange
         let stockToUpdate = TrackedStock(symbol: "AAPL", targetProportion: 0.0)
         let stockOther1 = TrackedStock(symbol: "GOOG", targetProportion: 0.0)
         let stockOther2 = TrackedStock(symbol: "MSFT", targetProportion: 0.0)
         testModelContext.insert(stockToUpdate)
         testModelContext.insert(stockOther1)
         testModelContext.insert(stockOther2)
         viewModel.currentTrackedStocks = [stockToUpdate, stockOther1, stockOther2]

         let newProportionForAAPL: Double = 0.6 // Update AAPL to 60%

         // Act
         viewModel.updateProportionAndRedistribute(trackedStock: stockToUpdate, newProportionInput: newProportionForAAPL)

         // Assert
         XCTAssertEqual(stockToUpdate.targetProportion, 0.6, accuracy: 0.0001)
         // Remaining 0.4 should be split equally between GOOG and MSFT (0.2 each)
         XCTAssertEqual(stockOther1.targetProportion, 0.2, accuracy: 0.0001)
         XCTAssertEqual(stockOther2.targetProportion, 0.2, accuracy: 0.0001)
         // Check sum
         let finalSum = stockToUpdate.targetProportion + stockOther1.targetProportion + stockOther2.targetProportion
         XCTAssertEqual(finalSum, 1.0, accuracy: 0.0001)
     }

     /// Tests clamping of proportion update (cannot go above 1.0 or below 0.0)
     func testUpdateProportionClamping() throws {
          guard let viewModel = viewModel else { XCTFail("ViewModel not initialized"); return }
          // Arrange
          let stockToUpdate = TrackedStock(symbol: "AAPL", targetProportion: 0.5)
          let stockOther1 = TrackedStock(symbol: "GOOG", targetProportion: 0.5)
          testModelContext.insert(stockToUpdate)
          testModelContext.insert(stockOther1)
          viewModel.currentTrackedStocks = [stockToUpdate, stockOther1]

          // Act: Try to update beyond 1.0
          viewModel.updateProportionAndRedistribute(trackedStock: stockToUpdate, newProportionInput: 1.2)

          // Assert: Should be clamped to 1.0, other should be 0.0
          XCTAssertEqual(stockToUpdate.targetProportion, 1.0, accuracy: 0.0001)
          XCTAssertEqual(stockOther1.targetProportion, 0.0, accuracy: 0.0001)

          // Act: Try to update below 0.0
          viewModel.updateProportionAndRedistribute(trackedStock: stockToUpdate, newProportionInput: -0.3)

          // Assert: Should be clamped to 0.0, other should be 1.0
          XCTAssertEqual(stockToUpdate.targetProportion, 0.0, accuracy: 0.0001)
          XCTAssertEqual(stockOther1.targetProportion, 1.0, accuracy: 0.0001)
     }
}
