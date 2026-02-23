/// File: CowLogger.swift
///
/// This file is part of the CowCodable deterministic decoding SDK project.

import Foundation

// MARK: - CowLogKind

/// Category of deterministic decode log entries produced by CowCodable.
///
/// ---------------------------------------------------------------------
/// PURPOSE
/// ---------------------------------------------------------------------
///
/// Categorizes structured decode events emitted during rescue operations.
///
/// This enables:
/// - Machine-readable diagnostics
/// - UI presentation (e.g., demo app)
/// - Precise test assertions
///
/// ---------------------------------------------------------------------
/// CASES
/// ---------------------------------------------------------------------
///
/// - `rescued`  → A value was deterministically converted
/// - `skipped`  → A value was dropped (array/dictionary element)
/// - `failed`   → A decode operation failed deterministically
///
/// ---------------------------------------------------------------------
/// THREAD SAFETY
/// ---------------------------------------------------------------------
///
/// Value type. Fully `Sendable`.
public enum CowLogKind: String, Codable, Sendable {
    case rescued
    case skipped
    case failed
}


// MARK: - CowLogEntry

/// Structured deterministic decode log entry.
///
/// ---------------------------------------------------------------------
/// PURPOSE
/// ---------------------------------------------------------------------
///
/// Provides structured insight into:
/// - Rescue behavior
/// - Skip behavior
/// - Decode failures
///
/// Designed for:
/// - Debugging
/// - Automated testing
/// - Demo UI rendering
/// - Observability tooling
///
/// ---------------------------------------------------------------------
/// DESIGN PRINCIPLES
/// ---------------------------------------------------------------------
///
/// - Immutable
/// - Deterministic
/// - Machine-readable
/// - Serializable
///
/// ---------------------------------------------------------------------
/// FIELDS
/// ---------------------------------------------------------------------
///
/// - `kind`       → Category of event
/// - `codingPath` → Dot-separated decode path
/// - `message`    → Human-readable explanation
/// - `rawValue`   → Original raw JSON value representation
///
/// ---------------------------------------------------------------------
/// THREAD SAFETY
/// ---------------------------------------------------------------------
///
/// Immutable value type.
/// Fully `Sendable`.
public struct CowLogEntry: Codable, Sendable {

    public let kind: CowLogKind
    public let codingPath: String
    public let message: String
    public let rawValue: String

    public init(kind: CowLogKind,
                codingPath: String,
                message: String,
                rawValue: String) {
        self.kind = kind
        self.codingPath = codingPath
        self.message = message
        self.rawValue = rawValue
    }
}


// MARK: - CowLogger

/// Deterministic logging utility for `@CowResilient`.
///
/// ---------------------------------------------------------------------
/// DESIGN PHILOSOPHY
/// ---------------------------------------------------------------------
///
/// `CowLogger` exists to provide:
///
/// - Deterministic structured logging
/// - Optional capture for testing
/// - Debug-mode console output
///
/// Logging is:
/// - Explicit
/// - Structured
/// - Predictable
/// - Non-magical
///
/// It does NOT:
/// - Swallow errors
/// - Alter decode behavior
/// - Perform rescue itself
///
/// ---------------------------------------------------------------------
/// CAPTURE LIFECYCLE
/// ---------------------------------------------------------------------
///
/// Logging operates in two modes:
///
/// 1. Passive mode (default)
///    - Only debug console output (if enabled)
///
/// 2. Capture mode
///    - Structured entries are recorded in memory
///    - Intended for:
///         - Demo UI
///         - Unit tests
///
/// Capture must be explicitly started via:
///
/// ```swift
/// CowLogger.beginCapture()
/// ```
///
/// ---------------------------------------------------------------------
/// THREAD SAFETY
/// ---------------------------------------------------------------------
///
/// - Internal state protected by `NSLock`
/// - Safe for concurrent decoding
///
/// ---------------------------------------------------------------------
/// PERFORMANCE
/// ---------------------------------------------------------------------
///
/// - O(1) append
/// - O(1) read snapshot
/// - Minimal lock contention
///
/// Debug printing is conditional.
///
/// ---------------------------------------------------------------------
/// DEBUG BEHAVIOR
/// ---------------------------------------------------------------------
///
/// Console printing occurs only in `DEBUG` builds,
/// unless environment variable:
///
///     COWCODABLE_DEBUG_LOGGING=0
///
/// is set to disable it.
///
/// ---------------------------------------------------------------------
/// IMPORTANT
/// ---------------------------------------------------------------------
///
/// Logging must never influence decode logic.
/// It is purely observational.
///
public enum CowLogger {

    private static let lock = NSLock()

    private nonisolated(unsafe) static var captureEnabled = false
    private nonisolated(unsafe) static var entries: [CowLogEntry] = []

    private static let debugLoggingEnvironmentKey = "COWCODABLE_DEBUG_LOGGING"

    // MARK: Capture Control

    /// Begins structured log capture.
    ///
    /// - Parameter reset:
    ///     When `true`, clears existing entries before starting capture.
    ///
    /// Intended for:
    /// - Unit tests
    /// - Demo app decoding session
    public static func beginCapture(reset: Bool = true) {
        lock.withLock {
            captureEnabled = true
            if reset {
                entries.removeAll(keepingCapacity: true)
            }
        }
    }

    /// Ends capture and returns all recorded entries.
    ///
    /// - Returns:
    ///     Snapshot of captured entries in insertion order.
    public static func endCapture() -> [CowLogEntry] {
        lock.withLock {
            captureEnabled = false
            return entries
        }
    }

    /// Returns recent captured entries.
    ///
    /// - Parameter limit:
    ///     Optional maximum number of entries from the tail.
    ///
    /// - Returns:
    ///     Snapshot of entries.
    public static func recentEntries(limit: Int? = nil) -> [CowLogEntry] {
        lock.withLock {
            guard let limit,
                  limit > 0,
                  entries.count > limit
            else {
                return entries
            }
            return Array(entries.suffix(limit))
        }
    }

    /// Clears all recorded entries.
    public static func clear() {
        lock.withLock {
            entries.removeAll(keepingCapacity: false)
        }
    }

    // MARK: Internal Logging Hooks

    static func logRescue(expected: String,
                          actual: String,
                          value: String,
                          codingPath: [CodingKey]) {
        let message = "Rescued \(actual) into \(expected)"
        append(.init(
            kind: .rescued,
            codingPath: codingPathString(codingPath),
            message: message,
            rawValue: value
        ))
    }

    static func logSkip(codingPath: [CodingKey],
                        reason: String,
                        rawValue: String) {
        append(.init(
            kind: .skipped,
            codingPath: codingPathString(codingPath),
            message: reason,
            rawValue: rawValue
        ))
    }

    static func logFailure(codingPath: [CodingKey],
                           reason: String,
                           rawValue: String) {
        append(.init(
            kind: .failed,
            codingPath: codingPathString(codingPath),
            message: reason,
            rawValue: rawValue
        ))
    }

    // MARK: Internal Append

    private static func append(_ entry: CowLogEntry) {
        lock.withLock {

            if captureEnabled {
                entries.append(entry)
            }

            #if DEBUG
            if ProcessInfo.processInfo.environment[debugLoggingEnvironmentKey] != "0" {
                print("🐄 [\(entry.kind.rawValue)] \(entry.codingPath): \(entry.message) | raw=\(entry.rawValue)")
            }
            #endif
        }
    }

    private static func codingPathString(_ codingPath: [CodingKey]) -> String {
        codingPath.isEmpty
            ? "<root>"
            : codingPath.map(\.stringValue).joined(separator: ".")
    }
}
