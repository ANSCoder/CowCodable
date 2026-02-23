import Foundation
import CowCodable

/// Nested resilience example for CowCodable.
///
/// Explanation:
/// - Nested arrays and dictionaries are rescued recursively.
/// - One fully invalid nested object is removed.
/// - Valid values are preserved with original order.
///
/// Expected output:
/// ```
/// payload=[["good": [1, 2]], ["other": [3, 4]]]
/// ```
private struct NestedModel: Codable {
    @CowResilient var payload: [[String: [Int]]] = []
}

@main
enum NestedModelExample {
    static func main() throws {
        CowConfiguration.defaultRescueStrategy = StrictRescueStrategy.self
        CowConfiguration.defaultNullStrategy = .fail

        let json = """
        {
          "payload": [
            { "good": [1, "2", "bad"] },
            "completely-invalid",
            { "other": [3, 4] }
          ]
        }
        """
        let decoded = try JSONDecoder().decode(NestedModel.self, from: Data(json.utf8))
        print("payload=\(decoded.payload)")
    }
}
