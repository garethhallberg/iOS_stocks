//
//  StockListViewModel.swift
//  StockTracker
//
//  Created by gareth15 on 28/04/2025.
//

import SwiftUI
import SwiftData // Needed for FetchDescriptor if checking duplicates

// Struct for displaying combined data in the view
struct DisplayStock: Identifiable {
    let id = UUID()
    let symbol: String // The persisted symbol
    var quote: StockQuote? // Live data fetched from API
    var fetchError: Bool = false // Flag if fetching failed for this stock
}

import SwiftUI
import SwiftData
import Combine // Needed if using older @ObservedObject pattern, less so with @Observable

@Observable // Use modern @Observable
class StockListViewModel {
    var displayStocks: [DisplayStock] = []
    var isLoading: Bool = false

    // Hold dependencies (injected)
    private let financeService: FinanceServiceProtocol
    private let modelContext: ModelContext // Context for persistence operations

    // Initializer accepting both dependencies
    init(modelContext: ModelContext, financeService: FinanceServiceProtocol = YahooFinanceService()) {
        self.modelContext = modelContext
        self.financeService = financeService
        print("StockListViewModel initialized WITH context and \(type(of: financeService))")
    }

    // --- Persistence Methods ---

    func addStock(symbol: String) {
        let cleanedSymbol = symbol.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedSymbol.isEmpty else {
            print("Symbol cannot be empty")
            // Consider adding user-facing error handling (e.g., published error property)
            return
        }

        // Check for duplicates using the injected context
        let predicate = #Predicate<TrackedStock> { $0.symbol == cleanedSymbol }
        var fetchDescriptor = FetchDescriptor(predicate: predicate)
        fetchDescriptor.fetchLimit = 1 // Only need to know if one exists

        do {
            let existing = try modelContext.fetch(fetchDescriptor)
            guard existing.isEmpty else {
                print("\(cleanedSymbol) already added.")
                // Add user-facing feedback?
                return // Already exists
            }
        } catch {
            print("Failed to check for existing stock: \(error)")
            // Decide how to handle - maybe prevent adding?
            return
        }

        // Create and insert new stock using the injected context
        let newStock = TrackedStock(symbol: cleanedSymbol)
        modelContext.insert(newStock)
        print("Inserted \(cleanedSymbol) via ViewModel")
        // SwiftData auto-saves frequently, but manual save after direct action is also okay
        // try? modelContext.save()
    }

    func deleteStock(stock: TrackedStock) {
        // Ensure the object is valid within the context if needed (usually okay if passed from @Query result)
        print("Deleting \(stock.symbol) via ViewModel")
        modelContext.delete(stock)
        // try? modelContext.save()
    }

    // --- Data Fetching Method ---

    @MainActor
    func fetchQuotes(for trackedStocks: [TrackedStock]) async {
        // (Implementation remains the same as before - uses self.financeService)
        guard !isLoading else { return }
        print("Starting quote fetch for \(trackedStocks.count) symbols.")
        isLoading = true
        self.displayStocks = trackedStocks.map { DisplayStock(symbol: $0.symbol) }

        await withTaskGroup(of: (String, Result<StockQuote, Error>).self) { group in
            for stock in trackedStocks {
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
            for await (symbol, result) in group {
                 if let index = self.displayStocks.firstIndex(where: { $0.symbol == symbol }) {
                     switch result {
                     case .success(let quote):
                         self.displayStocks[index].quote = quote
                         self.displayStocks[index].fetchError = false
                     case .failure:
                         self.displayStocks[index].quote = nil
                         self.displayStocks[index].fetchError = true
                     }
                 }
            }
        }
        isLoading = false
        print("Finished quote fetch.")
    }
}
