//  Created by Martin Cardozo on 24/10/2025.

import XCTest
import OpenFeature
@testable import SplitProvider

final class EvaluatorTests: XCTestCase {

    private func makeEvaluator(withTreatment treatment: String = "defaultTreatment") -> Evaluator {
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

    // MARK: Object Evaluation Tests

    func testEvaluateObjectCallsParser() throws {
        let expectedTreatment = "test-treatment-string"
        let SUT = makeEvaluator(withTreatment: expectedTreatment)
        var parserWasCalled = false
        var receivedTreatment: String?

        let parser: (String) throws -> OpenFeature.Value = { treatment in
            parserWasCalled = true
            receivedTreatment = treatment
            return .string("parsed-value")
        }

        _ = try SUT.evaluateObject(key: "flag", context: nil, parser: parser)

        XCTAssertTrue(parserWasCalled, "Parser function should be called")
        XCTAssertEqual(receivedTreatment, expectedTreatment, "Parser should receive the treatment string")
    }

    func testEvaluateObjectReturnsParserResult() throws {
        let SUT = makeEvaluator(withTreatment: "some-treatment")
        let expectedValue = OpenFeature.Value.structure(["key": .string("value")])

        let parser: (String) throws -> OpenFeature.Value = { _ in
            return expectedValue
        }

        let result = try SUT.evaluateObject(key: "flag", context: nil, parser: parser)

        XCTAssertEqual(result.value, expectedValue, "Should return the parser's result")
    }

    func testEvaluateObjectPropagatesParserError() throws {
        let SUT = makeEvaluator(withTreatment: "invalid-json")
        let expectedError = OpenFeatureError.parseError(message: "Parser error")

        let parser: (String) throws -> OpenFeature.Value = { _ in
            throw expectedError
        }

        XCTAssertThrowsError(try SUT.evaluateObject(key: "flag", context: nil, parser: parser)) { error in
            XCTAssertEqual(error as? OpenFeatureError, expectedError, "Should propagate parser errors")
        }
    }

    func testEvaluateObjectWithControlTreatment() throws {
        let client = ClientMock()
        client.treatment = "control"
        let SUT = Evaluator(splitClient: client)

        let parser: (String) throws -> OpenFeature.Value = { _ in
            XCTFail("Parser should not be called for CONTROL treatment")
            return .null
        }

        XCTAssertThrowsError(try SUT.evaluateObject(key: "flag", context: nil, parser: parser)) { error in
            XCTAssertEqual(error as? OpenFeatureError, OpenFeatureError.flagNotFoundError(key: "flag"))
        }
    }

    func testEvaluateObjectWithNilClient() throws {
        let SUT = Evaluator(splitClient: nil)

        let parser: (String) throws -> OpenFeature.Value = { _ in
            XCTFail("Parser should not be called when client is nil")
            return .null
        }

        XCTAssertThrowsError(try SUT.evaluateObject(key: "flag", context: nil, parser: parser)) { error in
            XCTAssertEqual(error as? OpenFeatureError, OpenFeatureError.providerFatalError(message: "Split Client not found"))
        }
    }
}
