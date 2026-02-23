import Foundation
import CowCodable

/// Null strategy example for CowCodable.
///
/// Explanation:
/// - `.fail` throws for missing and null values.
/// - `.useDefault` applies deterministic default values.
/// - `.skip` behaves like defaulting for singular values while keeping decode flow alive.
/// - Wrong types still follow rescue rules and are not treated as missing/null.
///
/// Expected output:
/// ```
/// fail(missing)=...
/// fail(null)=...
/// useDefault(missing)=0
/// skip(null)=0
/// wrongTypeRescued=42
/// ```
private struct NullModel: Codable {
    @CowResilient var id: Int = 0
}

@main
enum NullStrategyExample {
    static func main() throws {
        CowConfiguration.defaultRescueStrategy = StrictRescueStrategy.self

        CowConfiguration.defaultNullStrategy = .fail
        do {
            _ = try JSONDecoder().decode(NullModel.self, from: Data("{}".utf8))
        } catch {
            print("fail(missing)=\(error)")
        }
        do {
            _ = try JSONDecoder().decode(NullModel.self, from: Data(#"{"id":null}"#.utf8))
        } catch {
            print("fail(null)=\(error)")
        }

        CowConfiguration.defaultNullStrategy = .useDefault
        let useDefault = try JSONDecoder().decode(NullModel.self, from: Data("{}".utf8))
        print("useDefault(missing)=\(useDefault.id)")

        CowConfiguration.defaultNullStrategy = .skip
        let skip = try JSONDecoder().decode(NullModel.self, from: Data(#"{"id":null}"#.utf8))
        print("skip(null)=\(skip.id)")

        CowConfiguration.defaultNullStrategy = .fail
        let wrongType = try JSONDecoder().decode(NullModel.self, from: Data(#"{"id":"42"}"#.utf8))
        print("wrongTypeRescued=\(wrongType.id)")
    }
}
