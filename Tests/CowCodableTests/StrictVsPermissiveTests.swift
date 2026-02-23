import XCTest
@testable import CowCodable

final class StrictVsPermissiveTests: XCTestCase {
    private struct Model: Codable {
        @CowResilient var intValue: Int = 0
        @CowResilient var charValue: Character = "\0"
        @CowResilient var list: [Int] = []
    }

    func testScientificNotationIntDiffersByMode() throws {
        let json = #"{"intValue":"1e3","charValue":"A","list":[1]}"#

        CowConfiguration.defaultRescueStrategy = StrictRescueStrategy.self
        CowConfiguration.defaultNullStrategy = .fail
        XCTAssertThrowsError(try decode(Model.self, json: json), "Strict mode should reject scientific notation for Int.")

        CowConfiguration.defaultRescueStrategy = PermissiveRescueStrategy.self
        let permissive = try decode(Model.self, json: json)
        XCTAssertEqual(permissive.intValue, 1000, "Permissive mode should parse scientific notation into Int when integral.")
    }

    func testCharacterFromIntegerOnlyInPermissiveMode() throws {
        let json = #"{"intValue":1,"charValue":65,"list":[1]}"#

        CowConfiguration.defaultRescueStrategy = StrictRescueStrategy.self
        CowConfiguration.defaultNullStrategy = .fail
        XCTAssertThrowsError(try decode(Model.self, json: json), "Strict mode should reject Character from Int.")

        CowConfiguration.defaultRescueStrategy = PermissiveRescueStrategy.self
        let permissive = try decode(Model.self, json: json)
        XCTAssertEqual(permissive.charValue, "A", "Permissive mode should allow Character from integer Unicode scalar.")
    }

    func testSingleValueArrayBehaviorDiffersByMode() throws {
        let json = #"{"intValue":1,"charValue":"A","list":"9"}"#

        CowConfiguration.defaultRescueStrategy = StrictRescueStrategy.self
        CowConfiguration.defaultNullStrategy = .fail
        XCTAssertThrowsError(try decode(Model.self, json: json), "Strict mode should reject single scalar source for array target.")

        CowConfiguration.defaultRescueStrategy = PermissiveRescueStrategy.self
        let permissive = try decode(Model.self, json: json)
        XCTAssertEqual(permissive.list, [9], "Permissive mode should wrap a scalar into one-element array.")
    }

    private func decode<T: Decodable>(_ type: T.Type, json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
}
