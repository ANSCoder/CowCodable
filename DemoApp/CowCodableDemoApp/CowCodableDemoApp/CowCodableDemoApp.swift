/// File: CowCodableDemoApp.swift
///
/// Demo application source for the CowCodable SDK showcase.

import SwiftUI

/// CowCodable demo application entry point.
///
/// Purpose: bootstraps the production-style iOS SwiftUI demo client.
/// Design philosophy: keep startup minimal and route all behavior through feature modules.
/// Thread safety: SwiftUI scene lifecycle is managed by the framework on the main actor.
/// Deterministic behavior: always launches to a single root flow with no side effects.
/// Example usage: run the `CowCodableDemoApp` scheme on an iOS 16+ simulator.
@main
internal struct CowCodableDemoApp: App {

    // MARK: - Body

    internal var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
