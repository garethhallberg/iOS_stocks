//
//  StockTrackerApp.swift
//  StockTracker
//
//  Created by gareth15 on 28/04/2025.
//

import SwiftUI
import SwiftData

@main
struct StockTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: TrackedStock.self) // Automatically sets up SwiftData for TrackedStock
    }
}
