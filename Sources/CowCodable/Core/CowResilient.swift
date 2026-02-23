/// File: CowResilient.swift
///
/// This file is part of the CowCodable deterministic decoding SDK project.

import Foundation

// MARK: - CowResilient

/// Universal deterministic resilience wrapper for primitive and primitive-container decoding.
///
/// `@CowResilient` is the sole public property wrapper of CowCodable.
/// It enables controlled, explicit rescue of malformed JSON values while
/// preserving deterministic and explainable behavior.
///
/// ---------------------------------------------------------------------
/// SUPPORTED TARGETS
/// ---------------------------------------------------------------------
///
/// Primitive:
/// - `String`
/// - `Int`
/// - `Double`
/// - `Float`
/// - `Bool`
/// - `Character`
///
/// Containers:
/// - Arrays of supported targets (including nested arrays)
/// - `[String: SupportedTarget]` (including nested dictionaries)
///
/// ---------------------------------------------------------------------
/// UNSUPPORTED TARGETS
/// ---------------------------------------------------------------------
///
/// - Arbitrary `Codable` model rescue via reflection
/// - Ambiguous coercions (e.g., `12.3 → Int`)
/// - Implicit structural transformation beyond defined strategies
///
/// ---------------------------------------------------------------------
/// DETERMINISTIC GUARANTEES
/// ---------------------------------------------------------------------
///
/// For any field:
///
/// Same:
/// - JSON payload
/// - `CowNullStrategy`
/// - Rescue strategy (Strict/Permissive)
///
/// Always produces the same result.
///
/// Ambiguous numeric conversions fail.
/// Invalid array/dictionary elements are dropped deterministically and logged.
/// Structural and type failures are classified distinctly.
///
/// ---------------------------------------------------------------------
/// DECODE FLOW
/// ---------------------------------------------------------------------
///
/// 1. Capture current global configuration.
/// 2. If value is `null` → apply `CowNullStrategy`.
/// 3. Attempt direct decode into `Value`.
/// 4. Bridge to `AnyCodableValue`.
/// 5. Attempt deterministic rescue.
/// 6. If rescue fails → emit log + throw `CowDecodingError`.
///
/// ---------------------------------------------------------------------
/// THREAD SAFETY
/// ---------------------------------------------------------------------
///
/// - Value type.
/// - `Sendable` when `Value` is `Sendable`.
/// - Safe for concurrent decoding.
/// - Global configuration reads are lock-protected.
///
/// ---------------------------------------------------------------------
/// PERFORMANCE
/// ---------------------------------------------------------------------
///
/// - O(1) for primitive rescue.
/// - O(n) for arrays/dictionaries.
/// - No reflection.
/// - No dynamic casting outside defined rules.
///
/// ---------------------------------------------------------------------
/// EXAMPLE
/// ---------------------------------------------------------------------
///
/// ```swift
/// struct Profile: Codable {
///     @CowResilient var id: String = ""
///     @CowResilient var score: Double = 0
/// }
/// ```
@propertyWrapper
public struct CowResilient<Value: Codable>: Codable {

    /// Decoded or deterministically rescued value.
    public var wrappedValue: Value

    /// Null handling policy captured at initialization.
    ///
    /// Important: This captures configuration at decode time,
    /// not dynamically afterward.
    public let nullStrategy: CowNullStrategy

    /// Active rescue strategy name captured at initialization.
    public let rescueStrategyName: String

    // MARK: Initialization

    /// Creates wrapper with explicit fallback and optional strategy overrides.
    ///
    /// - Parameters:
    ///   - wrappedValue: Initial fallback value.
    ///   - nullStrategy: Missing/null behavior. Defaults to global configuration.
    ///   - rescueStrategy: Rescue strategy type. Defaults to global configuration.
    ///
    /// This initializer does not perform decoding.
    public init(
        wrappedValue: Value,
        nullStrategy: CowNullStrategy = CowConfiguration.defaultNullStrategy,
        rescueStrategy: (any CowRescueStrategy.Type) = CowConfiguration.defaultRescueStrategy
    ) {
        self.wrappedValue = wrappedValue
        self.nullStrategy = nullStrategy
        self.rescueStrategyName = rescueStrategy.name
    }

    /// Decodes wrapped value with deterministic rescue semantics.
    ///
    /// - Parameter decoder: Decoder for the current field.
    /// - Throws:
    ///   - `CowDecodingError.missingKey`
    ///   - `CowDecodingError.nullValue`
    ///   - `CowDecodingError.invalidType`
    ///   - `CowDecodingError.defaultValueUnavailable`
    public init(from decoder: any Decoder) throws {

        let nullStrategy = CowConfiguration.defaultNullStrategy
        let rescueMode = CowConfiguration.defaultRescueMode

        self.nullStrategy = nullStrategy
        self.rescueStrategyName = CowConfiguration.defaultRescueStrategy.name

        let container = try decoder.singleValueContainer()

        // Explicit null
        if container.decodeNil() {
            wrappedValue = try Self.resolveDefault(
                strategy: nullStrategy,
                expectedType: Value.self,
                codingPath: decoder.codingPath,
                reason: .null
            )
            return
        }

        // Direct decode
        if let direct = try? container.decode(Value.self) {
            wrappedValue = direct
            return
        }

        // Bridge and rescue
        let bridgeValue = try container.decode(AnyCodableValue.self)

        guard let rescued = CowRescueEngine.rescue(
            bridgeValue,
            as: Value.self,
            mode: rescueMode
        ) else {

            CowLogger.logFailure(
                codingPath: decoder.codingPath,
                reason: "Unable to rescue \(bridgeValue.typeLabel) into \(Value.self)",
                rawValue: bridgeValue.description
            )

            throw CowDecodingError.invalidType(
                codingPath: decoder.codingPath,
                expectedType: String(describing: Value.self),
                actualType: bridgeValue.typeLabel,
                rawValue: bridgeValue.description
            )
        }

        wrappedValue = rescued

        CowLogger.logRescue(
            expected: String(describing: Value.self),
            actual: bridgeValue.typeLabel,
            value: bridgeValue.description,
            codingPath: decoder.codingPath
        )
    }

    /// Encodes wrapped value using standard single-value semantics.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }

    // MARK: Missing / Null Resolution

    enum MissingOrNullReason {
        case missing
        case null
    }

    /// Resolves structural missing/null cases according to `CowNullStrategy`.
    static func resolveDefault(
        strategy: CowNullStrategy,
        expectedType: Value.Type,
        codingPath: [CodingKey],
        reason: MissingOrNullReason
    ) throws -> Value {

        switch strategy {

        case .fail:
            switch reason {
            case .missing:
                CowLogger.logFailure(
                    codingPath: codingPath,
                    reason: "Missing key",
                    rawValue: "<missing>"
                )
                throw CowDecodingError.missingKey(
                    codingPath: codingPath,
                    expectedType: String(describing: expectedType)
                )

            case .null:
                CowLogger.logFailure(
                    codingPath: codingPath,
                    reason: "Null value",
                    rawValue: "null"
                )
                throw CowDecodingError.nullValue(
                    codingPath: codingPath,
                    expectedType: String(describing: expectedType),
                    strategy: strategy
                )
            }

        case .useDefault, .skip:

            guard let fallback = CowRescueEngine.defaultValue(for: expectedType) else {

                CowLogger.logFailure(
                    codingPath: codingPath,
                    reason: "Missing default value provider",
                    rawValue: "<none>"
                )

                throw CowDecodingError.defaultValueUnavailable(
                    expectedType: String(describing: expectedType)
                )
            }

            let reasonMessage = (reason == .missing) ? "missing key" : "null value"

            CowLogger.logSkip(
                codingPath: codingPath,
                reason: "Applied default due to \(reasonMessage)",
                rawValue: String(describing: fallback)
            )

            return fallback
        }
    }
}

// MARK: - Sendable Conformance

extension CowResilient: Sendable where Value: Sendable {}


// MARK: - Keyed Decoding Support

/// Keyed decoding support for `@CowResilient` that distinguishes:
/// - Missing key
/// - Explicit null
///
/// This extension ensures structural issues are handled before
/// entering single-value decoding logic.
public extension KeyedDecodingContainer {

    func decode<T>(
        _ type: CowResilient<T>.Type,
        forKey key: Key
    ) throws -> CowResilient<T> where T: Codable {

        let nullStrategy = CowConfiguration.defaultNullStrategy
        let strategy = CowConfiguration.defaultRescueStrategy

        // Missing key
        if !contains(key) {
            let defaultValue = try CowResilient<T>.resolveDefault(
                strategy: nullStrategy,
                expectedType: T.self,
                codingPath: codingPath + [key],
                reason: .missing
            )
            return CowResilient<T>(
                wrappedValue: defaultValue,
                nullStrategy: nullStrategy,
                rescueStrategy: strategy
            )
        }

        // Explicit null
        if try decodeNil(forKey: key) {
            let defaultValue = try CowResilient<T>.resolveDefault(
                strategy: nullStrategy,
                expectedType: T.self,
                codingPath: codingPath + [key],
                reason: .null
            )
            return CowResilient<T>(
                wrappedValue: defaultValue,
                nullStrategy: nullStrategy,
                rescueStrategy: strategy
            )
        }

        // Standard decode path
        return try decodeIfPresent(type, forKey: key)
            ?? CowResilient<T>(
                wrappedValue: try CowResilient<T>.resolveDefault(
                    strategy: nullStrategy,
                    expectedType: T.self,
                    codingPath: codingPath + [key],
                    reason: .missing
                ),
                nullStrategy: nullStrategy,
                rescueStrategy: strategy
            )
    }
}
