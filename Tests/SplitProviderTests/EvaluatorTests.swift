//  Created by Martin Cardozo on 24/10/2025.

import XCTest
import OpenFeature
@testable import SplitProvider

final class EvaluatorTests: XCTestCase {
    
    private func makeEvaluator(with treatment: String) -> Evaluator {
        let client = ClientMock()
        client.treatment = treatment
        return Evaluator(splitClient: client)
    }
    
    func testBoolTrue() {
        let SUT = makeEvaluator(with: "true")
        let result = SUT.evaluate(key: "flag", defaultValue: false, context: nil)
        XCTAssertEqual(result.value, true)
    }
    
    func testBoolFalse() {
        let SUT = makeEvaluator(with: "FA LSE")
        let result = SUT.evaluate(key: "flag", defaultValue: true, context: nil)
        XCTAssertEqual(result.value, false)
    }
    
    func testInt64() {
        let SUT = makeEvaluator(with: "123")
        let result = SUT.evaluate(key: "flag", defaultValue: Int64(0), context: nil)
        XCTAssertEqual(result.value, 123)
    }
    
    func testDouble() {
        let SUT = makeEvaluator(with: "3.14")
        let result = SUT.evaluate(key: "flag", defaultValue: 0.0, context: nil)
        XCTAssertEqual(result.value, 3.14, accuracy: 0.0001)
    }
    
    func testString() {
        let SUT = makeEvaluator(with: "banana")
        let result = SUT.evaluate(key: "flag", defaultValue: "default", context: nil)
        XCTAssertEqual(result.value, "banana")
    }
    
    func testValue() {
        let SUT = makeEvaluator(with: "json_string")
        let result = SUT.evaluate(key: "flag", defaultValue: OpenFeature.Value.string("default"), context: nil)
        XCTAssertEqual(result.value, .string("json_string"))
    }
    
    func testInvalidTypeFallsBackToDefault() {
        let SUT = makeEvaluator(with: "notAnInt")
        let result = SUT.evaluate(key: "flag", defaultValue: Int64(42), context: nil)
        XCTAssertEqual(result.value, 42, "Should return default when conversion fails")
    }
    
    func testWhenSplitClientIsNilReturnsControl() {
        let SUT = Evaluator(splitClient: nil)
        let result = SUT.evaluate(key: "flag", defaultValue: "default", context: nil)
        XCTAssertEqual(result.value, Constants.CONTROL.rawValue)
    }
}
