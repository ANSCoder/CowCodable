/// File: StrategyControlsView.swift
///
/// Demo application source for the CowCodable SDK showcase.

import CowCodable
import SwiftUI

/// Decode controls for strategy selection and decode actions.
///
/// Purpose: centralize all user commands that influence decoding behavior.
/// Design philosophy: keep controls stateless and bind all behavior to the view model.
/// Thread safety: this view performs no shared mutable work.
/// Deterministic behavior: each control maps directly to a single bound state/action.
/// Example usage: embed in `ContentView` with bindings from `DecodeViewModel`.
internal struct StrategyControlsView: View {

    // MARK: - Bindings

    @Binding internal var strategy: DemoStrategy
    @Binding internal var nullStrategy: CowNullStrategy

    // MARK: - Inputs

    internal let isDecoding: Bool
    internal let decodeAction: () -> Void
    internal let resetAction: () -> Void
    internal let copyOutputAction: () -> Void
    internal let clearLogAction: () -> Void

    // MARK: - Body

    internal var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Controls")
                .font(.headline)

            strategyPicker
            nullStrategyPicker
            actionButtons
        }
    }

    // MARK: - Subviews

    private var strategyPicker: some View {
        Picker("Mode", selection: $strategy) {
            ForEach(DemoStrategy.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var nullStrategyPicker: some View {
        Picker("Null Strategy", selection: $nullStrategy) {
            Text("Fail").tag(CowNullStrategy.fail)
            Text("Use Default").tag(CowNullStrategy.useDefault)
            Text("Skip").tag(CowNullStrategy.skip)
        }
        .pickerStyle(.menu)
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button(isDecoding ? "Decoding..." : "Decode", action: decodeAction)
                .buttonStyle(.borderedProminent)
                .disabled(isDecoding)

            Button("Reset", action: resetAction)
                .buttonStyle(.bordered)

            Button("Copy Output", action: copyOutputAction)
                .buttonStyle(.bordered)

            Button("Clear Log", action: clearLogAction)
                .buttonStyle(.bordered)
        }
    }
}

/// Demo decode modes mapped to CowCodable rescue strategies.
///
/// Purpose: present user-selectable strategy values without exposing SDK internals in views.
/// Design philosophy: use a small enum adapter between UI and package metatypes.
/// Thread safety: immutable enum values are fully sendable.
/// Deterministic behavior: each case maps to one fixed strategy type.
/// Example usage: bind in segmented control and pass `sdkType` to configuration.
internal enum DemoStrategy: String, CaseIterable, Identifiable, Sendable {
    case strict = "Strict"
    case permissive = "Permissive"

    internal var id: String {
        rawValue
    }

    internal var sdkType: any CowRescueStrategy.Type {
        switch self {
        case .strict:
            return StrictRescueStrategy.self
        case .permissive:
            return PermissiveRescueStrategy.self
        }
    }
}
