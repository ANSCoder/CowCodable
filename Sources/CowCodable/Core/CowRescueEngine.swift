/// File: CowRescueEngine.swift
///
/// This file is part of the CowCodable deterministic decoding SDK project.

import Foundation

/// Internal engine responsible for coordinating deterministic rescue logic
/// for values decoded via `@CowResilient`.
///
/// `CowRescueEngine` acts as a thin orchestration layer between:
/// - `AnyCodableValue` (raw decoded JSON bridge)
/// - `CowRescuePrimitive` conforming types
/// - `CowDefaultValue` conforming types
/// - Selected `CowRescueMode` (Strict / Permissive)
///
/// This type does not contain rescue rules itself. Instead, it delegates
/// conversion logic to primitive types that conform to `CowRescuePrimitive`,
/// ensuring:
///
/// - Deterministic behavior
/// - No reflection usage
/// - No unsafe casting
/// - Explicit conversion matrix
///
/// ## Design Philosophy
///
/// The engine is intentionally:
/// - Stateless
/// - Deterministic
/// - Protocol-driven
/// - Non-magical
///
/// It does not attempt to rescue arbitrary `Codable` models.
/// Only types conforming to `CowRescuePrimitive` are eligible.
///
/// ## Deterministic Guarantees
///
/// - Rescue only occurs if explicitly supported by the primitive.
/// - Ambiguous numeric coercions (e.g., `12.3` → `Int`) must fail in strict mode.
/// - Behavior differs only based on `CowRescueMode`.
/// - No silent fallback occurs outside defined rules.
///
/// ## Thread Safety
///
/// `CowRescueEngine` contains no mutable state and is fully thread-safe.
///
/// ## Performance
///
/// All operations are O(1) per value.
/// No heap allocations beyond standard decoding infrastructure.
///
/// ## Example (Internal Usage)
///
/// ```swift
/// let rescued: Int? = CowRescueEngine.rescue(rawValue,
///                                            as: Int.self,
///                                            mode: .strict)
/// ```
///
/// This type is internal infrastructure and not intended for public use.
internal enum CowRescueEngine {

    /// Attempts to rescue a value for a given target type using the selected rescue mode.
    ///
    /// - Parameters:
    ///   - value: The raw `AnyCodableValue` decoded from JSON.
    ///   - type: The expected target type.
    ///   - mode: The rescue mode (`.strict` or `.permissive`).
    ///
    /// - Returns: A deterministically rescued value if supported; otherwise `nil`.
    ///
    /// This function delegates rescue logic to the target type
    /// if it conforms to `CowRescuePrimitive`.
    static func rescue<Value>(
        _ value: AnyCodableValue,
        as type: Value.Type,
        mode: CowRescueMode
    ) -> Value? where Value: Codable {
        rescueByPrimitiveProtocol(value, as: type, mode: mode)
    }

    /// Internal protocol-based rescue dispatch.
    ///
    /// If `Value` conforms to `CowRescuePrimitive`, this method invokes
    /// the primitive’s rescue logic.
    ///
    /// - Returns: Rescued value if conversion is supported.
    static func rescueByPrimitiveProtocol<Value>(
        _ value: AnyCodableValue,
        as type: Value.Type,
        mode: CowRescueMode
    ) -> Value? where Value: Codable {
        guard let primitiveType = Value.self as? any CowRescuePrimitive.Type,
              let result = primitiveType.cowRescue(from: value, using: mode)
        else {
            return nil
        }
        return result as? Value
    }

    /// Returns a default value for a given type if it conforms to `CowDefaultValue`.
    ///
    /// Used primarily when:
    /// - `CowNullStrategy.useDefault` is selected
    /// - A key is missing or explicitly `null`
    ///
    /// - Parameter type: Target type.
    /// - Returns: Default value if available; otherwise `nil`.
    ///
    /// This does not generate synthetic defaults.
    /// Only types explicitly conforming to `CowDefaultValue` are supported.
    static func defaultValue<Value>(for type: Value.Type) -> Value? where Value: Codable {
        guard let defaultType = Value.self as? any CowDefaultValue.Type else {
            return nil
        }
        return defaultType.cowDefaultValue as? Value
    }
}

/// Utility responsible for deterministic numeric string parsing.
///
/// `CowNumericParser` centralizes all string-to-number conversion logic
/// for `Double` and `Float` rescue operations.
///
/// This parser:
/// - Trims whitespace
/// - Supports scientific notation
/// - Optionally supports special float tokens (`NaN`, `Infinity`, etc.)
/// - Enforces deterministic behavior based on configuration
///
/// ## Special Float Handling
///
/// Supported tokens (case-insensitive):
///
/// - `nan`
/// - `infinity`
/// - `+infinity`
/// - `-infinity`
/// - `inf`
/// - `+inf`
/// - `-inf`
///
/// Special values are only allowed when `allowSpecialFloatValues` is `true`.
/// Otherwise, they are rejected deterministically.
///
/// ## Design Philosophy
///
/// This parser exists to:
///
/// - Prevent scattered numeric parsing logic
/// - Centralize float handling rules
/// - Avoid inconsistent behavior between `Float` and `Double`
/// - Make Strict vs Permissive mode behavior predictable
///
/// ## Deterministic Guarantees
///
/// - Empty strings always fail.
/// - Whitespace is trimmed before parsing.
/// - No fallback coercion is performed.
/// - Behavior does not vary outside configuration flags.
///
/// ## Thread Safety
///
/// Stateless and thread-safe.
///
/// ## Performance
///
/// O(1) per parse operation.
///
/// This type is internal and not part of public API.
internal enum CowNumericParser {

    /// Parses a `Double` from a string.
    ///
    /// - Parameters:
    ///   - value: Input string.
    ///   - allowSpecialFloatValues: Whether `NaN` and `Infinity` tokens are allowed.
    ///
    /// - Returns: Parsed `Double` if valid; otherwise `nil`.
    static func parseDouble(_ value: String, allowSpecialFloatValues: Bool) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.lowercased()
        if isSpecialFloatToken(normalized) {
            guard allowSpecialFloatValues else { return nil }
            return mapSpecialDoubleToken(normalized)
        }
        return Double(trimmed)
    }

    /// Parses a `Float` from a string.
    ///
    /// - Parameters:
    ///   - value: Input string.
    ///   - allowSpecialFloatValues: Whether `NaN` and `Infinity` tokens are allowed.
    ///
    /// - Returns: Parsed `Float` if valid; otherwise `nil`.
    static func parseFloat(_ value: String, allowSpecialFloatValues: Bool) -> Float? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.lowercased()
        if isSpecialFloatToken(normalized) {
            guard allowSpecialFloatValues else { return nil }
            return mapSpecialFloatToken(normalized)
        }
        return Float(trimmed)
    }

    /// Determines whether a string matches a special float token.
    private static func isSpecialFloatToken(_ value: String) -> Bool {
        value == "nan"
            || value == "infinity"
            || value == "+infinity"
            || value == "-infinity"
            || value == "inf"
            || value == "+inf"
            || value == "-inf"
    }

    /// Maps special string tokens to `Double` values.
    private static func mapSpecialDoubleToken(_ value: String) -> Double? {
        switch value {
        case "nan": .nan
        case "infinity", "+infinity", "inf", "+inf": .infinity
        case "-infinity", "-inf": -.infinity
        default: nil
        }
    }

    /// Maps special string tokens to `Float` values.
    private static func mapSpecialFloatToken(_ value: String) -> Float? {
        switch value {
        case "nan": .nan
        case "infinity", "+infinity", "inf", "+inf": .infinity
        case "-infinity", "-inf": -.infinity
        default: nil
        }
    }
}
