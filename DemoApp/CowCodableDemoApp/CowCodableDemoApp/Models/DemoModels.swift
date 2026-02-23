/// File: DemoModels.swift
///
/// Demo application source for the CowCodable SDK showcase.

import CowCodable
import Foundation

/// Codable model fixtures for decoding presets.
///
/// Purpose: define strongly typed sample decode surfaces for each corruption scenario.
/// Design philosophy: keep model definitions simple and focused on resilience behavior.
/// Thread safety: value types with `@CowResilient` defaults are safe for concurrent decode use.
/// Deterministic behavior: fixed defaults ensure stable fallback outcomes.
/// Example usage: selected in `DecodeViewModel.decodePreset` based on current preset.

// MARK: - Primitive

internal struct PrimitiveCorruptionModel: Codable {
    @CowResilient internal var name: String = ""
    @CowResilient internal var age: Int = 0
    @CowResilient internal var score: Double = 0
    @CowResilient internal var isActive: Bool = false
    @CowResilient internal var initial: Character = "\0"
    @CowResilient internal var ratio: Float = 0
}

// MARK: - Array

internal struct ArrayCorruptionModel: Codable {
    @CowResilient internal var numbers: [Int] = []
    @CowResilient internal var nested: [[Int]] = []
}

// MARK: - Dictionary

internal struct DictionaryCorruptionModel: Codable {
    @CowResilient internal var intMap: [String: Int] = [:]
    @CowResilient internal var boolMap: [String: Bool] = [:]
    @CowResilient internal var nestedMap: [String: [String: Int]] = [:]
}

// MARK: - Nested

internal struct NestedComplexModel: Codable {
    @CowResilient internal var payload: [[String: [Int]]] = []
}

// MARK: - Null Edge Case

internal struct NullEdgeCaseModel: Codable {
    @CowResilient internal var id: Int = 0
    @CowResilient internal var title: String = ""
}

// MARK: - Overflow

internal struct OverflowCaseModel: Codable {
    @CowResilient internal var count: Int = 0
    @CowResilient internal var weight: Float = 0
}

// MARK: - Strict vs Permissive

internal struct StrictPermissiveCaseModel: Codable {
    @CowResilient internal var age: Int = 0
    @CowResilient internal var initial: Character = "\0"
    @CowResilient internal var ratio: Float = 0
    @CowResilient internal var values: [Int] = []
}
