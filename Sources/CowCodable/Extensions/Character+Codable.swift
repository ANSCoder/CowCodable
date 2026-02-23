/// File: Character+Codable.swift
///
/// This file is part of the CowCodable deterministic decoding SDK project.

import Foundation

/// Retroactive `Codable` conformance for `Character`.
///
/// Swift's standard library does not provide built-in `Codable` conformance
/// for `Character`. Since `@CowResilient` supports deterministic rescue for
/// primitive types — including `Character` — this extension enables
/// JSON decoding and encoding of single-character string values.
///
/// ---------------------------------------------------------------------
/// DESIGN PHILOSOPHY
/// ---------------------------------------------------------------------
///
/// A `Character` in JSON must be represented as a single-character `String`.
///
/// This implementation:
/// - Accepts only trimmed strings of length exactly 1.
/// - Rejects empty strings.
/// - Rejects multi-character strings.
/// - Trims leading and trailing whitespace before validation.
/// - Does NOT attempt to infer characters from numeric Unicode scalars.
///   (Unicode scalar rescue is handled at the rescue layer, not here.)
///
/// This keeps decoding:
/// - Deterministic
/// - Predictable
/// - Strict by default
///
/// ---------------------------------------------------------------------
/// DECODING RULES
/// ---------------------------------------------------------------------
///
/// Accepted:
/// - `"A"`
/// - `"  A  "` → trimmed → `"A"`
///
/// Rejected:
/// - `""`
/// - `"AB"`
/// - `"  "`
///
/// If invalid, decoding throws `DecodingError.typeMismatch`.
///
/// ---------------------------------------------------------------------
/// THREAD SAFETY
/// ---------------------------------------------------------------------
///
/// Stateless implementation.
/// Safe for concurrent decoding.
///
/// ---------------------------------------------------------------------
/// PERFORMANCE
/// ---------------------------------------------------------------------
///
/// O(1) trimming and validation.
/// No reflection.
/// No heap allocations beyond standard string handling.
///
/// ---------------------------------------------------------------------
/// EXAMPLE
/// ---------------------------------------------------------------------
///
/// ```swift
/// struct Model: Codable {
///     let grade: Character
/// }
///
/// let json = #"{"grade": "A"}"#
/// let model = try JSONDecoder().decode(Model.self, from: Data(json.utf8))
/// ```
///
/// This extension is required for deterministic `Character` support
/// within CowCodable’s rescue engine.
extension Character: @retroactive Codable {

    /// Decodes a `Character` from a single-character JSON string.
    ///
    /// - Parameter decoder: Decoder supplying a JSON value.
    ///
    /// - Throws: `DecodingError.typeMismatch` if the value is not
    ///   a single-character string after trimming whitespace.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count == 1, let character = trimmed.first else {
            throw DecodingError.typeMismatch(
                Character.self,
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Character expects a single-character String."
                )
            )
        }

        self = character
    }

    /// Encodes the `Character` as a single-character JSON string.
    ///
    /// Encoding is symmetric with decoding behavior.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(self))
    }
}
