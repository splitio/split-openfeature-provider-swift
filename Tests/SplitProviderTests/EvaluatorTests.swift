//  Created by Martin Cardozo on 24/10/2025.

import XCTest
import OpenFeature
@testable import SplitProvider

final class EvaluatorTests: XCTestCase {
    
    private func makeEvaluator(withTreatment treatment: String) -> Evaluator {
        let client = ClientMock()
        client.treatment = treatment
        return Evaluator(splitClient: client)
    }
    
    func testBoolTrue() throws {
        let SUT = makeEvaluator(withTreatment: "true")
        let result = try SUT.evaluate(key: "flag", type: Bool.self, context: nil)
        XCTAssertEqual(result.value, true)
    }
    
    func testBoolFalse() throws {
        let SUT = makeEvaluator(withTreatment: "FALSE")
        let result = try SUT.evaluate(key: "flag", type: Bool.self, context: nil)
        XCTAssertEqual(result.value, false)
    }
    
    func testInt64() throws {
        let SUT = makeEvaluator(withTreatment: "123")
        let result = try SUT.evaluate(key: "flag", type: Int64.self, context: nil)
        XCTAssertEqual(result.value, 123)
    }
    
    func testDouble() throws {
        let SUT = makeEvaluator(withTreatment: "3.14")
        let result = try SUT.evaluate(key: "flag", type: Double.self, context: nil)
        XCTAssertEqual(result.value, 3.14, accuracy: 0.0001)
    }
    
    func testString() throws {
        let SUT = makeEvaluator(withTreatment: "banana")
        let result = try SUT.evaluate(key: "flag", type: String.self, context: nil)
        XCTAssertEqual(result.value, "banana")
    }
    
    func testValue() throws {
        let SUT = makeEvaluator(withTreatment: "json_string")
        let result = try SUT.evaluate(key: "flag", type: OpenFeature.Value.self, context: nil)
        XCTAssertEqual(result.value, .string("json_string"))
    }
    
    func testInvalidTypeThrows() throws {
        let SUT = makeEvaluator(withTreatment: "notAnInt")
        var evaluationError = OpenFeatureError.invalidContextError
        
        do {
            _ = try SUT.evaluate(key: "flag", type: Int64.self, context: nil)
        } catch {
            evaluationError = (error as? OpenFeatureError)!
        }
        
        XCTAssertEqual(evaluationError, OpenFeatureError.valueNotConvertableError)
    }
    
    func testNilSplitClient() throws {
        let SUT = Evaluator(splitClient: nil)
        var evaluationError = OpenFeatureError.invalidContextError
        
        do {
            _ = try SUT.evaluate(key: "flag", type: String.self, context: nil)
        } catch {
            evaluationError = (error as? OpenFeatureError)!
        }
        
        XCTAssertEqual(evaluationError, OpenFeatureError.providerFatalError(message: "Split Client not found"))
    }
}
