import Foundation
import CowCodable

/// Array rescue example for CowCodable.
///
/// Explanation:
/// - Mixed-type arrays keep valid rescued values and drop invalid elements.
/// - Nested arrays apply rescue recursively.
/// - In permissive mode, a single scalar can be wrapped into one-element arrays.
///
/// Expected output:
/// ```
/// numbers=[1, 2, 3]
/// nested=[[1, 2], [3]]
/// scalar->array numbers=[9]
/// ```
private struct ArrayModel: Codable {
    @CowResilient var numbers: [Int] = []
    @CowResilient var nested: [[Int]] = []
}

@main
enum ArrayRescueExample {
    static func main() throws {
        CowConfiguration.defaultRescueStrategy = StrictRescueStrategy.self
        CowConfiguration.defaultNullStrategy = .fail

        let json = """
        {
          "numbers": [1, "2", 3.0, 3.7, "bad"],
          "nested": [[1, "2"], ["3", "x"]]
        }
        """
        let decoded = try JSONDecoder().decode(ArrayModel.self, from: Data(json.utf8))
        print("numbers=\(decoded.numbers)")
        print("nested=\(decoded.nested)")

        CowConfiguration.defaultRescueStrategy = PermissiveRescueStrategy.self
        let scalarJSON = #"{"numbers":"9","nested":[1, "2"]}"#
        let permissive = try JSONDecoder().decode(ArrayModel.self, from: Data(scalarJSON.utf8))
        print("scalar->array numbers=\(permissive.numbers)")
    }
}
