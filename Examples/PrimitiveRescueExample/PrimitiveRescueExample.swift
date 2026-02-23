import Foundation
import CowCodable

/// Primitive rescue example for CowCodable.
///
/// Explanation:
/// - `name` rescues from Int to String.
/// - `age` rescues from String with whitespace trimming.
/// - `score` rescues scientific notation.
/// - `isActive` rescues bool-like string.
/// - `initial` rescues from single-character string.
/// - Overflow and strict NaN/Infinity behavior are shown with failing payloads.
///
/// Expected output:
/// ```
/// Primitive decoded: name=12345 age=32 score=1000.0 active=true initial=Z
/// Overflow error: ...
/// Strict NaN error: ...
/// Permissive NaN accepted: true
/// ```
private struct PrimitiveModel: Codable {
    @CowResilient var name: String = ""
    @CowResilient var age: Int = 0
    @CowResilient var score: Double = 0
    @CowResilient var isActive: Bool = false
    @CowResilient var initial: Character = "\0"
}

@main
enum PrimitiveRescueExample {
    static func main() throws {
        CowConfiguration.defaultRescueStrategy = StrictRescueStrategy.self
        CowConfiguration.defaultNullStrategy = .fail

        let json = """
        {
          "name": 12345,
          "age": " 32 ",
          "score": "1e3",
          "isActive": "yes",
          "initial": "Z"
        }
        """
        let model = try JSONDecoder().decode(PrimitiveModel.self, from: Data(json.utf8))
        print("Primitive decoded: name=\(model.name) age=\(model.age) score=\(model.score) active=\(model.isActive) initial=\(model.initial)")

        let overflow = #"{"name":"x","age":"999999999999999999999999","score":"1","isActive":"true","initial":"A"}"#
        do {
            _ = try JSONDecoder().decode(PrimitiveModel.self, from: Data(overflow.utf8))
        } catch {
            print("Overflow error: \(error)")
        }

        let strictNaN = #"{"name":"x","age":"1","score":"NaN","isActive":"true","initial":"A"}"#
        do {
            _ = try JSONDecoder().decode(PrimitiveModel.self, from: Data(strictNaN.utf8))
        } catch {
            print("Strict NaN error: \(error)")
        }

        CowConfiguration.defaultRescueStrategy = PermissiveRescueStrategy.self
        let permissive = try JSONDecoder().decode(PrimitiveModel.self, from: Data(strictNaN.utf8))
        print("Permissive NaN accepted: \(permissive.score.isNaN)")
    }
}
