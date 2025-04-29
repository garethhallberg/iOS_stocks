//
//  StockRow.swift
//  StockTracker
//
//  Created by gareth15 on 28/04/2025.
//

import Foundation
import SwiftUI

// Extracted Row View for better organization
struct StockRow: View {
    let stock: DisplayStock
    let isLoading: Bool // Pass loading state to avoid redundant text

    var body: some View {
         HStack {
              VStack(alignment: .leading) {
                  Text(stock.symbol).font(.headline)
                  Text(stock.quote?.shortName ?? (isLoading ? "Loading..." : (stock.fetchError ? "Failed" : "N/A")))
                      .font(.caption)
                      .foregroundColor(.gray)
                      .lineLimit(1)
              }
              Spacer()
              if stock.fetchError {
                   Image(systemName: "exclamationmark.triangle.fill")
                       .foregroundColor(.orange)
              } else if let quote = stock.quote {
                   VStack(alignment: .trailing) {
                       Text(priceString(quote.price))
                           .font(.headline)
                       Text(changeString(quote.change, percent: quote.changePercent))
                           .font(.subheadline)
                           .foregroundColor(changeColor(quote.change))
                   }
              } else if !isLoading {
                    ProgressView().scaleEffect(0.8) // Show small spinner if quote is nil but not loading globally/failed
              }
         }
    }

    // Helper functions (can be static or moved to an extension)
    private func priceString(_ price: Float?) -> String {
         guard let price = price else { return "--" }
         return String(format: "%.2f", price)
    }

    private func changeString(_ change: Float?, percent: Float?) -> String {
         guard let change = change, let percent = percent else { return "--" }
         return String(format: "%@%.2f (%.2f%%)", change >= 0 ? "+" : "", change, percent)
    }

    private func changeColor(_ change: Float?) -> Color {
         guard let change = change else { return .gray }
         if change > 0 { return .green }
         if change < 0 { return .red }
         return .gray
    }
}
