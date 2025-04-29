//
//  ContentView.swift
//  StockTracker
//
//  Created by gareth15 on 28/04/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrackedStock.symbol) private var trackedStocks: [TrackedStock]

    // Use @StateObject if targeting older than iOS 17 or if preferred
    // @State is fine for @Observable classes in iOS 17+
    @State private var viewModel: StockListViewModel
    @State private var newSymbol: String = ""

    // Custom init to ensure ViewModel gets the context when the View is created
    // Note: This approach works but can sometimes have nuances with environment timing.
    // A common alternative is initializing in .onAppear or using a wrapper class.
    // However, let's try direct init first.
     init() {
         // We need access to the modelContext available in the Environment *during* init.
         // This is tricky. A better pattern might be needed if this fails.
         // Let's *assume* for now we can create it later or pass context differently.
         // We will initialize it properly within the body's .task modifier instead.
         // Create a temporary instance first.
         // THIS IS A PLACEHOLDER - see .task modifier below for proper init
         _viewModel = State(initialValue: StockListViewModel(modelContext: try! ModelContainer(for: TrackedStock.self).mainContext)) // TEMPORARY - DO NOT SHIP
     }


    var body: some View {
        NavigationView {
            VStack {
                // Input Section
                HStack {
                    TextField("Add Symbol (e.g., AAPL)", text: $newSymbol)
                        .textInputAutocapitalization(.characters)
                        .disableAutocorrection(true)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit(addStock)

                    Button("Add", action: addStock)
                        .disabled(newSymbol.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding([.horizontal, .top])

                // Stock List Section
                List {
                    ForEach(viewModel.displayStocks) { stock in
                        StockRow(stock: stock, isLoading: viewModel.isLoading)
                    }
                    // Use the @Query result (`trackedStocks`) to find the object to delete
                    .onDelete(perform: deleteItems)
                }
                .listStyle(.plain)
                .overlay { /* ... loading indicator ... */ } // (Same as before)
                .refreshable { await refreshData() }
                .navigationTitle("My Stocks")
                .toolbar { EditButton() } // EditButton often works well with .onDelete
            }
            // This task modifier correctly initializes/updates the VM when the context or trackedStocks are ready/changed.
            .task(id: trackedStocks) {
                // Check if the viewModel's context is different from the environment's
                // This ensures we initialize properly when the view appears and context is available
                 // Or simply re-initialize every time trackedStocks changes? Let's try that.
                 let currentContext = modelContext // Capture environment context
                 // Recreate the VM with the current context and fetch data
                 viewModel = StockListViewModel(modelContext: currentContext) // Uses default real FinanceService
                 await viewModel.fetchQuotes(for: trackedStocks)

            }
        }
    }

    // View function to add stock - DELEGATES to ViewModel
    private func addStock() {
        viewModel.addStock(symbol: newSymbol) // Call ViewModel's method
        newSymbol = "" // Clear field
    }

    // View function to delete - DELEGATES to ViewModel
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { trackedStocks[$0] }.forEach { stock in
                viewModel.deleteStock(stock: stock) // Call ViewModel's method
            }
        }
    }

    // Function to manually refresh data
    private func refreshData() async {
         await viewModel.fetchQuotes(for: trackedStocks)
    }
}
