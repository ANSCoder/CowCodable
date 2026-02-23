import XCTest
@testable import CowCodable

final class OverflowTests: XCTestCase {
    private struct IntModel: Codable {
        @CowResilient var value: Int = 0
    }

    private struct FloatModel: Codable {
        @CowResilient var value: Float = 0
    }

    override func setUp() {
        super.setUp()
        CowConfiguration.defaultNullStrategy = .fail
        CowConfiguration.defaultRescueStrategy = StrictRescueStrategy.self
    }

    func testLargeIntegerOverflowFails() {
        let json = #"{"value":"9999999999999999999999999999999"}"#
        XCTAssertThrowsError(try decode(IntModel.self, json: json), "Integer overflow should fail deterministically.") { error in
            XCTAssertNotNil(error, "Overflow must produce an actionable decoding error.")
        }
    }

    func testFloatNanAndInfinityBehavior() {
        let jsonNaN = #"{"value":"NaN"}"#
        XCTAssertThrowsError(try decode(FloatModel.self, json: jsonNaN), "Strict mode must reject NaN String.") { error in
            XCTAssertNotNil(error, "NaN rejection should surface decoding error.")
        }

        CowConfiguration.defaultRescueStrategy = PermissiveRescueStrategy.self
        XCTAssertNoThrow(try decode(FloatModel.self, json: jsonNaN), "Permissive mode should allow NaN String.")
        XCTAssertNoThrow(try decode(FloatModel.self, json: #"{"value":"Infinity"}"#), "Permissive mode should allow Infinity String.")
    }

    private func decode<T: Decodable>(_ type: T.Type, json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
}
