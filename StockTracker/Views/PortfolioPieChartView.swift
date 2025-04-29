import SwiftUI
import Charts // Import the Swift Charts framework

/// A view that displays a pie chart representing the portfolio allocation
/// based on the managed value of each stock.
struct PortfolioPieChartView: View {
    /// The array of stock data prepared for display.
    let displayStocks: [DisplayStock]
    /// The total managed value, used for calculating percentages accurately if needed.
    let totalManagedValue: Double

    // Filtered data suitable for the chart (non-zero managed value)
    private var chartData: [DisplayStock] {
        displayStocks.filter { ($0.managedValue ?? 0.0) > 0.0001 } // Filter out zero/negligible values
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Allocation by Managed Value")
                .font(.headline)
                .padding(.leading) // Add padding to align with chart

            // Use GeometryReader to make the chart adapt to available space
            GeometryReader { geometry in
                Chart(chartData) { stock in
                    // Create a SectorMark for the pie chart.
                    // Angle is proportional to the stock's managed value.
                    // Inner radius creates a donut chart effect.
                    SectorMark(
                        angle: .value("Value", stock.managedValue ?? 0.0),
                        innerRadius: .ratio(0.55), // Adjust for donut thickness
                        angularInset: 1.5 // Small gap between sectors
                    )
                    // Style the sector with rounded corners.
                    .cornerRadius(5)
                    // Assign a unique color based on the stock symbol.
                    .foregroundStyle(by: .value("Symbol", stock.symbol))
                    // Add tooltips (popovers) to show details on hover/tap.
                    .annotation(position: .overlay) {
                         // Optionally add percentage labels directly on slices if space allows
                         // For complex labels, tooltips are often better
                    }
                     .accessibilityLabel("\(stock.symbol): \(stock.managedValue ?? 0, format: .currency(code: "USD"))") // Basic accessibility label
                }
                // Apply common chart styling
                .chartLegend(position: .bottom, alignment: .center, spacing: 10) // Position the legend
                .chartForegroundStyleScale(range: chartColorPalette()) // Use a defined color palette
                // Add tooltips that appear on interaction
                .chartOverlay { proxy in
                     GeometryReader { innerGeometry in
                          Rectangle().fill(.clear).contentShape(Rectangle())
                               .gesture(
                                    DragGesture(minimumDistance: 0)
                                         .onChanged { value in
                                              // Find plot item at the touch/drag location
                                              let origin = innerGeometry[proxy.plotAreaFrame].origin
                                              let location = CGPoint(
                                                  x: value.location.x - origin.x,
                                                  y: value.location.y - origin.y
                                              )
                                              // Get the sector mark tapped
                                              if let (symbol, _) = proxy.value(at: location, as: (String, Double).self) {
                                                   // TODO: Implement logic to show a custom popover/tooltip
                                                   // For now, just print
                                                   print("Tapped/Hovered on: \(symbol)")
                                              }
                                         }
                               )
                     }
                }
                // Limit chart height or let GeometryReader control it
                .frame(height: max(200, geometry.size.width * 0.6)) // Example dynamic height
            }
             // Add padding around the chart itself
             .padding()
        }
        // Add padding around the entire VStack containing the title and chart
        .padding(.vertical)
        // Show a message if there's no data to display
        .overlay {
             if chartData.isEmpty {
                  Text("Add stocks and set allocations to see the chart.")
                       .font(.caption)
                       .foregroundStyle(.secondary)
             }
        }
    }

    /// Generates a consistent color palette for the chart.
    /// Uses a predefined set of colors and cycles through them.
    private func chartColorPalette() -> [Color] {
        // Define a palette of distinct colors
        // Consider using Color assets for better management
        return [
            .blue, .green, .red, .orange, .purple, .yellow, .cyan, .mint, .indigo, .teal
        ]
    }
}

// MARK: - Preview
#Preview {
    // Create sample data for the preview
    let sampleStocks = [
        DisplayStock(trackedStock: TrackedStock(symbol: "AAPL", targetProportion: 0.40), managedTotalValue: 1000.0, quote: StockQuote(symbol: "AAPL", shortName: "Apple", price: 175, change: 1, changePercent: 0.5)),
        DisplayStock(trackedStock: TrackedStock(symbol: "GOOG", targetProportion: 0.30), managedTotalValue: 1000.0, quote: StockQuote(symbol: "GOOG", shortName: "Alphabet", price: 2800, change: 10, changePercent: 0.3)),
        DisplayStock(trackedStock: TrackedStock(symbol: "MSFT", targetProportion: 0.20), managedTotalValue: 1000.0, quote: StockQuote(symbol: "MSFT", shortName: "Microsoft", price: 300, change: -2, changePercent: -0.6)),
         DisplayStock(trackedStock: TrackedStock(symbol: "TSLA", targetProportion: 0.10), managedTotalValue: 1000.0, quote: StockQuote(symbol: "TSLA", shortName: "Tesla", price: 900, change: 20, changePercent: 2.1))
    ]

    return PortfolioPieChartView(displayStocks: sampleStocks, totalManagedValue: 1000.0)
        .padding() // Add padding for preview canvas
}
