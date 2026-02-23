import XCTest
@testable import CowCodable

final class ArrayRescueTests: XCTestCase {
    private struct Model: Codable {
        @CowResilient var numbers: [Int] = []
        @CowResilient var nested: [[Int]] = []
    }

    override func setUp() {
        super.setUp()
        CowConfiguration.defaultNullStrategy = .fail
    }

    func testMixedTypeArrayDropsInvalidElements() throws {
        CowConfiguration.defaultRescueStrategy = StrictRescueStrategy.self
        let json = """
        {
          "numbers": [1, "2", 3.0, 4.5, "x"],
          "nested": [[1, "2"], ["3", "invalid"], [4]]
        }
        """
        let decoded = try decode(Model.self, json: json)
        XCTAssertEqual(decoded.numbers, [1, 2, 3], "Invalid array values must be dropped deterministically.")
        XCTAssertEqual(decoded.nested, [[1, 2], [3], [4]], "Invalid nested values must be dropped while preserving valid order.")
    }

    func testSingleValueInsteadOfArrayEdgeCase() throws {
        CowConfiguration.defaultRescueStrategy = PermissiveRescueStrategy.self
        let json = """
        {
          "numbers": "5",
          "nested": [1, 2, 3]
        }
        """
        let decoded = try decode(Model.self, json: json)
        XCTAssertEqual(decoded.numbers, [5], "Permissive mode should wrap a single value into one-element array.")
        XCTAssertEqual(decoded.nested, [[1], [2], [3]], "Permissive mode should wrap scalar values for nested array targets.")
    }

    func testSingleValueInsteadOfArrayFailsInStrictMode() {
        CowConfiguration.defaultRescueStrategy = StrictRescueStrategy.self
        let json = """
        {
          "numbers": "5",
          "nested": [1]
        }
        """
        XCTAssertThrowsError(try decode(Model.self, json: json), "Strict mode should reject non-array source for array target.") { error in
            XCTAssertNotNil(error, "Error should exist for strict array source mismatch.")
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
}
