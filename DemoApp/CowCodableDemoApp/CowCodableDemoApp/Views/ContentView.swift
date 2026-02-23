/// File: ContentView.swift
///
/// Demo application source for the CowCodable SDK showcase.

import SwiftUI

/// Root screen for CowCodable SDK behavior exploration.
///
/// Purpose: compose JSON input, decode controls, output rendering, and rescue diagnostics.
/// Design philosophy: keep visual composition in the view and business logic in the view model.
/// Thread safety: state mutations are isolated to `DecodeViewModel` on the main actor.
/// Deterministic behavior: UI rendering reflects only bound state, with no hidden side effects.
/// Example usage: launch app, pick a preset, edit JSON, decode, and inspect logs.
internal struct ContentView: View {

    // MARK: - State

    @StateObject private var viewModel = DecodeViewModel()
    @FocusState private var isJSONEditorFocused: Bool

    // MARK: - Body

    internal var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    presetSection
                    jsonInputSection
                    controlsSection
                    outputSection
                    summarySection
                    logSection
                }
                .padding(20)
            }
            .navigationTitle("CowCodable")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isJSONEditorFocused = false
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        Text("CowCodable SDK Demo")
            .font(.title2)
            .fontWeight(.semibold)
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("JSON Preset")
                .font(.headline)

            Picker("JSON Preset", selection: $viewModel.selectedPreset) {
                ForEach(JSONPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.menu)

            Text(viewModel.selectedPreset.explanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var jsonInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("JSON Input")
                .font(.headline)

            TextEditor(text: $viewModel.jsonInput)
                .font(.system(.body, design: .monospaced))
                .focused($isJSONEditorFocused)
                .frame(minHeight: 220)
                .padding(8)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var controlsSection: some View {
        StrategyControlsView(
            strategy: $viewModel.selectedStrategy,
            nullStrategy: $viewModel.selectedNullStrategy,
            isDecoding: viewModel.isDecoding,
            decodeAction: viewModel.decode,
            resetAction: viewModel.reset,
            copyOutputAction: viewModel.copyOutput,
            clearLogAction: viewModel.clearLog
        )
    }

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Decoded Output")
                .font(.headline)

            if let error = viewModel.errorMessage {
                outputContainer(text: error, isError: true)
            } else {
                outputContainer(
                    text: viewModel.decodedOutput.isEmpty ? "No decoded output yet." : viewModel.decodedOutput,
                    isError: false
                )
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Rescue Summary")
                .font(.headline)
            Text(viewModel.rescueSummaryLine)
                .font(.subheadline)
            Text(viewModel.skipSummaryLine)
                .font(.subheadline)
            Text(viewModel.failureSummaryLine)
                .font(.subheadline)
        }
    }

    private var logSection: some View {
        RescueLogView(entries: viewModel.logEntries)
    }

    private func outputContainer(text: String, isError: Bool) -> some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(isError ? Color.red : Color.primary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
