import XCTest
@testable import CowCodable

final class ConcurrencyTests: XCTestCase {
    private struct Model: Codable {
        @CowResilient var value: Int = 0
        @CowResilient var list: [Int] = []
    }

    override func setUp() {
        super.setUp()
        CowConfiguration.defaultRescueStrategy = PermissiveRescueStrategy.self
        CowConfiguration.defaultNullStrategy = .fail
    }

    func testConcurrentDecodingIsStable() async throws {
        let payload = #"{"value":"1e2","list":"9"}"#
        let iterations = 300

        let results = try await withThrowingTaskGroup(of: Model.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    try JSONDecoder().decode(Model.self, from: Data(payload.utf8))
                }
            }

            var output: [Model] = []
            output.reserveCapacity(iterations)
            for try await element in group {
                output.append(element)
            }
            return output
        }

        XCTAssertEqual(results.count, iterations, "All concurrent tasks should finish successfully.")
        XCTAssertTrue(results.allSatisfy { $0.value == 100 && $0.list == [9] }, "Concurrent decode results should be deterministic.")
    }
}
