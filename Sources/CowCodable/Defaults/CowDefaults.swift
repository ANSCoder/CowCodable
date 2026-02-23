/// File: CowDefaults.swift
///
/// This file is part of the CowCodable deterministic decoding SDK project.

import Foundation

// MARK: - CowDefaultValue

/// Supplies deterministic default values for `@CowResilient`.
///
/// ---------------------------------------------------------------------
/// PURPOSE
/// ---------------------------------------------------------------------
///
/// Used when `CowNullStrategy` requires a fallback value:
/// - `.useDefault`
/// - `.skip`
///
/// This protocol guarantees that default values are:
/// - Explicit
/// - Stable
/// - Deterministic
/// - Free from runtime inference
///
/// ---------------------------------------------------------------------
/// DESIGN PHILOSOPHY
/// ---------------------------------------------------------------------
///
/// Default values must never:
/// - Be randomly generated
/// - Depend on runtime state
/// - Be inferred dynamically
///
/// Only types explicitly conforming to this protocol
/// are eligible for default fallback behavior.
///
/// This prevents silent data corruption.
///
/// ---------------------------------------------------------------------
/// THREAD SAFETY
/// ---------------------------------------------------------------------
///
/// Conforming values should be immutable constants.
///
/// ---------------------------------------------------------------------
/// EXAMPLE
/// ---------------------------------------------------------------------
///
/// ```swift
/// extension URL: CowDefaultValue {
///     public static let cowDefaultValue = URL(string: "about:blank")!
/// }
/// ```
public protocol CowDefaultValue {
    static var cowDefaultValue: Self { get }
}


// MARK: - CowRescuePrimitive

/// Internal protocol defining deterministic rescue behavior.
///
/// Only primitive and primitive-container types conform to this protocol.
///
/// ---------------------------------------------------------------------
/// DESIGN PHILOSOPHY
/// ---------------------------------------------------------------------
///
/// Rescue rules must:
/// - Be explicit
/// - Be deterministic
/// - Respect Strict vs Permissive mode
/// - Avoid ambiguous coercion
/// - Avoid reflection
///
/// No hidden fallback logic is allowed here.
///
/// ---------------------------------------------------------------------
/// STRICT VS PERMISSIVE
/// ---------------------------------------------------------------------
///
/// Strict:
/// - Minimal coercion
/// - No speculative numeric interpretation
///
/// Permissive:
/// - Allows additional deterministic but safe conversions
/// - Never performs ambiguous coercion
///
/// ---------------------------------------------------------------------
/// THREAD SAFETY
/// ---------------------------------------------------------------------
///
/// Conforming types must be `Sendable`.
internal protocol CowRescuePrimitive: CowDefaultValue, Sendable {

    static func cowRescue(
        from value: AnyCodableValue,
        using mode: CowRescueMode
    ) -> Self?
}


// MARK: - Default Value Conformances

extension String: CowDefaultValue { public static let cowDefaultValue = "" }
extension Int: CowDefaultValue { public static let cowDefaultValue = 0 }
extension Double: CowDefaultValue { public static let cowDefaultValue = 0.0 }
extension Float: CowDefaultValue { public static let cowDefaultValue: Float = 0 }
extension Bool: CowDefaultValue { public static let cowDefaultValue = false }
extension Character: CowDefaultValue { public static let cowDefaultValue: Character = "\0" }

extension Array: CowDefaultValue where Element: CowDefaultValue {
    public static var cowDefaultValue: [Element] { [] }
}

extension Dictionary: CowDefaultValue where Key == String, Value: CowDefaultValue {
    public static var cowDefaultValue: [String: Value] { [:] }
}


// MARK: - Primitive Rescue Implementations

// MARK: String

extension String: CowRescuePrimitive {

    /// Rescue rules:
    /// - Accept String directly
    /// - Convert Int, Double, Bool via String()
    /// - Reject containers and null
    static func cowRescue(from value: AnyCodableValue,
                          using mode: CowRescueMode) -> String? {

        switch value {
        case .string(let raw): return raw
        case .int(let raw): return String(raw)
        case .double(let raw): return String(raw)
        case .bool(let raw): return String(raw)
        case .null, .array, .object:
            return nil
        }
    }
}


// MARK: Bool

extension Bool: CowRescuePrimitive {

    /// Rescue rules:
    /// - Accept Bool directly
    /// - Int/Double: non-zero → true
    /// - String: supports common boolean tokens
    /// - Reject containers/null
    static func cowRescue(from value: AnyCodableValue,
                          using mode: CowRescueMode) -> Bool? {

        switch value {

        case .bool(let raw):
            return raw

        case .int(let raw):
            return raw != 0

        case .double(let raw):
            return raw != 0

        case .string(let raw):
            switch raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased() {
            case "true", "1", "yes", "y", "t": return true
            case "false", "0", "no", "n", "f": return false
            default: return nil
            }

        case .null, .array, .object:
            return nil
        }
    }
}


// MARK: Character

extension Character: CowRescuePrimitive {

    /// Strict:
    /// - Accept single-character string only
    ///
    /// Permissive:
    /// - Accept Unicode scalar from Int
    /// - Accept integral Double as scalar
    static func cowRescue(from value: AnyCodableValue,
                          using mode: CowRescueMode) -> Character? {

        switch value {

        case .string(let raw):
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count == 1 else { return nil }
            return trimmed.first

        case .int(let raw):
            guard mode == .permissive,
                  let scalar = UnicodeScalar(raw)
            else { return nil }
            return Character(scalar)

        case .double(let raw):
            guard mode == .permissive,
                  raw.isFinite,
                  floor(raw) == raw,
                  raw >= Double(Int.min),
                  raw <= Double(Int.max),
                  let scalar = UnicodeScalar(Int(raw))
            else { return nil }
            return Character(scalar)

        case .bool, .null, .array, .object:
            return nil
        }
    }
}


// MARK: Double

extension Double: CowRescuePrimitive {

    /// Strict:
    /// - Accept Double
    /// - Accept Int
    /// - Accept Bool
    /// - String parsed without special float tokens
    ///
    /// Permissive:
    /// - Allow NaN / Infinity tokens
    static func cowRescue(from value: AnyCodableValue,
                          using mode: CowRescueMode) -> Double? {

        switch value {

        case .double(let raw):
            return raw

        case .int(let raw):
            return Double(raw)

        case .bool(let raw):
            return raw ? 1 : 0

        case .string(let raw):
            return CowNumericParser.parseDouble(
                raw,
                allowSpecialFloatValues: mode == .permissive
            )

        case .null, .array, .object:
            return nil
        }
    }
}


// MARK: Float

extension Float: CowRescuePrimitive {

    static func cowRescue(from value: AnyCodableValue,
                          using mode: CowRescueMode) -> Float? {

        switch value {

        case .double(let raw):
            guard raw.isFinite || mode == .permissive,
                  raw >= -Double(Float.greatestFiniteMagnitude),
                  raw <= Double(Float.greatestFiniteMagnitude)
            else { return nil }
            return Float(raw)

        case .int(let raw):
            return Float(raw)

        case .bool(let raw):
            return raw ? 1 : 0

        case .string(let raw):
            return CowNumericParser.parseFloat(
                raw,
                allowSpecialFloatValues: mode == .permissive
            )

        case .null, .array, .object:
            return nil
        }
    }
}


// MARK: Int

extension Int: CowRescuePrimitive {

    /// Strict:
    /// - Accept Int
    /// - Accept Bool
    /// - Accept integral Double
    /// - Accept exact numeric String
    ///
    /// Permissive:
    /// - Accept integral scientific notation string
    static func cowRescue(from value: AnyCodableValue,
                          using mode: CowRescueMode) -> Int? {

        switch value {

        case .int(let raw):
            return raw

        case .bool(let raw):
            return raw ? 1 : 0

        case .double(let raw):
            guard raw.isFinite,
                  floor(raw) == raw,
                  raw >= Double(Int.min),
                  raw <= Double(Int.max)
            else { return nil }
            return Int(raw)

        case .string(let raw):
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

            if let exact = Int(trimmed) {
                return exact
            }

            guard mode == .permissive,
                  let asDouble = CowNumericParser.parseDouble(
                      trimmed,
                      allowSpecialFloatValues: false
                  ),
                  floor(asDouble) == asDouble,
                  asDouble >= Double(Int.min),
                  asDouble <= Double(Int.max)
            else {
                return nil
            }

            return Int(asDouble)

        case .null, .array, .object:
            return nil
        }
    }
}


// MARK: - Collection Rescue


// MARK: Array

extension Array: CowRescuePrimitive where Element: CowRescuePrimitive {

    /// Strict:
    /// - Only rescue if source is Array
    ///
    /// Permissive:
    /// - Allow scalar-to-array wrapping
    ///
    /// Invalid elements are dropped deterministically and logged.
    static func cowRescue(from value: AnyCodableValue,
                          using mode: CowRescueMode) -> [Element]? {

        let source: [AnyCodableValue]

        switch value {
        case .array(let raw):
            source = raw
        default:
            guard mode == .permissive else { return nil }
            source = [value]
        }

        var output: [Element] = []
        output.reserveCapacity(source.count)

        for element in source {
            if let rescued = Element.cowRescue(from: element, using: mode) {
                output.append(rescued)
            } else {
                CowLogger.logSkip(
                    codingPath: [],
                    reason: "Dropped invalid array element",
                    rawValue: element.description
                )
            }
        }

        return output
    }
}


// MARK: Dictionary

extension Dictionary: CowRescuePrimitive
where Key == String, Value: CowRescuePrimitive {

    /// Only rescue when source is JSON object.
    ///
    /// Invalid values are dropped deterministically and logged.
    static func cowRescue(from value: AnyCodableValue,
                          using mode: CowRescueMode) -> [String: Value]? {

        guard case .object(let source) = value else {
            return nil
        }

        var output: [String: Value] = [:]
        output.reserveCapacity(source.count)

        for (key, rawValue) in source {
            if let rescued = Value.cowRescue(from: rawValue, using: mode) {
                output[key] = rescued
            } else {
                CowLogger.logSkip(
                    codingPath: [],
                    reason: "Dropped invalid dictionary entry at key '\(key)'",
                    rawValue: rawValue.description
                )
            }
        }

        return output
    }
}
