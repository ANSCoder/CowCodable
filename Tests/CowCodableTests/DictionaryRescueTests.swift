import XCTest
@testable import CowCodable

final class DictionaryRescueTests: XCTestCase {
    private struct Model: Codable {
        @CowResilient var intMap: [String: Int] = [:]
        @CowResilient var boolMap: [String: Bool] = [:]
        @CowResilient var nested: [String: [String: Int]] = [:]
    }

    override func setUp() {
        super.setUp()
        CowConfiguration.defaultRescueStrategy = StrictRescueStrategy.self
        CowConfiguration.defaultNullStrategy = .fail
    }

    func testDictionaryRescueDropsInvalidEntries() throws {
        let json = """
        {
          "intMap": { "a": 1, "b": "2", "c": "x" },
          "boolMap": { "t": "true", "f": 0, "bad": "maybe" },
          "nested": {
            "group1": { "x": "1", "y": "invalid" },
            "group2": { "z": 3 }
          }
        }
        """
        let decoded = try decode(Model.self, json: json)
        XCTAssertEqual(decoded.intMap["a"], 1, "Direct dictionary values should decode.")
        XCTAssertEqual(decoded.intMap["b"], 2, "Rescued dictionary values should decode.")
        XCTAssertNil(decoded.intMap["c"], "Invalid dictionary entries must be dropped.")
        XCTAssertEqual(decoded.boolMap["t"], true, "Bool-like String should rescue to Bool.")
        XCTAssertEqual(decoded.boolMap["f"], false, "Numeric zero should rescue to Bool false.")
        XCTAssertNil(decoded.boolMap["bad"], "Invalid Bool string should be dropped.")
        XCTAssertEqual(decoded.nested["group1"]?["x"], 1, "Nested dictionary valid entry should survive.")
        XCTAssertNil(decoded.nested["group1"]?["y"], "Nested dictionary invalid entry should be dropped.")
    }

    func testDictionaryRootTypeMismatchFails() {
        let json = """
        {
          "intMap": ["a", "b"],
          "boolMap": {},
          "nested": {}
        }
        """
        XCTAssertThrowsError(try decode(Model.self, json: json), "Non-object dictionary payload should fail deterministically.") { error in
            XCTAssertNotNil(error, "Expected decoding error for dictionary root type mismatch.")
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
}
