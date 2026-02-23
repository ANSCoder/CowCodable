/// File: JSONSamples.swift
///
/// Demo application source for the CowCodable SDK showcase.

import Foundation

/// Preset JSON payload catalog for deterministic demo scenarios.
///
/// Purpose: provide reproducible input fixtures for each showcased rescue behavior.
/// Design philosophy: keep examples explicit, readable, and directly editable by users.
/// Thread safety: immutable enum values and strings are value-type safe.
/// Deterministic behavior: each case has fixed JSON and fixed explanation text.
/// Example usage: bind `JSONPreset.allCases` to a picker and read `sampleJSON`.
internal enum JSONPreset: String, CaseIterable, Identifiable {
    case primitiveCorruption = "Primitive Corruption"
    case arrayCorruption = "Array Corruption"
    case dictionaryCorruption = "Dictionary Corruption"
    case nestedComplex = "Nested Complex"
    case nullEdgeCase = "Null Edge Case"
    case overflowCase = "Overflow Case"
    case strictVsPermissiveCase = "Strict vs Permissive Case"

    // MARK: - Identity

    internal var id: String {
        rawValue
    }

    // MARK: - Sample Payloads

    internal var sampleJSON: String {
        switch self {
        case .primitiveCorruption:
            return #"""
{
  "name": 12345,
  "age": " 32 ",
  "score": "1e3",
  "isActive": "yes",
  "initial": "Z",
  "ratio": "NaN"
}
"""#
        case .arrayCorruption:
            return #"""
{
  "numbers": [1, "2", 3.0, 3.7, "bad"],
  "nested": [[1, "2"], ["3", "x"], 9]
}
"""#
        case .dictionaryCorruption:
            return #"""
{
  "intMap": {"a": 1, "b": "2", "c": "bad"},
  "boolMap": {"on": "true", "off": 0, "unknown": "maybe"},
  "nestedMap": {
    "group1": {"x": "1", "y": "bad"},
    "group2": {"z": 3}
  }
}
"""#
        case .nestedComplex:
            return #"""
{
  "payload": [
    {"good": [1, "2", "bad"]},
    "fully-invalid-object",
    {"other": [3, 4, "5"]}
  ]
}
"""#
        case .nullEdgeCase:
            return #"""
{
  "id": null,
  "title": 123
}
"""#
        case .overflowCase:
            return #"""
{
  "count": "999999999999999999999999",
  "weight": "1e1000"
}
"""#
        case .strictVsPermissiveCase:
            return #"""
{
  "age": "1e3",
  "initial": 65,
  "ratio": "Infinity",
  "values": "7"
}
"""#
        }
    }

    // MARK: - Explanations

    internal var explanation: String {
        switch self {
        case .primitiveCorruption:
            return "Primitive drift across numbers, booleans, and character values."
        case .arrayCorruption:
            return "Mixed arrays demonstrate rescued values and skipped invalid elements."
        case .dictionaryCorruption:
            return "Dictionary entries illustrate key/value rescue and deterministic dropping."
        case .nestedComplex:
            return "Nested objects show multilevel rescue while preserving valid structure."
        case .nullEdgeCase:
            return "Switch null strategy to compare fail, useDefault, and skip behavior."
        case .overflowCase:
            return "Large numeric inputs show deterministic overflow handling and failures."
        case .strictVsPermissiveCase:
            return "Toggle strict and permissive to compare conversion boundaries on identical JSON."
        }
    }
}
