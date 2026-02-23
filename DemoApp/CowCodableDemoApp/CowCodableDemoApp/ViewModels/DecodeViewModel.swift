/// File: DecodeViewModel.swift
///
/// Demo application source for the CowCodable SDK showcase.

import CowCodable
import Foundation
import UIKit

/// Main view model for JSON decoding workflow.
///
/// Purpose: own decode state, execute decode work off the main thread, and publish UI-ready outputs.
/// Design philosophy: isolate all business logic from SwiftUI views to enforce MVVM boundaries.
/// Thread safety: all observable state runs on `@MainActor`; decoding occurs in detached tasks.
/// Deterministic behavior: decode outcome is fully determined by selected preset, strategy, and JSON input.
/// Example usage: instantiate as `@StateObject` in `ContentView`.
@MainActor
internal final class DecodeViewModel: ObservableObject {

    // MARK: - Published State

    @Published internal var selectedPreset: JSONPreset = .primitiveCorruption {
        didSet {
            applySelectedPreset()
        }
    }

    @Published internal var jsonInput: String
    @Published internal var selectedStrategy: DemoStrategy = .strict
    @Published internal var selectedNullStrategy: CowNullStrategy = .fail

    @Published internal var decodedOutput: String = ""
    @Published internal var logEntries: [CowLogEntry] = []
    @Published internal var errorMessage: String?
    @Published internal var isDecoding: Bool = false

    @Published internal var rescueSummaryLine: String = "0 values rescued"
    @Published internal var skipSummaryLine: String = "0 elements skipped"
    @Published internal var failureSummaryLine: String = "0 failures"

    // MARK: - Initialization

    internal init() {
        jsonInput = JSONPreset.primitiveCorruption.sampleJSON
    }

    // MARK: - User Actions

    internal func decode() {
        guard !isDecoding else {
            return
        }

        let preset = selectedPreset
        let input = jsonInput
        let strategy = selectedStrategy
        let nullStrategy = selectedNullStrategy

        isDecoding = true
        errorMessage = nil

        Task {
            let result = await Self.performDecode(
                preset: preset,
                jsonInput: input,
                strategy: strategy,
                nullStrategy: nullStrategy
            )

            applyDecodeResult(result)
        }
    }

    internal func reset() {
        applySelectedPreset()
        clearResultState()
    }

    internal func clearLog() {
        logEntries = []
        rescueSummaryLine = "0 values rescued"
        skipSummaryLine = "0 elements skipped"
        failureSummaryLine = "0 failures"
    }

    internal func copyOutput() {
        let contentToCopy = errorMessage ?? decodedOutput

        guard !contentToCopy.isEmpty else {
            return
        }

        UIPasteboard.general.string = contentToCopy
    }

    // MARK: - State Helpers

    private func applySelectedPreset() {
        jsonInput = selectedPreset.sampleJSON
        clearResultState()
    }

    private func clearResultState() {
        decodedOutput = ""
        errorMessage = nil
        clearLog()
    }

    private func applyDecodeResult(_ result: DecodeResult) {
        decodedOutput = result.output
        logEntries = result.logs
        errorMessage = result.error

        let summary = OutputFormatter.summary(from: result.logs)
        rescueSummaryLine = "\(summary.rescuedCount) values rescued"
        skipSummaryLine = "\(summary.skippedCount) elements skipped"
        failureSummaryLine = "\(summary.failedCount) failures"
        isDecoding = false
    }

    // MARK: - Decode Pipeline

    nonisolated private static func performDecode(
        preset: JSONPreset,
        jsonInput: String,
        strategy: DemoStrategy,
        nullStrategy: CowNullStrategy
    ) async -> DecodeResult {
        await Task.detached(priority: .userInitiated) {
            CowConfiguration.defaultRescueStrategy = strategy.sdkType
            CowConfiguration.defaultNullStrategy = nullStrategy
            CowLogger.beginCapture(reset: true)

            defer {
                _ = CowLogger.endCapture()
            }

            do {
                let data = Data(jsonInput.utf8)
                let decodedData = try decodePreset(preset: preset, from: data)
                let logs = CowLogger.recentEntries()
                let output = OutputFormatter.prettyJSON(from: decodedData)
                return DecodeResult(output: output, logs: logs, error: nil)
            } catch {
                let logs = CowLogger.recentEntries()
                let message = OutputFormatter.friendlyError(error)
                return DecodeResult(output: "", logs: logs, error: message)
            }
        }.value
    }

    nonisolated private static func decodePreset(preset: JSONPreset, from data: Data) throws -> Data {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        switch preset {
        case .primitiveCorruption:
            return try encoder.encode(decoder.decode(PrimitiveCorruptionModel.self, from: data))
        case .arrayCorruption:
            return try encoder.encode(decoder.decode(ArrayCorruptionModel.self, from: data))
        case .dictionaryCorruption:
            return try encoder.encode(decoder.decode(DictionaryCorruptionModel.self, from: data))
        case .nestedComplex:
            return try encoder.encode(decoder.decode(NestedComplexModel.self, from: data))
        case .nullEdgeCase:
            return try encoder.encode(decoder.decode(NullEdgeCaseModel.self, from: data))
        case .overflowCase:
            return try encoder.encode(decoder.decode(OverflowCaseModel.self, from: data))
        case .strictVsPermissiveCase:
            return try encoder.encode(decoder.decode(StrictPermissiveCaseModel.self, from: data))
        }
    }
}

// MARK: - DecodeResult

private struct DecodeResult {
    let output: String
    let logs: [CowLogEntry]
    let error: String?
}
