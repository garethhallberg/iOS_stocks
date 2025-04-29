import SwiftUI
import SwiftData
import Combine // Keep for potential future use


/// ViewModel managing tracked stocks, persistence, fetching quotes, and portfolio allocation logic.
@Observable
class StockListViewModel {
    var displayStocks: [DisplayStock] = []
    /// The user-defined fixed total value the proportions apply to.
    var managedTotalValue: Double = 1000.0 { // Default or load from UserDefaults
        didSet {
            // Ensure non-negative
            if managedTotalValue < 0 { managedTotalValue = 0 }
            // Trigger recalculation when this changes
            Task { @MainActor in await self.recalculateDisplayData() }
            // TODO: Save to UserDefaults if needed
        }
    }
    /// The calculated actual market value based on current prices. Shows drift.
    var actualTotalValue: Double = 0.0
    var isLoading: Bool = false

    private let financeService: FinanceServiceProtocol
    internal let modelContext: ModelContext
    internal var currentTrackedStocks: [TrackedStock] = [] // Keep track of fetched objects

    /// Initializer
    init(modelContext: ModelContext, financeService: FinanceServiceProtocol = YahooFinanceService()) {
        self.modelContext = modelContext
        self.financeService = financeService
        print("StockListViewModel initialized WITH context and using \(type(of: financeService))")
        // TODO: Load managedTotalValue from UserDefaults if desired
    }

    // MARK: - Persistence Methods (Add/Delete - Slightly Modified)

    /// Adds a new stock symbol. It starts with 0% proportion, requiring user adjustment.
    func addStock(symbol: String) {
        let cleanedSymbol = symbol.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedSymbol.isEmpty else { return }

        // --- Duplicate Check (same as before) ---
        let predicate = #Predicate<TrackedStock> { $0.symbol == cleanedSymbol }
        var fetchDescriptor = FetchDescriptor(predicate: predicate)
        fetchDescriptor.fetchLimit = 1
        do {
            let existing = try modelContext.fetch(fetchDescriptor)
            guard existing.isEmpty else {
                print("\(cleanedSymbol) is already being tracked.")
                return
            }
        } catch {
            print("Error checking for existing stock \(cleanedSymbol): \(error)")
            return
        }
        // --- End Duplicate Check ---

        // Insert new stock with 0 proportion. User needs to adjust sliders.
        let newStock = TrackedStock(symbol: cleanedSymbol, targetProportion: 0.0)
        modelContext.insert(newStock)
        print("Inserted \(cleanedSymbol) via ViewModel with 0% proportion.")
        // The @Query update in ContentView will trigger .task -> processTrackedStocks
    }

    /// Deletes a tracked stock and redistributes its proportion among remaining stocks.
    func deleteStock(stockToDelete: TrackedStock) {
        print("Deleting \(stockToDelete.symbol) via ViewModel")

        // Find the object in the current context/list
        guard let stockInContext = currentTrackedStocks.first(where: { $0.persistentModelID == stockToDelete.persistentModelID }) else {
            print("Could not find \(stockToDelete.symbol) in current context for deletion.")
            return
        }

        let deletedProportion = stockInContext.targetProportion
        modelContext.delete(stockInContext) // Delete from SwiftData

        // Redistribute the deleted proportion among remaining stocks
        let remainingStocks = currentTrackedStocks.filter { $0.persistentModelID != stockToDelete.persistentModelID }
        let totalRemainingProportion = remainingStocks.reduce(0.0) { $0 + $1.targetProportion }

        if totalRemainingProportion > 0.00001 && !remainingStocks.isEmpty { // Avoid division by zero
            // Add the deleted proportion back, scaled by each remaining stock's share
            for remainingStock in remainingStocks {
                 let increase = deletedProportion * (remainingStock.targetProportion / totalRemainingProportion)
                 remainingStock.targetProportion += increase
                 print("Increased \(remainingStock.symbol) proportion by \(increase * 100)%")
            }
            // Ensure total is exactly 1.0 after redistribution
            normalizeProportions(stocksToNormalize: remainingStocks)
        } else if !remainingStocks.isEmpty {
             // If remaining stocks all had 0%, distribute equally
             let equalShare = 1.0 / Double(remainingStocks.count)
             remainingStocks.forEach { $0.targetProportion = equalShare }
             print("Distributed proportion equally among remaining stocks.")
        }


        // Trigger UI update by recalculating display data
        Task { @MainActor in
            // We need to refetch trackedStocks to get the updated list *after* deletion
            // This is slightly awkward; ideally the @Query update handles this,
            // but we might need an immediate recalculation based on the modified remainingStocks.
            // For now, let the @Query update trigger the main processing.
            print("Deletion complete, waiting for @Query update to trigger processing.")
        }
    }


    /// Updates the target proportion for a specific stock and redistributes the difference
    /// among other stocks to maintain a total proportion of 1.0 (100%).
    func updateProportionAndRedistribute(trackedStock: TrackedStock, newProportionInput: Double) {
        // Clamp new proportion between 0.0 and 1.0
        let newProportion = max(0.0, min(1.0, newProportionInput))

        guard let stockInContext = currentTrackedStocks.first(where: { $0.persistentModelID == trackedStock.persistentModelID }) else {
            print("Cannot find stock \(trackedStock.symbol) to update proportion.")
            return
        }

        let oldProportion = stockInContext.targetProportion
        let deltaProportion = newProportion - oldProportion

        // If no change, do nothing
        if abs(deltaProportion) < 0.00001 { return }

        print("Updating \(trackedStock.symbol) proportion from \(oldProportion*100)% to \(newProportion*100)%. Delta: \(deltaProportion*100)%")

        // Update the target stock's proportion
        stockInContext.targetProportion = newProportion

        // Adjust other stocks proportionally
        let otherStocks = currentTrackedStocks.filter { $0.persistentModelID != trackedStock.persistentModelID }
        let totalOtherProportion = otherStocks.reduce(0.0) { $0 + $1.targetProportion }

        if !otherStocks.isEmpty {
            if totalOtherProportion > 0.00001 {
                // Distribute the negative delta among others based on their relative weight
                for otherStock in otherStocks {
                    let adjustment = -deltaProportion * (otherStock.targetProportion / totalOtherProportion)
                    otherStock.targetProportion += adjustment
                    // Clamp individual proportions just in case of floating point issues
                    otherStock.targetProportion = max(0.0, min(1.0, otherStock.targetProportion))
                }
            } else {
                // If all others were 0%, distribute the remaining proportion equally
                let remainingTotalProportion = 1.0 - newProportion
                let equalShare = remainingTotalProportion / Double(otherStocks.count)
                otherStocks.forEach { $0.targetProportion = max(0.0, min(1.0, equalShare)) }
            }
        }

        // Ensure the sum is exactly 1.0 after adjustments
        normalizeProportions(stocksToNormalize: currentTrackedStocks)

        // Recalculate display data immediately for responsiveness
        Task { @MainActor in
            await self.recalculateDisplayData()
        }
    }

    /// Ensures proportions sum exactly to 1.0, adjusting the largest proportion if needed.
    private func normalizeProportions(stocksToNormalize: [TrackedStock]) {
        let currentSum = stocksToNormalize.reduce(0.0) { $0 + $1.targetProportion }
        let difference = 1.0 - currentSum

        // If difference is negligible, do nothing
        if abs(difference) < 0.00001 { return }

        print("Normalizing proportions. Current sum: \(currentSum), Difference: \(difference)")

        // Find the stock with the largest proportion to adjust
        if let stockToAdjust = stocksToNormalize.max(by: { $0.targetProportion < $1.targetProportion }) {
            let adjustedProportion = stockToAdjust.targetProportion + difference
            // Clamp adjustment just in case
            stockToAdjust.targetProportion = max(0.0, min(1.0, adjustedProportion))
            print("Adjusted \(stockToAdjust.symbol) proportion to \(stockToAdjust.targetProportion * 100)% to normalize sum.")

            // Final check (optional, for debugging)
            let finalSum = stocksToNormalize.reduce(0.0) { $0 + $1.targetProportion }
            if abs(1.0 - finalSum) > 0.00001 {
                print("⚠️ Normalization failed. Final sum: \(finalSum)")
            }
        } else if !stocksToNormalize.isEmpty {
            // Fallback: if no max found (e.g., all zero), distribute equally
             let equalShare = 1.0 / Double(stocksToNormalize.count)
             stocksToNormalize.forEach { $0.targetProportion = equalShare }
        }
    }


    // MARK: - Data Processing & Fetching

    /// Processes the latest list of TrackedStock objects from the @Query.
    /// Fetches quotes and updates the displayStocks array and total values.
    @MainActor
    func processTrackedStocks(_ stocks: [TrackedStock]) async {
        guard !isLoading else { return }
        print("Processing \(stocks.count) tracked stocks.")
        isLoading = true
        self.currentTrackedStocks = stocks // Store the latest list from @Query

        // Ensure proportions sum to 1.0 before processing (might be needed after add/delete)
        normalizeProportions(stocksToNormalize: self.currentTrackedStocks)

        // Create display data based on current proportions and managed total
        var intermediateDisplayStocks = self.currentTrackedStocks.map {
            DisplayStock(trackedStock: $0, managedTotalValue: self.managedTotalValue)
        }

        // --- Fetch Quotes Concurrently (same TaskGroup logic as before) ---
        await withTaskGroup(of: (String, Result<StockQuote, Error>).self) { group in
            for stock in self.currentTrackedStocks { // Use the stored list
                group.addTask {
                    do {
                        let quote = try await self.financeService.fetchQuote(symbol: stock.symbol)
                        return (stock.symbol, .success(quote))
                    } catch {
                        print("Error fetching \(stock.symbol): \(error)")
                        return (stock.symbol, .failure(error))
                    }
                }
            }

            // Process results and update intermediate array
            for await (symbol, result) in group {
                if let index = intermediateDisplayStocks.firstIndex(where: { $0.symbol == symbol }) {
                    switch result {
                    case .success(let quote):
                        intermediateDisplayStocks[index].quote = quote
                        intermediateDisplayStocks[index].fetchError = false
                        // Recalculate implied quantity and current value with the fetched price
                        if let price = quote.price, price > 0 {
                            let priceAsDouble = Double(price)
                            // Use managedValue calculated earlier based on proportion
                            let managedValue = intermediateDisplayStocks[index].managedValue ?? 0
                            intermediateDisplayStocks[index].impliedQuantity = managedValue / priceAsDouble
                            intermediateDisplayStocks[index].currentValue = (intermediateDisplayStocks[index].impliedQuantity ?? 0) * priceAsDouble
                        } else {
                            intermediateDisplayStocks[index].impliedQuantity = nil
                            intermediateDisplayStocks[index].currentValue = nil
                        }
                    case .failure:
                        intermediateDisplayStocks[index].quote = nil
                        intermediateDisplayStocks[index].fetchError = true
                        intermediateDisplayStocks[index].impliedQuantity = nil
                        intermediateDisplayStocks[index].currentValue = nil
                    }
                }
            }
        } // TaskGroup finishes
        // --- End Fetch Quotes ---

        // Update the main @Observable properties
        self.displayStocks = intermediateDisplayStocks
        recalculateActualTotalValue() // Calculate total based on latest current values

        isLoading = false
        print("Finished processing stocks. Actual Total Value: \(actualTotalValue)")
    }

    /// Recalculates the *actual* total portfolio value based on current prices and implied quantities.
    @MainActor
    private func recalculateActualTotalValue() {
        actualTotalValue = displayStocks.reduce(0.0) { sum, stock in
            sum + (stock.currentValue ?? 0.0) // Add current value, defaulting to 0 if nil
        }
        print("Recalculated Actual Total Value: \(actualTotalValue)")
    }

    /// Recalculates managed values, implied quantities, and current values for all displayStocks.
    /// Called after `managedTotalValue` changes or a proportion update.
    @MainActor
    private func recalculateDisplayData() async {
         print("Recalculating display data based on new managed total or proportions...")
         var needsTotalRecalc = false
         for index in displayStocks.indices {
             // Find corresponding TrackedStock to get latest proportion
             guard let trackedStock = currentTrackedStocks.first(where: { $0.symbol == displayStocks[index].symbol }) else { continue }
             let currentProportion = trackedStock.targetProportion // Use proportion from persisted object

             // Update proportion in display object if it differs
             if abs(displayStocks[index].targetProportion - currentProportion) > 0.00001 {
                 displayStocks[index].targetProportion = currentProportion
                 needsTotalRecalc = true
             }

             // Calculate new managed value based on current managedTotalValue
             let newManagedValue = managedTotalValue * currentProportion
             if displayStocks[index].managedValue != newManagedValue {
                 displayStocks[index].managedValue = newManagedValue
                 needsTotalRecalc = true
             }

             // Recalculate implied quantity and current value if price exists
             if let price = displayStocks[index].quote?.price, price > 0 {
                 let priceAsDouble = Double(price)
                 let newImpliedQuantity = newManagedValue / priceAsDouble
                 let newCurrentValue = newImpliedQuantity * priceAsDouble

                 if displayStocks[index].impliedQuantity != newImpliedQuantity {
                      displayStocks[index].impliedQuantity = newImpliedQuantity
                      needsTotalRecalc = true
                 }
                 if displayStocks[index].currentValue != newCurrentValue {
                      displayStocks[index].currentValue = newCurrentValue
                      needsTotalRecalc = true
                 }

             } else {
                 // Ensure calculated values are nil if price is missing
                 if displayStocks[index].impliedQuantity != nil { displayStocks[index].impliedQuantity = nil; needsTotalRecalc = true }
                 if displayStocks[index].currentValue != nil { displayStocks[index].currentValue = nil; needsTotalRecalc = true }
             }
         }
         if needsTotalRecalc {
              recalculateActualTotalValue() // Update total if any individual values changed
         }
    }
}
