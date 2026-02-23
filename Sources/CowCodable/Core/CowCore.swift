/// File: CowCore.swift
///
/// This file is part of the CowCodable deterministic decoding SDK project.

import Foundation

// MARK: - CowNullStrategy

/// Controls how `@CowResilient` handles structural JSON issues:
/// - Missing keys
/// - Explicit `null` values
///
/// `CowNullStrategy` intentionally separates structural payload problems
/// from type conversion (rescue) problems.
///
/// This ensures:
/// - Deterministic behavior
/// - Clear failure classification
/// - No hidden implicit fallbacks
///
/// ---------------------------------------------------------------------
/// DESIGN PHILOSOPHY
/// ---------------------------------------------------------------------
///
/// Structural problems (missing/null) are NOT type mismatches.
/// They are handled explicitly and predictably by this strategy.
///
/// Missing key and explicit `null` are treated as distinct states.
/// The chosen strategy defines deterministic behavior for both.
///
/// ---------------------------------------------------------------------
/// DETERMINISTIC GUARANTEES
/// ---------------------------------------------------------------------
///
/// - Same payload + same strategy = same result.
/// - No strategy introduces silent coercion.
/// - No implicit default unless explicitly configured.
///
/// ---------------------------------------------------------------------
/// PERFORMANCE
/// ---------------------------------------------------------------------
///
/// O(1) branching at decode time.
///
/// ---------------------------------------------------------------------
/// THREAD SAFETY
/// ---------------------------------------------------------------------
///
/// Value type. Fully `Sendable`.
///
/// ---------------------------------------------------------------------
/// EXAMPLE
/// ---------------------------------------------------------------------
///
/// ```swift
/// CowConfiguration.defaultNullStrategy = .useDefault
/// ```
public enum CowNullStrategy: String, CaseIterable, Sendable, Codable {

    /// Throw when key is missing or value is explicitly `null`.
    case fail

    /// Use deterministic default value when available.
    case useDefault

    /// Skip missing/null and preserve current value (if any).
    case skip
}

// MARK: - Internal Rescue Mode

/// Internal rescue mode used to differentiate strict and permissive policies.
///
/// This is intentionally not public to avoid exposing internal dispatch logic.
internal enum CowRescueMode: Sendable {
    case strict
    case permissive
}

// MARK: - Public Rescue Strategy Protocol

/// Public contract for selecting rescue policy.
///
/// Strategy types provide an explicit decoding policy
/// without exposing internal bridge or primitive mechanics.
///
/// ---------------------------------------------------------------------
/// DESIGN PHILOSOPHY
/// ---------------------------------------------------------------------
///
/// Strategies define *conversion boundaries*, not rescue implementations.
///
/// They exist to:
/// - Make behavior explicit
/// - Avoid hidden global magic
/// - Enable runtime switching in controlled environments
///
/// ---------------------------------------------------------------------
/// DETERMINISTIC GUARANTEES
/// ---------------------------------------------------------------------
///
/// Strategy mode is static and deterministic.
/// It cannot vary per decode call unless explicitly reconfigured.
///
/// ---------------------------------------------------------------------
/// THREAD SAFETY
/// ---------------------------------------------------------------------
///
/// Strategies are metatype-only.
/// No instance state.
/// Fully thread-safe.
public protocol CowRescueStrategy {

    /// Human-readable name used in:
    /// - Diagnostics
    /// - Logging
    /// - Demo UI
    static var name: String { get }
}

internal protocol CowRescueModeProvider {
    static var mode: CowRescueMode { get }
}

// MARK: - Strict Strategy

/// Strict deterministic rescue policy.
///
/// ---------------------------------------------------------------------
/// BEHAVIOR SUMMARY
/// ---------------------------------------------------------------------
///
/// - Minimal coercion.
/// - No ambiguous numeric conversions.
/// - No scalar-to-array wrapping.
/// - No integer-to-Character Unicode scalar rescue.
/// - No speculative fallback.
///
/// Strict mode prioritizes predictability over flexibility.
///
/// ---------------------------------------------------------------------
/// EXAMPLE
/// ---------------------------------------------------------------------
///
/// ```swift
/// CowConfiguration.defaultRescueStrategy = StrictRescueStrategy.self
/// ```
public enum StrictRescueStrategy: CowRescueStrategy, CowRescueModeProvider {
    public static let name = "Strict"
    static let mode: CowRescueMode = .strict
}

// MARK: - Permissive Strategy

/// Permissive deterministic rescue policy.
///
/// ---------------------------------------------------------------------
/// BEHAVIOR SUMMARY
/// ---------------------------------------------------------------------
///
/// - Allows additional deterministic conversions.
/// - Accepts integral scientific notation strings for `Int`.
/// - Allows scalar-to-array wrapping (e.g., `"5"` → `[5]`).
/// - Allows integer Unicode scalar → `Character`.
///
/// Still deterministic.
/// Never performs ambiguous coercion.
///
/// ---------------------------------------------------------------------
/// EXAMPLE
/// ---------------------------------------------------------------------
///
/// ```swift
/// CowConfiguration.defaultRescueStrategy = PermissiveRescueStrategy.self
/// ```
public enum PermissiveRescueStrategy: CowRescueStrategy, CowRescueModeProvider {
    public static let name = "Permissive"
    static let mode: CowRescueMode = .permissive
}

// MARK: - Global Configuration

/// Global decoding configuration for `@CowResilient`.
///
/// ---------------------------------------------------------------------
/// DESIGN PHILOSOPHY
/// ---------------------------------------------------------------------
///
/// Centralized configuration:
/// - Keeps model definitions clean
/// - Enables runtime policy switching
/// - Avoids passing strategy everywhere
///
/// Configuration is global by design.
/// It affects all `@CowResilient` decoding operations.
///
/// ---------------------------------------------------------------------
/// DETERMINISTIC GUARANTEES
/// ---------------------------------------------------------------------
///
/// - Configuration changes apply only to subsequent decodes.
/// - Lock-protected state ensures consistent reads.
/// - No partial updates.
///
/// ---------------------------------------------------------------------
/// THREAD SAFETY
/// ---------------------------------------------------------------------
///
/// Uses internal `NSLock` to protect mutable static state.
/// Safe for concurrent reads and writes.
///
/// ---------------------------------------------------------------------
/// PERFORMANCE
/// ---------------------------------------------------------------------
///
/// O(1) lock-protected access.
/// Lock contention is minimal and decode-time negligible.
///
/// ---------------------------------------------------------------------
/// EXAMPLE
/// ---------------------------------------------------------------------
///
/// ```swift
/// CowConfiguration.defaultRescueStrategy = PermissiveRescueStrategy.self
/// CowConfiguration.defaultNullStrategy = .skip
/// ```
public enum CowConfiguration {

    private static let lock = NSLock()

    private nonisolated(unsafe) static var _defaultNullStrategy: CowNullStrategy = .fail
    private nonisolated(unsafe) static var _defaultRescueMode: CowRescueMode = .strict

    /// Default null handling strategy.
    public static var defaultNullStrategy: CowNullStrategy {
        get { lock.withLock { _defaultNullStrategy } }
        set { lock.withLock { _defaultNullStrategy = newValue } }
    }

    /// Default rescue strategy type.
    public static var defaultRescueStrategy: any CowRescueStrategy.Type {
        get {
            lock.withLock {
                switch _defaultRescueMode {
                case .strict: StrictRescueStrategy.self
                case .permissive: PermissiveRescueStrategy.self
                }
            }
        }
        set {
            lock.withLock {
                if let provider = newValue as? any CowRescueModeProvider.Type {
                    _defaultRescueMode = provider.mode
                } else {
                    _defaultRescueMode = .strict
                }
            }
        }
    }

    /// Internal mode used by rescue engine.
    static var defaultRescueMode: CowRescueMode {
        lock.withLock { _defaultRescueMode }
    }
}

// MARK: - CowDecodingError

/// Error emitted by `@CowResilient` when deterministic decoding cannot complete.
///
/// ---------------------------------------------------------------------
/// ERROR CLASSIFICATION
/// ---------------------------------------------------------------------
///
/// Each case maps one-to-one with failure type:
///
/// - Missing key
/// - Explicit null
/// - Invalid type conversion
/// - Missing deterministic default provider
///
/// No error is ambiguous.
///
/// ---------------------------------------------------------------------
/// THREAD SAFETY
/// ---------------------------------------------------------------------
///
/// Immutable value type.
/// Fully `Sendable`.
public enum CowDecodingError: LocalizedError, Sendable {

    case missingKey(codingPath: [CodingKey], expectedType: String)

    case nullValue(codingPath: [CodingKey], expectedType: String, strategy: CowNullStrategy)

    case invalidType(codingPath: [CodingKey], expectedType: String, actualType: String, rawValue: String)

    case defaultValueUnavailable(expectedType: String)

    public var errorDescription: String? {
        switch self {
        case .missingKey(let path, let expectedType):
            return "CowResilient decoding failed: missing key at '\(path.cowPathString)' for expected type '\(expectedType)'."

        case .nullValue(let path, let expectedType, let strategy):
            return "CowResilient decoding failed: null value at '\(path.cowPathString)' for expected type '\(expectedType)' with strategy '\(strategy.rawValue)'."

        case .invalidType(let path, let expectedType, let actualType, let rawValue):
            return "CowResilient decoding failed: cannot rescue '\(actualType)' value '\(rawValue)' into '\(expectedType)' at '\(path.cowPathString)'."

        case .defaultValueUnavailable(let expectedType):
            return "CowResilient decoding failed: no deterministic default value is available for '\(expectedType)'."
        }
    }
}

// MARK: - NSLock Convenience

/// Convenience wrapper around `NSLock` to execute a closure
/// while holding the lock.
///
/// This helper:
/// - Ensures balanced `lock()` / `unlock()` calls
/// - Prevents accidental early returns leaving the lock held
/// - Reduces repetitive boilerplate
///
/// ---------------------------------------------------------------------
/// DESIGN PHILOSOPHY
/// ---------------------------------------------------------------------
///
/// Centralizing lock usage:
/// - Improves readability
/// - Reduces risk of deadlocks due to forgotten `unlock()`
/// - Keeps concurrency intent explicit
///
/// The closure is executed synchronously while the lock is held.
/// Callers should avoid performing long-running or blocking work
/// inside the closure.
///
/// ---------------------------------------------------------------------
/// THREAD SAFETY
/// ---------------------------------------------------------------------
///
/// Provides mutual exclusion for the duration of the closure.
/// Safe for concurrent use.
///
/// ---------------------------------------------------------------------
/// PERFORMANCE
/// ---------------------------------------------------------------------
///
/// O(1) lock acquisition and release.
/// The `@inline(__always)` attribute reduces call overhead.
///
/// ---------------------------------------------------------------------
/// EXAMPLE
/// ---------------------------------------------------------------------
///
/// ```swift
/// lock.withLock {
///     sharedState = newValue
/// }
/// ```
extension NSLock {

    @inline(__always)
    fileprivate func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}


// MARK: - Coding Path Formatting

/// Utility for converting a `CodingKey` path into
/// a human-readable dot-separated string.
///
/// Used primarily for:
/// - `CowDecodingError` descriptions
/// - Rescue logging
/// - Demo UI diagnostics
///
/// ---------------------------------------------------------------------
/// DESIGN PHILOSOPHY
/// ---------------------------------------------------------------------
///
/// The path representation:
/// - Is stable
/// - Deterministic
/// - Sorted by decoding traversal order
///
/// Root-level paths are represented as `"<root>"`
/// to avoid empty or ambiguous messages.
///
/// ---------------------------------------------------------------------
/// EXAMPLE
/// ---------------------------------------------------------------------
///
/// Given a coding path representing:
///
/// ```json
/// {
///   "user": {
///     "profile": {
///       "age": "invalid"
///     }
///   }
/// }
/// ```
///
/// The formatted string becomes:
///
/// ```
/// "user.profile.age"
/// ```
///
/// If the path is empty:
///
/// ```
/// "<root>"
/// ```
extension Array where Element == CodingKey {

    /// Human-readable dot-separated coding path string.
    fileprivate var cowPathString: String {
        isEmpty
            ? "<root>"
            : map(\.stringValue).joined(separator: ".")
    }
}
