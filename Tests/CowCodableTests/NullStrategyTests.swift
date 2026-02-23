import XCTest
@testable import CowCodable

final class NullStrategyTests: XCTestCase {
    private struct Model: Codable {
        @CowResilient var id: Int = 0
    }

    func testMissingKeyWithFailStrategyThrows() {
        CowConfiguration.defaultNullStrategy = .fail
        CowConfiguration.defaultRescueStrategy = StrictRescueStrategy.self

        let json = "{}"
        XCTAssertThrowsError(try decode(Model.self, json: json), "Missing key should throw when null strategy is fail.") { error in
            guard case CowDecodingError.missingKey = error else {
                XCTFail("Expected CowDecodingError.missingKey, got \(error).")
                return
            }
        }
    }

    func testExplicitNullWithFailStrategyThrows() {
        CowConfiguration.defaultNullStrategy = .fail
        CowConfiguration.defaultRescueStrategy = StrictRescueStrategy.self

        let json = #"{"id":null}"#
        XCTAssertThrowsError(try decode(Model.self, json: json), "Null value should throw when null strategy is fail.") { error in
            guard case CowDecodingError.nullValue = error else {
                XCTFail("Expected CowDecodingError.nullValue, got \(error).")
                return
            }
        }
    }

    func testMissingKeyWithUseDefaultStrategyUsesDefault() throws {
        CowConfiguration.defaultNullStrategy = .useDefault
        CowConfiguration.defaultRescueStrategy = StrictRescueStrategy.self

        let decoded = try decode(Model.self, json: "{}")
        XCTAssertEqual(decoded.id, 0, "Missing key should use deterministic default when strategy is useDefault.")
    }

    func testNullWithSkipStrategyUsesDefault() throws {
        CowConfiguration.defaultNullStrategy = .skip
        CowConfiguration.defaultRescueStrategy = StrictRescueStrategy.self

        let decoded = try decode(Model.self, json: #"{"id":null}"#)
        XCTAssertEqual(decoded.id, 0, "Null should resolve to deterministic default when strategy is skip.")
    }

    func testWrongTypeStillUsesRescueAndNotNullPath() throws {
        CowConfiguration.defaultNullStrategy = .fail
        CowConfiguration.defaultRescueStrategy = StrictRescueStrategy.self

        let decoded = try decode(Model.self, json: #"{"id":"44"}"#)
        XCTAssertEqual(decoded.id, 44, "Wrong type should follow rescue behavior and not null/missing behavior.")
    }

    private func decode<T: Decodable>(_ type: T.Type, json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
}
