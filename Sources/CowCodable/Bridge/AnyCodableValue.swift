/// File: AnyCodableValue.swift
///
/// This file is part of the CowCodable deterministic decoding SDK project.

import Foundation

/// Internal JSON bridge used by `@CowResilient` to perform deterministic
/// rescue of mismatched payloads.
///
/// `AnyCodableValue` represents a strongly-typed, recursive abstraction over
/// JSON-compatible primitives and containers.
///
/// Supported JSON shapes:
/// - `String`
/// - `Int`
/// - `Double`
/// - `Bool`
/// - `null`
/// - `Array`
/// - `Object` (dictionary with `String` keys)
///
/// This type exists solely to:
///
/// - Provide a safe intermediate decoding layer
/// - Avoid reflection (`Mirror`)
/// - Avoid unsafe dynamic casting
/// - Preserve deterministic rescue behavior
/// - Support nested arrays and objects
///
/// It is `internal` by design. Public consumers interact only with
/// `@CowResilient`, not with this bridge.
///
/// ---------------------------------------------------------------------
/// DESIGN PHILOSOPHY
/// ---------------------------------------------------------------------
///
/// 1. Deterministic
///    - Decoding order is explicit and predictable.
///    - No implicit coercion occurs here.
///    - This type does NOT perform rescue.
///      It only represents raw decoded structure.
///
/// 2. Strict JSON Modeling
///    - Only JSON-compatible types are modeled.
///    - No support for arbitrary `Codable` types.
///    - Keys must be `String`.
///
/// 3. Recursive by Design
///    - Uses `indirect` enum to support nested arrays and objects.
///    - Allows deep container rescue in higher layers.
///
/// ---------------------------------------------------------------------
/// DECODING ORDER
/// ---------------------------------------------------------------------
///
/// Decoding follows this strict order:
///
/// 1. `null`
/// 2. `String`
/// 3. `Int`
/// 4. `Double`
/// 5. `Bool`
/// 6. `[AnyCodableValue]`
/// 7. `[String: AnyCodableValue]`
///
/// The order ensures:
/// - Integer numbers are captured as `Int` before `Double`
/// - Containers are evaluated after primitives
///
/// ---------------------------------------------------------------------
/// THREAD SAFETY
/// ---------------------------------------------------------------------
///
/// - Fully `Sendable`
/// - No shared mutable state
/// - Safe for concurrent decoding
///
/// ---------------------------------------------------------------------
/// PERFORMANCE
/// ---------------------------------------------------------------------
///
/// - O(1) for primitive decode
/// - O(n) for container recursion
/// - No reflection
/// - No heap allocations beyond container storage
///
/// ---------------------------------------------------------------------
/// EXAMPLE (INTERNAL USAGE)
/// ---------------------------------------------------------------------
///
/// ```swift
/// let bridged = try container.decode(AnyCodableValue.self)
/// let rescued = CowRescueEngine.rescue(bridged,
///                                       as: Int.self,
///                                       mode: .strict)
/// ```
///
/// This type is internal infrastructure and not part of the public API.
indirect enum AnyCodableValue: Codable, CustomStringConvertible, Sendable {

    /// JSON string value.
    case string(String)

    /// JSON integer value.
    case int(Int)

    /// JSON floating-point value.
    case double(Double)

    /// JSON boolean value.
    case bool(Bool)

    /// JSON null value.
    case null

    /// JSON array.
    case array([AnyCodableValue])

    /// JSON object with `String` keys.
    case object([String: AnyCodableValue])

    /// Decodes a JSON-compatible value into its strongly typed representation.
    ///
    /// - Parameter decoder: Decoder providing raw JSON data.
    ///
    /// - Throws: `DecodingError.typeMismatch` if the value cannot be represented
    ///   as one of the supported JSON-compatible shapes.
    ///
    /// This initializer does NOT perform any rescue logic.
    /// It only models raw JSON structure.
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        if let value = try? container.decode(Int.self) {
            self = .int(value)
            return
        }
        if let value = try? container.decode(Double.self) {
            self = .double(value)
            return
        }
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }
        if let value = try? container.decode([AnyCodableValue].self) {
            self = .array(value)
            return
        }
        if let value = try? container.decode([String: AnyCodableValue].self) {
            self = .object(value)
            return
        }

        throw DecodingError.typeMismatch(
            AnyCodableValue.self,
            .init(
                codingPath: decoder.codingPath,
                debugDescription: "Unsupported JSON value for AnyCodableValue bridge."
            )
        )
    }

    /// Encodes the bridged value back into JSON-compatible format.
    ///
    /// This maintains structural symmetry with decoding.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }

    /// Human-readable string representation of the value.
    ///
    /// Used primarily for:
    /// - Debug logging
    /// - Rescue explanations
    /// - Demo app output
    ///
    /// Containers are rendered recursively.
    var description: String {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return String(value)
        case .double(let value):
            return String(value)
        case .bool(let value):
            return String(value)
        case .null:
            return "null"
        case .array(let value):
            return "[\(value.map(\.description).joined(separator: ", "))]"
        case .object(let value):
            let content = value
                .sorted(by: { $0.key < $1.key })
                .map { "\($0.key): \($0.value.description)" }
                .joined(separator: ", ")
            return "{\(content)}"
        }
    }

    /// Human-readable type label used in rescue logs.
    ///
    /// Example:
    /// - `"String"`
    /// - `"Int"`
    /// - `"Array"`
    var typeLabel: String {
        switch self {
        case .string: "String"
        case .int: "Int"
        case .double: "Double"
        case .bool: "Bool"
        case .null: "Null"
        case .array: "Array"
        case .object: "Object"
        }
    }
}
