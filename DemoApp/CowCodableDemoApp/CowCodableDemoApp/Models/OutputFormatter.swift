/// File: OutputFormatter.swift
///
/// Demo application source for the CowCodable SDK showcase.

import CowCodable
import Foundation

/// Formatting helpers for decode output and user-facing errors.
///
/// Purpose: transform raw decode results into readable JSON and friendly diagnostics.
/// Design philosophy: centralize text formatting so views remain presentation-only.
/// Thread safety: stateless static helpers with no shared mutable storage.
/// Deterministic behavior: same input always produces the same rendered output strings.
/// Example usage: used by `DecodeViewModel` after each decode attempt.
internal enum OutputFormatter {

    // MARK: - Summary

    internal struct Summary {
        internal let rescuedCount: Int
        internal let skippedCount: Int
        internal let failedCount: Int
    }

    // MARK: - Public Helpers

    internal static func prettyJSON(from data: Data) -> String {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let prettyData = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys]
            ),
            let text = String(data: prettyData, encoding: .utf8)
        else {
            return String(decoding: data, as: UTF8.self)
        }

        return text
    }

    internal static func summary(from entries: [CowLogEntry]) -> Summary {
        Summary(
            rescuedCount: entries.filter { $0.kind == .rescued }.count,
            skippedCount: entries.filter { $0.kind == .skipped }.count,
            failedCount: entries.filter { $0.kind == .failed }.count
        )
    }

    internal static func friendlyError(_ error: Error) -> String {
        if let decodingError = error as? DecodingError {
            return describe(decodingError)
        }

        if let cowError = error as? CowDecodingError {
            return cowError.errorDescription ?? "CowCodable could not decode the payload."
        }

        return "Decoding failed. Check JSON validity and selected strategy."
    }

    // MARK: - Internal Helpers

    private static func describe(_ decodingError: DecodingError) -> String {
        switch decodingError {
        case .typeMismatch(_, let context):
            return "Type mismatch at '\(pathString(context.codingPath))'. \(context.debugDescription)"
        case .valueNotFound(_, let context):
            return "Required value missing at '\(pathString(context.codingPath))'. \(context.debugDescription)"
        case .keyNotFound(let key, let context):
            return "Missing key '\(key.stringValue)' at '\(pathString(context.codingPath))'. \(context.debugDescription)"
        case .dataCorrupted(let context):
            return "Invalid JSON structure at '\(pathString(context.codingPath))'. \(context.debugDescription)"
        @unknown default:
            return "Decoding failed due to an unsupported error condition."
        }
    }

    private static func pathString(_ path: [CodingKey]) -> String {
        if path.isEmpty {
            return "<root>"
        }

        return path.map(\.stringValue).joined(separator: ".")
    }
}
