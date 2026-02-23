import Foundation
import CowCodable

/// Dictionary rescue example for CowCodable.
///
/// Explanation:
/// - `[String: Int]` rescues numeric strings and drops invalid values.
/// - `[String: Bool]` rescues bool-like values and drops invalid values.
/// - Nested dictionaries apply the same deterministic dropping behavior.
///
/// Expected output:
/// ```
/// intMap=["a": 1, "b": 2]
/// boolMap=["on": true, "off": false]
/// nested=["group": ["x": 1]]
/// ```
private struct DictionaryModel: Codable {
    @CowResilient var intMap: [String: Int] = [:]
    @CowResilient var boolMap: [String: Bool] = [:]
    @CowResilient var nested: [String: [String: Int]] = [:]
}

@main
enum DictionaryRescueExample {
    static func main() throws {
        CowConfiguration.defaultRescueStrategy = StrictRescueStrategy.self
        CowConfiguration.defaultNullStrategy = .fail

        let json = """
        {
          "intMap": { "a": 1, "b": "2", "c": "bad" },
          "boolMap": { "on": "true", "off": 0, "maybe": "idk" },
          "nested": { "group": { "x": "1", "y": "bad" } }
        }
        """
        let decoded = try JSONDecoder().decode(DictionaryModel.self, from: Data(json.utf8))
        print("intMap=\(decoded.intMap)")
        print("boolMap=\(decoded.boolMap)")
        print("nested=\(decoded.nested)")
    }
}
