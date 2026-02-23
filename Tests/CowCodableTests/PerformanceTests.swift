import XCTest
@testable import CowCodable

/// Performance benchmark suite for CowCodable.
///
/// | Input Size | Count | Expected Complexity |
/// |-----------:|------:|---------------------|
/// | Small      | 100   | O(n) |
/// | Medium     | 2,000 | O(n) |
/// | Large      | 10,000| O(n) |
final class PerformanceTests: XCTestCase {
    private struct Model: Codable {
        @CowResilient var values: [Int] = []
    }

    override func setUp() {
        super.setUp()
        CowConfiguration.defaultRescueStrategy = StrictRescueStrategy.self
        CowConfiguration.defaultNullStrategy = .fail
    }

    func testSmallInputPerformance() throws {
        let data = makeData(count: 100)
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            do {
                _ = try JSONDecoder().decode(Model.self, from: data)
            } catch {
                XCTFail("Small benchmark decode should not fail: \(error)")
            }
        }
    }

    func testMediumInputPerformance() throws {
        let data = makeData(count: 2_000)
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            do {
                _ = try JSONDecoder().decode(Model.self, from: data)
            } catch {
                XCTFail("Medium benchmark decode should not fail: \(error)")
            }
        }
    }

    func testLargeInputPerformance() throws {
        let data = makeData(count: 10_000)
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            do {
                _ = try JSONDecoder().decode(Model.self, from: data)
            } catch {
                XCTFail("Large benchmark decode should not fail: \(error)")
            }
        }
    }

    private func makeData(count: Int) -> Data {
        precondition(count > 0, "Benchmark count must be positive.")
        let values = (0..<count).map { $0.isMultiple(of: 13) ? "\"\($0)\"" : "\($0)" }
        let json = #"{"values":[\#(values.joined(separator: ","))]}"#
        return Data(json.utf8)
    }
}
