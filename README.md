# iOS Stock Portfolio Tracker & Allocator

## Description

This is an iOS application built with SwiftUI and SwiftData to track stock investments and manage portfolio allocation based on a user-defined total value. It fetches near real-time stock quote data (currently using an unofficial Yahoo Finance wrapper) and allows users to visually track their portfolio composition with a pie chart.

The architecture is designed with testability and future expansion in mind, featuring a protocol-based service layer to easily swap data sources (e.g., replacing the current Yahoo Finance implementation with a custom backend API).

## Features

* **Add/Delete Stocks:** Track desired stock symbols.
* **Managed Total Value:** Define a fixed total value for the portfolio (e.g., £1000).
* **Proportional Allocation:** Allocate percentages of the managed total value to each tracked stock using sliders.
* **Automatic Redistribution:** Changing one stock's allocation automatically adjusts others to maintain a 100% total allocation.
* **Live Data Fetching:** Retrieves current stock prices and calculates current market values.
* **Value Calculation:** Displays Managed Value (based on allocation) and Current Market Value (based on live price) for each holding.
* **Total Value Display:** Shows both the user-defined Managed Total Value and the calculated Actual Market Value.
* **Pie Chart Visualization:** Displays portfolio allocation based on managed value using Swift Charts.
* **Persistence:** Uses SwiftData to store the tracked stocks and their target allocations.
* **Testable Architecture:** Employs MVVM-like structure with dependency injection and protocol-based services for unit testing.

## Technology Stack

* **Platform:** iOS 17.0+
* **Language:** Swift
* **UI Framework:** SwiftUI
* **Data Persistence:** SwiftData
* **Charts:** Swift Charts
* **Data Fetching (Current):** `SwiftYFinance` library (via `YahooFinanceService`)
* **Architecture:** MVVM-like, Protocol-Oriented Service Layer
* **IDE:** Xcode 16+

## Project Structure

```bash
    StockTracker/                  # Main App Target Folder
│
├── StockTrackerApp.swift      # App entry point & SwiftData setup
├── Assets.xcassets          # App icons, images
├── Preview Content          # Assets for Xcode Previews
│
├── Models/                  # Data structures group
│   ├── TrackedStock.swift   # SwiftData @Model class (Symbol, TargetProportion)
│   └── StockQuote.swift     # Struct for fetched quote data
│
├── Views/                   # SwiftUI Views group
│   ├── ContentView.swift    # Main container view
│   ├── StockRow.swift       # View for a single stock row + slider
│   ├── PortfolioPieChartView.swift # Pie chart view
│   └── PortfolioHeaderViewPro.swift # Header with value display/input
│
├── ViewModels/              # Observable classes group
│   └── StockListViewModel.swift # Handles data fetching, calculations, persistence actions
│
└── Services/                # External interaction group
    ├── FinanceServiceProtocol.swift # Defines data fetching contract
    └── YahooFinanceService.swift    # Current implementation using SwiftYFinance

StockTrackerTests/             # Unit Test Target Folder
│
├── StockListViewModelTests.swift # Tests for the ViewModel
│
└── Mocks/                   # Mock implementations group
    └── MockFinanceService.swift # Mock Finance Service
```
## Setup

1.  **Clone the repository:**
    ```bash
    git clone <your-repository-url>
    cd <repository-directory>
    ```
2.  **Open in Xcode:** Open the `.xcodeproj` file in Xcode 16 or later.
3.  **Fetch Packages:** Xcode should automatically resolve and fetch the Swift Package dependencies (SwiftYFinance). If not, go to File > Packages > Resolve Package Versions.
4.  **Build & Run:** Select a simulator or a physical device running iOS 17.0+ and run the app (Cmd+R).

## Future Enhancements

* **Backend API Integration:** Replace `YahooFinanceService` with `BackendAPIService` to fetch data from a custom cloud API.
* **LLM Analysis:** Integrate with a backend service that uses an LLM to provide daily reports or insights based on portfolio data.
* **User Authentication:** Secure user data.
* **Cloud Sync:** Sync portfolio data across user devices (potentially via CloudKit integration with SwiftData).
* **Improved Error Handling:** Display user-friendly alerts for API errors or data issues.
* **Historical Data & Charts:** Add line charts to visualize stock price history.
* **More Robust Allocation:** Add warnings or constraints if total allocation doesn't equal 100%.

