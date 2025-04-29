import SwiftUI


/// A view representing a single row in the stock list.
/// Displays symbol, name, target proportion (with slider), managed value, and current value.
struct StockRow: View {
    /// The display data for the stock.
    let stock: DisplayStock
    /// Indicates if a global data fetch operation is in progress.
    let isLoading: Bool
    /// Closure to call when the target proportion slider *finishes* changing.
    let onProportionChange: (Double) -> Void // Renamed for clarity

    // Local state bound to the Slider. Using Double for proportion (0.0 to 1.0).
    @State private var internalProportion: Double

    // Formatter for displaying percentages
    private let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    // Formatter for displaying currency
    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2 // Show cents for values
        formatter.minimumFractionDigits = 2
        return formatter
    }()

    /// Initialize the StockRow, syncing the internal state with the initial proportion.
    init(stock: DisplayStock, isLoading: Bool, onProportionChange: @escaping (Double) -> Void) {
        self.stock = stock
        self.isLoading = isLoading
        self.onProportionChange = onProportionChange
        // Initialize the @State variable with the proportion value passed in.
        _internalProportion = State(initialValue: stock.targetProportion)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // MARK: Top Section (Symbol, Name, Status)
            HStack {
                Text(stock.symbol)
                    .font(.headline)
                    .frame(minWidth: 60, alignment: .leading)

                Text(stock.quote?.shortName ?? loadingOrErrorText)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                // Status Indicator (Loading/Error) - Placed top right
                if stock.fetchError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .help("Failed to fetch quote")
                } else if isLoading && stock.quote == nil {
                    ProgressView().scaleEffect(0.7)
                }
            }

            // MARK: Proportion Slider Section
            HStack {
                 Text("Allocation:") // Changed label
                     .font(.caption)
                     .foregroundStyle(.secondary)
                 Slider(
                     value: $internalProportion,
                     in: 0...1.0, // Slider range is 0% to 100%
                     step: 0.01 // 1% steps
                 ) {
                     Text("Target Allocation Slider") // Accessibility
                 } minimumValueLabel: {
                     Text("0%")
                         .font(.caption2)
                         .foregroundStyle(.secondary)
                 } maximumValueLabel: {
                     Text("100%")
                         .font(.caption2)
                         .foregroundStyle(.secondary)
                 } onEditingChanged: { isEditing in
                     // When the user finishes dragging the slider (isEditing becomes false)
                     if !isEditing {
                         // Call the closure to notify the ViewModel of the final change
                         onProportionChange(internalProportion)
                     }
                 }
                 // Display the current slider value as a percentage
                 Text(percentFormatter.string(from: NSNumber(value: internalProportion)) ?? "")
                     .font(.caption.monospacedDigit())
                     .frame(minWidth: 50, alignment: .trailing)
            }


            // MARK: Value Section (Managed vs Current)
            HStack {
                VStack(alignment: .leading) {
                    Text("Managed Value") // Renamed from Target
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(currencyString(stock.managedValue))
                        .font(.caption.monospacedDigit())
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Current Value") // Renamed from Actual
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(currencyString(stock.currentValue))
                        .font(.caption.monospacedDigit().weight(.medium))
                         .foregroundColor(stock.currentValue == nil ? .gray : .primary)
                }
            }
        }
        .padding(.vertical, 6)
        // Update internal proportion if the external stock proportion changes
        // (e.g., due to normalization after another slider moved, or after deletion)
        .onChange(of: stock.targetProportion) { _, newValue in
             if abs(internalProportion - newValue) > 0.00001 { // Use tolerance
                  print("Updating internal proportion for \(stock.symbol) from \(internalProportion) to \(newValue) due to external change.")
                  internalProportion = newValue
             }
        }
    }

    // MARK: - Helper Functions

    /// Determines status text when quote name is unavailable.
    private var loadingOrErrorText: String {
        if isLoading && stock.quote == nil && !stock.fetchError {
            return "Loading..."
        } else if stock.fetchError {
            return "Error"
        } else {
            return "N/A"
        }
    }

    /// Formats an optional Double as a currency string.
    private func currencyString(_ value: Double?) -> String {
        guard let value = value else { return "--" }
        return currencyFormatter.string(from: NSNumber(value: value)) ?? "--"
    }
}
