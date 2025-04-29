import SwiftUI
import SwiftData
import Charts // Import Charts framework here as well

/// The main view of the application, displaying the list of tracked stocks and controls for adding/deleting.
struct ContentView: View {
    /// Access the SwiftData model context from the environment.
    @Environment(\.modelContext) private var modelContext

    /// Automatically fetches and observes all `TrackedStock` entities from SwiftData, sorted by symbol.
    @Query(sort: \TrackedStock.symbol) private var trackedStocks: [TrackedStock]

    /// The ViewModel instance, responsible for fetching live data and handling persistence logic.
    @State private var viewModel: StockListViewModel

    /// State variable bound to the text field for adding new symbols.
    @State private var newSymbol: String = ""

    /// State variable for the target total value input. Using String for TextField binding.
    @State private var managedTotalValueString: String = "1000" // Default value as string

    /// State variable to track edit mode for swipe-to-delete alternative
    @State private var editMode: EditMode = .inactive


    /// Formatter for currency input/display
    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0 // No decimals for managed total
        formatter.minimumFractionDigits = 0
        // Set locale if needed, e.g., formatter.locale = Locale(identifier: "en_GB") for £
        // formatter.locale = Locale(identifier: "en_GB")
        // formatter.currencySymbol = "£" // Force symbol if needed
        return formatter
    }()

    /// Initializes the ContentView.
    init() {
        let placeholderContext: ModelContext
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: TrackedStock.self, configurations: config)
            placeholderContext = container.mainContext
        } catch {
            fatalError("Failed to create placeholder model context: \(error)")
        }
        let initialViewModel = StockListViewModel(modelContext: placeholderContext)
        _viewModel = State(initialValue: initialViewModel)
        // Initialize the string state based on the ViewModel's initial Double value
        _managedTotalValueString = State(initialValue: currencyFormatter.string(from: NSNumber(value: initialViewModel.managedTotalValue)) ?? "\(initialViewModel.managedTotalValue)")
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            // Use ScrollView to allow content (especially chart) to scroll if needed
            ScrollView {
                VStack(spacing: 0) { // Use spacing 0 for tighter control with Dividers
                    // Header Section
                    PortfolioHeaderViewPro(
                        targetValueString: $managedTotalValueString,
                        actualValue: viewModel.actualTotalValue,
                        formatter: currencyFormatter
                    ) { newValue in
                        viewModel.managedTotalValue = newValue
                    }
                    .padding(.bottom, 5)

                    Divider()

                    // --- Portfolio Chart Section ---
                    PortfolioPieChartView(
                        displayStocks: viewModel.displayStocks,
                        totalManagedValue: viewModel.managedTotalValue
                    )
                    .padding(.vertical) // Add some vertical spacing around the chart

                    Divider()
                    // --- End Chart Section ---


                    // Input Section
                    addStockInputSection
                        .padding(.top, 210) // Adjust value as needed
                        .padding([.horizontal, .top])
                        .padding(.bottom, 8) // Keep padding consistent

                    Divider().padding(.horizontal) // Add divider before list items

                    // Stock List Section (Extracted - Now uses VStack + ForEach)
                    stockListSection

                } // End main VStack
            } // End ScrollView
            // Modifiers applied to the ScrollView's content (VStack)
            .task(id: trackedStocks) { // Re-run when trackedStocks changes
                if viewModel.modelContext !== modelContext {
                     print("Re-initializing ViewModel with Environment ModelContext.")
                     let currentManagedValue = viewModel.managedTotalValue // Preserve user-set value
                     viewModel = StockListViewModel(modelContext: modelContext)
                     viewModel.managedTotalValue = currentManagedValue // Restore value
                     // Update string representation after re-init
                     managedTotalValueString = currencyFormatter.string(from: NSNumber(value: currentManagedValue)) ?? "\(currentManagedValue)"
                }
                 // Process stocks whenever the list changes or on initial appear.
                 await viewModel.processTrackedStocks(trackedStocks)
            }
            .onChange(of: viewModel.managedTotalValue) { _, newValue in // Update string when Double changes
                 let formattedString = currencyFormatter.string(from: NSNumber(value: newValue)) ?? "\(newValue)"
                 if managedTotalValueString != formattedString {
                      managedTotalValueString = formattedString
                 }
            }
            .navigationTitle("Portfolio Allocation")
            .toolbar {
                 // Use standard EditButton to toggle edit mode
                 EditButton()
            }
            // Apply editMode environment variable
            .environment(\.editMode, $editMode)
        }
        // Dismiss keyboard gesture attached to NavigationView
        .gesture(DragGesture().onChanged({_ in hideKeyboard()}))
    }

    // MARK: - Subviews / Computed Properties

    /// Computed property for the Add Stock input section.
    private var addStockInputSection: some View {
        HStack {
            TextField("Add Symbol (e.g., AAPL)", text: $newSymbol)
                .textInputAutocapitalization(.characters)
                .disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit(addStock) // Add on return key

            Button("Add", action: addStock)
                .disabled(newSymbol.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    /// Computed property for the main List section displaying summaries and holdings.
    /// Uses VStack + ForEach instead of List to avoid nested scrolling issues.
    private var stockListSection: some View {
        VStack(spacing: 0) { // Use VStack with 0 spacing
            // Summary Section (Optional: Could be moved outside ScrollView if fixed)
            summarySection
                .padding([.horizontal, .top]) // Add padding to summary content
                .padding(.bottom, 8)

            Divider().padding(.horizontal)

            // Holdings Section
            if viewModel.displayStocks.isEmpty && !viewModel.isLoading {
                 Text("Add stocks to get started.")
                      .foregroundStyle(.secondary)
                      .padding()
            } else {
                 // Iterate directly over displayStocks
                 ForEach(viewModel.displayStocks) { displayStock in
                      HStack { // Add HStack for delete button when editing
                           // Find corresponding TrackedStock for updates/deletes
                           if let trackedStock = trackedStocks.first(where: { $0.symbol == displayStock.symbol }) {
                                StockRow(
                                     stock: displayStock,
                                     isLoading: viewModel.isLoading,
                                     onProportionChange: { newProportion in
                                          viewModel.updateProportionAndRedistribute(trackedStock: trackedStock, newProportionInput: newProportion)
                                     }
                                )

                                // Show delete button only when in edit mode
                                if editMode.isEditing {
                                     Spacer() // Push button to the right
                                     Button {
                                          deleteStock(stockToDelete: trackedStock)
                                     } label: {
                                          Image(systemName: "minus.circle.fill")
                                               .foregroundStyle(.red)
                                     }
                                     .padding(.leading, 5) // Add space before button
                                }
                           } else {
                                Text("Error: Missing tracked stock for \(displayStock.symbol)")
                                     .foregroundColor(.red).font(.caption)
                           }
                      }
                      .padding(.horizontal) // Add horizontal padding to row content + button

                      // Add divider between rows
                      if displayStock.id != viewModel.displayStocks.last?.id {
                           Divider().padding(.leading) // Indent divider slightly
                      }
                 }
            }

            // Loading indicator at the bottom if loading
            if viewModel.isLoading {
                 ProgressView().padding()
            }
        }
        // Apply refreshable TO THE SCROLLVIEW instead of the List
        // Note: Refreshable on ScrollView might need adjustment depending on content size
        // .refreshable { await refreshData() } // Attach to ScrollView if needed
    }

    /// Computed property for the Summary section content.
    private var summarySection: some View {
        HStack {
             Text("Total Allocation:")
             Spacer()
             let totalProportion = trackedStocks.reduce(0.0) { $0 + $1.targetProportion }
             Text(totalProportion, format: .percent.precision(.fractionLength(1)))
                  .foregroundColor(abs(totalProportion - 1.0) < 0.001 ? .green : .orange) // Highlight if not 100%
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }


    // MARK: - View Actions
    private func addStock() {
        viewModel.addStock(symbol: newSymbol)
        newSymbol = ""
        hideKeyboard()
    }

    // Modified delete function to take the specific stock
    private func deleteStock(stockToDelete: TrackedStock) {
         withAnimation {
              viewModel.deleteStock(stockToDelete: stockToDelete)
         }
    }

    // Delete items using offsets (if keeping List's onDelete) - Not used with VStack approach
    /*
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            let objectsToDelete = offsets.map { trackedStocks[$0] }
            objectsToDelete.forEach { stock in
                viewModel.deleteStock(stockToDelete: stock)
            }
        }
    }
    */

    private func refreshData() async {
         // Use processTrackedStocks as it handles fetching and calculations
         await viewModel.processTrackedStocks(trackedStocks)
    }

    private func hideKeyboard() {
         UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Header view including the editable Managed Total Value.
struct PortfolioHeaderViewPro: View {
    @Binding var targetValueString: String // Changed name for clarity
    let actualValue: Double
    let formatter: NumberFormatter
    let onCommit: (Double) -> Void // Closure to call when editing finishes

    @FocusState private var isTargetFocused: Bool

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading) {
                Text("Managed Total Value") // Updated Label
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Managed Value", text: $targetValueString) // Updated Placeholder
                    .font(.largeTitle.weight(.semibold))
                    .keyboardType(.decimalPad)
                    .focused($isTargetFocused)
                    .onSubmit { commitManagedValue() } // Commit on return
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                isTargetFocused = false // Dismiss keyboard
                                commitManagedValue() // Commit value
                            }
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("Actual Market Value") // Updated Label
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(actualValue, format: .currency(code: formatter.locale?.currency?.identifier ?? "USD"))
                    .font(.title2.weight(.medium))
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 5)
    }

    /// Cleans the input string and updates the ViewModel's Double value.
    private func commitManagedValue() {
        // Remove currency symbols, grouping separators etc. Allow decimal point.
        let cleanedString = targetValueString.filter("0123456789.".contains)
        let newValue = Double(cleanedString) ?? 0.0 // Default to 0
        // Update the string binding to the formatted version (no decimals)
        formatter.maximumFractionDigits = 0 // Ensure formatter has 0 decimals for display
        targetValueString = formatter.string(from: NSNumber(value: newValue)) ?? "\(Int(newValue))"
        // Call the closure to update the ViewModel's Double property
        onCommit(max(0, newValue)) // Ensure non-negative value is committed
    }
}


// MARK: - Preview
#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container) // Use existing preview data setup
}

// PreviewSampleData struct remains the same
@MainActor
struct PreviewSampleData {
    static let container: ModelContainer = {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: TrackedStock.self, configurations: config)

            let sampleStocks = [
                TrackedStock(symbol: "AAPL", targetProportion: 0.4),
                TrackedStock(symbol: "GOOG", targetProportion: 0.3),
                TrackedStock(symbol: "MSFT", targetProportion: 0.3)
            ]
            var currentSum: Double = 0
            for stock in sampleStocks {
                 if currentSum + stock.targetProportion <= 1.0 || sampleStocks.last === stock {
                      container.mainContext.insert(stock)
                      currentSum += stock.targetProportion
                 } else {
                      let adjustedStock = TrackedStock(symbol: stock.symbol, targetProportion: max(0, 1.0 - currentSum))
                      container.mainContext.insert(adjustedStock)
                      break
                 }
            }
            return container
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }()
}
