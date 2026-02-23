import XCTest
@testable import CowCodable

final class PrimitiveRescueTests: XCTestCase {
    private struct Model: Codable {
        @CowResilient var stringValue: String = ""
        @CowResilient var intValue: Int = 0
        @CowResilient var doubleValue: Double = 0
        @CowResilient var floatValue: Float = 0
        @CowResilient var boolValue: Bool = false
        @CowResilient var charValue: Character = "\0"
    }

    override func setUp() {
        super.setUp()
        CowConfiguration.defaultRescueStrategy = StrictRescueStrategy.self
        CowConfiguration.defaultNullStrategy = .fail
    }

    func testPrimitiveRescueInStrictMode() throws {
        let json = """
        {
          "stringValue": 123,
          "intValue": "42",
          "doubleValue": "12.5",
          "floatValue": "3.25",
          "boolValue": "yes",
          "charValue": "A"
        }
        """

        let decoded = try decode(Model.self, json: json)
        XCTAssertEqual(decoded.stringValue, "123", "Strict mode should rescue String from Int.")
        XCTAssertEqual(decoded.intValue, 42, "Strict mode should rescue Int from numeric String.")
        XCTAssertEqual(decoded.doubleValue, 12.5, accuracy: 0.000_001, "Strict mode should rescue Double from numeric String.")
        XCTAssertEqual(decoded.floatValue, 3.25, accuracy: 0.000_001, "Strict mode should rescue Float from numeric String.")
        XCTAssertTrue(decoded.boolValue, "Strict mode should rescue Bool from bool-like String.")
        XCTAssertEqual(decoded.charValue, "A", "Strict mode should rescue Character from single-char String.")
    }

    func testWhitespaceTrimmingAndScientificNotationPermissive() throws {
        CowConfiguration.defaultRescueStrategy = PermissiveRescueStrategy.self

        let json = """
        {
          "stringValue": "  raw  ",
          "intValue": " 1e3 ",
          "doubleValue": " 2.5e2 ",
          "floatValue": " 5.5 ",
          "boolValue": "  true ",
          "charValue": 65
        }
        """

        let decoded = try decode(Model.self, json: json)
        XCTAssertEqual(decoded.intValue, 1000, "Permissive mode should parse scientific notation for Int when integral.")
        XCTAssertEqual(decoded.doubleValue, 250, accuracy: 0.000_001, "Permissive mode should parse scientific notation for Double.")
        XCTAssertEqual(decoded.floatValue, 5.5, accuracy: 0.000_001, "Permissive mode should trim whitespace for Float parsing.")
        XCTAssertTrue(decoded.boolValue, "Permissive mode should trim whitespace for Bool parsing.")
        XCTAssertEqual(decoded.charValue, "A", "Permissive mode should allow Character from ASCII scalar Int.")
    }

    func testAmbiguousNumericCoercionFails() {
        let json = """
        {
          "stringValue": "ok",
          "intValue": 12.3,
          "doubleValue": 1.0,
          "floatValue": 1.0,
          "boolValue": true,
          "charValue": "B"
        }
        """
        XCTAssertThrowsError(try decode(Model.self, json: json), "Ambiguous 12.3 -> Int conversion must fail.") { error in
            XCTAssertNotNil(error, "Error should be provided for ambiguous conversion.")
        }
    }

    func testCharacterRulesRejectInvalidValues() {
        let json = """
        {
          "stringValue": "ok",
          "intValue": 1,
          "doubleValue": 1.0,
          "floatValue": 1.0,
          "boolValue": false,
          "charValue": "AB"
        }
        """
        XCTAssertThrowsError(try decode(Model.self, json: json), "Character rescue should fail for multi-character String.") { error in
            XCTAssertNotNil(error, "Error should be provided for invalid Character rescue.")
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
}
