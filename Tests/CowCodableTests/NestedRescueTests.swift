import XCTest
@testable import CowCodable

final class NestedRescueTests: XCTestCase {
    private struct Model: Codable {
        @CowResilient var payload: [[String: [Int]]] = []
    }

    override func setUp() {
        super.setUp()
        CowConfiguration.defaultRescueStrategy = StrictRescueStrategy.self
        CowConfiguration.defaultNullStrategy = .fail
    }

    func testNestedArraysAndDictionariesRescueDeterministically() throws {
        let json = """
        {
          "payload": [
            { "first": [1, "2", "bad"] },
            "fully-invalid-object",
            { "second": [3, 4] }
          ]
        }
        """
        let decoded = try decode(Model.self, json: json)
        XCTAssertEqual(decoded.payload.count, 2, "Fully invalid nested object should be dropped from outer array.")
        XCTAssertEqual(decoded.payload[0]["first"], [1, 2], "Nested invalid values should be dropped while valid values remain.")
        XCTAssertEqual(decoded.payload[1]["second"], [3, 4], "Valid nested values should decode unchanged.")
    }

    private func decode<T: Decodable>(_ type: T.Type, json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
}
