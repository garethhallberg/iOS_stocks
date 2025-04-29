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
