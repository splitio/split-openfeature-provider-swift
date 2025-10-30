//  Created by Martin Cardozo on 22/10/2025.

import XCTest
import Combine
import Foundation
@testable import SplitProvider
@testable import OpenFeature
@testable import Split

final class SplitProviderTests: XCTestCase {
    
    private var provider: SplitProvider!
    private var providerCancellable: AnyCancellable?
    private let eventHandler = OpenFeature.EventHandler()
    
    override func tearDown() {
        providerCancellable?.cancel()
    }
}

// MARK: Setup Tests
extension SplitProviderTests {
   
    func testCorrectInitialization() {
        
        let readyExp = expectation(description: "SDK Ready")
        let openFeatureExp = expectation(description: "OpenFeature Ready")
        let nonErrorExp = expectation(description: "There should be no errors")
        nonErrorExp.isInverted = true
        
        // Setup events observer
        providerCancellable = OpenFeatureAPI.shared.observe().sink { event in
            switch event {
                case .ready:
                    readyExp.fulfill()
                case .error:
                    nonErrorExp.fulfill()
                default:
                    break
            }
        }
        
        provider = SplitProvider(key: "sofd75fo7w6ao576oshf567jshdkfrbk746")
        let context = ImmutableContext(targetingKey: "martin")
        provider.factory = FactoryMock()
        
        // Kickoff Provider
        Task {
            await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: context)
            openFeatureExp.fulfill()
        }

        wait(for: [readyExp, openFeatureExp, nonErrorExp], timeout: 4)
    }
    
    func testMissingApiKey() {
        
        let openFeatureExp = expectation(description: "OpenFeature Ready")
        var errorFired = false
        
        // Setup events observer
        providerCancellable = OpenFeatureAPI.shared.observe().sink { event in
            switch event {
                case .ready:
                    break
                case .error(let errorCode, _):
                    if errorCode == .invalidContext {
                        errorFired = true
                    }
                default:
                    break
            }
        }
        
        let context = ImmutableContext(targetingKey: "martin")
        provider = SplitProvider(key: "")
        provider.factory = FactoryMock()
        
        // Kickoff Provider
        Task {
            await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: context)
            openFeatureExp.fulfill()
        }

        wait(for: [openFeatureExp], timeout: 5)
        XCTAssertTrue(errorFired, "If there is no API key, an error should be fired")
    }
    
    func testMissingUserKey() {
        
        let openFeatureExp = expectation(description: "OpenFeature Ready")
        var errorFired = false
        
        // Setup events observer
        providerCancellable = OpenFeatureAPI.shared.observe().sink { event in
            switch event {
                case .ready:
                    break
                case .error(let errorCode, _):
                    if errorCode == .targetingKeyMissing {
                        errorFired = true
                    }
                default:
                    break
            }
        }
        
        let context = ImmutableContext(targetingKey: "")
        provider = SplitProvider(key: "sofd75fo7w6ao576oshf567jshdkfrbk746")
        provider.factory = FactoryMock()
        
        // Kickoff Provider
        Task {
            await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: context)
            openFeatureExp.fulfill()
        }

        wait(for: [openFeatureExp], timeout: 5)
        XCTAssertTrue(errorFired, "If there is no User key, an error should be fired")
    }
    
    func testMissingInitContext() {
        
        let openFeatureExp = expectation(description: "OpenFeature Ready")
        var errorFired = false
        
        provider = SplitProvider(key: "sofd75fo7w6ao576oshf567jshdkfrbk746")
        
        // Setup events observer
        providerCancellable = OpenFeatureAPI.shared.observe().sink { event in
            switch event {
                case .ready:
                    break
                case .error(let errorCode, _):
                    if errorCode == .invalidContext {
                        errorFired = true
                    }
                default:
                    break
            }
        }
        
        provider = SplitProvider(key: "sofd75fo7w6ao576oshf567jshdkfrbk746")
        provider.factory = FactoryMock()
        
        // Kickoff Provider
        Task {
            await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: nil)
            openFeatureExp.fulfill()
        }

        wait(for: [openFeatureExp], timeout: 5)
        XCTAssertTrue(errorFired, "If there is no initialContext, an error should be fired")
    }
    
    func testInitWithConfig() {
        
        let readyExp = expectation(description: "SDK Ready")
        let openFeatureExp = expectation(description: "OpenFeature Ready")

        // Config if needed
        let context = ImmutableContext(targetingKey: "martin")
        let config = SplitClientConfig()
        config.logLevel = .verbose
        
        provider = SplitProvider(key: "sofd75fo7w6ao576oshf567jshdkfrbk746", config: config)
        provider.factory = FactoryMock()
        
        // Setup events observer
        providerCancellable = OpenFeatureAPI.shared.observe().sink { event in
            switch event {
                case .ready:
                    readyExp.fulfill()
                case .error(_,_):
                    break
                default:
                    break
            }
        }
        
        // Kickoff Provider
        Task {
            await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: context)
            openFeatureExp.fulfill()
        }

        wait(for: [openFeatureExp, readyExp], timeout: 5)
        XCTAssertEqual(provider.splitClientConfig?.logLevel, .verbose, "SplitConfig should be correctly propagated")
    }
    
    func testTimeOut() {
        
        let errorExp = expectation(description: "SDK should time out")
        
        // Setup events observer
        providerCancellable = OpenFeatureAPI.shared.observe().sink { event in
            switch event {
                case .ready:
                    break
                case .error(let errorCode, let message):
                    if errorCode == .general && message == "Split Provider timed out." {
                        errorExp.fulfill()
                    }
                default:
                    break
            }
        }
        
        let context = ImmutableContext(targetingKey: "martin")
        provider = SplitProvider(key: "sofd75fo7w6ao576oshf567jshdkfrbk746")
        let factory = FactoryMock()
        let client = factory.client(matchingKey: "martin") as! ClientMock
        client.timeout = true // MARK: Fail point
        provider.factory = factory
        
        // Kickoff Provider
        Task { await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: context) }

        wait(for: [errorExp], timeout: 4)
    }
    
    func testNameIsCorrect() {
        XCTAssertTrue(SplitProvider(key: "sd87f65ds8fs6g8d65fba9sf6").metadata.name == SplitProviderMetadata().name)
    }
}

// MARK: Evaluation Tests
extension SplitProviderTests {

    func testBooleanTrue() throws {
        let client = ClientMock()
        let evaluator = Evaluator(splitClient: client)
        client.treatment = "true"

        let provider = SplitProvider(key: "sofd75fo7w6ao576oshf567jshdkfrbk746")
        provider.splitClient = client
        provider.evaluator = evaluator

        let result = try provider.getBooleanEvaluation(key: "flag", defaultValue: false, context: nil)
        XCTAssertEqual(result.value, true)
    }
    
    func testBooleanCase() throws {
        let client = ClientMock()
        let evaluator = Evaluator(splitClient: client)
        client.treatment = "tRuE"

        let provider = SplitProvider(key: "sofd75fo7w6ao576oshf567jshdkfrbk746")
        provider.splitClient = client
        provider.evaluator = evaluator

        let result = try provider.getBooleanEvaluation(key: "flag", defaultValue: false, context: nil)
        XCTAssertEqual(result.value, true)
    }
    
    func testBooleanEvaluationOn() throws {
        let client = ClientMock()
        let evaluator = Evaluator(splitClient: client)
        client.treatment = "on"

        let provider = SplitProvider(key: "sofd75fo7w6ao576oshf567jshdkfrbk746")
        provider.splitClient = client
        provider.evaluator = evaluator

        let result = try provider.getBooleanEvaluation(key: "flag", defaultValue: false, context: nil)
        XCTAssertEqual(result.value, true)
    }
    
    func testBooleanEvaluationFalse() throws {
        let client = ClientMock()
        let evaluator = Evaluator(splitClient: client)
        client.treatment = "false"

        let provider = SplitProvider(key: "sofd75fo7w6ao576oshf567jshdkfrbk746")
        provider.splitClient = client
        provider.evaluator = evaluator

        let result = try provider.getBooleanEvaluation(key: "flag", defaultValue: true, context: nil)
        XCTAssertEqual(result.value, false)
    }
    
    func testBooleanEvaluationOff() throws {
        let client = ClientMock()
        let evaluator = Evaluator(splitClient: client)
        client.treatment = "oFf"

        let provider = SplitProvider(key: "sofd75fo7w6ao576oshf567jshdkfrbk746")
        provider.splitClient = client
        provider.evaluator = evaluator

        let result = try provider.getBooleanEvaluation(key: "flag", defaultValue: true, context: nil)
        XCTAssertEqual(result.value, false)
    }

    func testIntegerEvaluation() throws {
        let client = ClientMock()
        let evaluator = Evaluator(splitClient: client)
        client.treatment = "123"

        let provider = SplitProvider(key: "sofd75fo7w6ao576oshf567jshdkfrbk746")
        provider.splitClient = client
        provider.evaluator = evaluator

        let result = try provider.getIntegerEvaluation(key: "flag", defaultValue: 0, context: nil)
        XCTAssertEqual(result.value, 123)
    }

    func testDoubleEvaluation() throws {
        let client = ClientMock()
        let evaluator = Evaluator(splitClient: client)
        client.treatment = "3.14"

        let provider = SplitProvider(key: "sofd75fo7w6ao576oshf567jshdkfrbk746")
        provider.splitClient = client
        provider.evaluator = evaluator

        let result = try provider.getDoubleEvaluation(key: "flag", defaultValue: 0.0, context: nil)
        XCTAssertEqual(result.value, 3.14, accuracy: 0.0001)
    }

    func testStringEvaluation() throws {
        let client = ClientMock()
        let evaluator = Evaluator(splitClient: client)
        client.treatment = "hello"

        let provider = SplitProvider(key: "sofd75fo7w6ao576oshf567jshdkfrbk746")
        provider.splitClient = client
        provider.evaluator = evaluator

        let result = try provider.getStringEvaluation(key: "flag", defaultValue: "default", context: nil)
        XCTAssertEqual(result.value, "hello")
    }
    
    func testWrongEvaluationType() {
        let client = ClientMock()
        let evaluator = Evaluator(splitClient: client)
        client.treatment = "tru"

        let provider = SplitProvider(key: "sofd75fo7w6ao576oshf567jshdkfrbk746")
        provider.splitClient = client
        provider.evaluator = evaluator
        
        do {
            _ = try provider.getIntegerEvaluation(key: "flag", defaultValue: 1, context: nil)
        } catch {
            XCTAssertEqual(error as? OpenFeatureError, OpenFeatureError.valueNotConvertableError)
        }
    }
    
    func testFlagWithConfig() {
        let evaluation = expectation(description: "OpenFeature should evaluate")
        let config = "{config: \"some config=4\"}"
        var result: FlagEvaluationDetails<Bool>? = nil
        
        // Setup events observer
        providerCancellable = OpenFeatureAPI.shared.observe().sink { event in
            switch event {
                case .ready:
                    result = OpenFeatureAPI.shared.getClient().getBooleanDetails(key: "test", defaultValue: false)
                    evaluation.fulfill()
                case .error(_, _):
                    break
                default:
                    break
            }
        }
        
        let context = ImmutableContext(targetingKey: "martin")
        provider = SplitProvider(key: "sofd75fo7w6ao576oshf567jshdkfrbk746")
        let factory = FactoryMock()
        let client = factory.client(matchingKey: "martin") as! ClientMock
        client.treatment = "on"
        client.config = config
        provider.factory = factory
        
        // Kickoff Provider
        Task { await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: context) }
        wait(for: [evaluation], timeout: 3)

        XCTAssertEqual(result?.flagMetadata["config"]?.asString(), config)
    }
    
    func testWithConfig() {
        let evaluation = expectation(description: "OpenFeature should evaluate")
        let config = "{config: \"some config=4\"}"
        var result: FlagEvaluationDetails<Bool>? = nil
        
        // Setup events observer
        providerCancellable = OpenFeatureAPI.shared.observe().sink { event in
            switch event {
                case .ready:
                    result = OpenFeatureAPI.shared.getClient().getBooleanDetails(key: "test", defaultValue: false)
                    evaluation.fulfill()
                case .error(_, _):
                    break
                default:
                    break
            }
        }
        
        let context = ImmutableContext(targetingKey: "martin")
        provider = SplitProvider(key: "sofd75fo7w6ao576oshf567jshdkfrbk746")
        let factory = FactoryMock()
        let client = factory.client(matchingKey: "martin") as! ClientMock
        client.treatment = "on"
        client.config = config
        provider.factory = factory
        
        // Kickoff Provider
        Task { await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: context) }
        wait(for: [evaluation], timeout: 3)

        XCTAssertEqual(result?.flagMetadata["config"]?.asString(), config)
    }
    
    func testWithAttributes() {
        let openFeatureReady = expectation(description: "OpenFeature should be ready")
        let evaluation = expectation(description: "OpenFeature should evaluate")
        var result: String? = nil
        let expectedResult: Int64 = 50
        
        // Setup events observer
        providerCancellable = OpenFeatureAPI.shared.observe().sink { event in
            switch event {
                case .ready:
                
                    // Pass attributes as context change (only valid form supported for now by Open Feature)
                    let context = ImmutableContext(targetingKey: "martin", structure: ImmutableStructure(attributes: ["someKey": OpenFeature.Value.integer(expectedResult)]))
                    OpenFeatureAPI.shared.setEvaluationContext(evaluationContext: context)
                
                    result = OpenFeatureAPI.shared.getClient().getStringValue(key: "test", defaultValue: "")
                    evaluation.fulfill()
                case .error(_, _):
                    break
                default:
                    break
            }
        }
        
        let context = ImmutableContext(targetingKey: "martin")
        provider = SplitProvider(key: "sofd75fo7w6ao576oshf567jshdkfrbk746")
        let factory = FactoryMock()
        let client = factory.client(matchingKey: "martin") as! ClientMock
        client.treatment = "on"
        client.attributes["someKey"] = expectedResult
        provider.factory = factory
        
        // Kickoff Provider
        Task {
            await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: context)
            openFeatureReady.fulfill()
        }
        wait(for: [openFeatureReady, evaluation], timeout: 3)

        XCTAssertEqual(result, "on-\(expectedResult)")
    }
    
    func testInvalidFlag() throws {
        var openFeatureError: OpenFeatureError?
        let client = ClientMock()
        let evaluator = Evaluator(splitClient: client)
        client.treatment = SplitConstants.control // Simulate flag not found at the client level

        let provider = SplitProvider(key: "sofd75fo7w6ao576oshf567jshdkfrbk746")
        provider.splitClient = client
        provider.evaluator = evaluator
        
        do {
            _ = try provider.getStringEvaluation(key: "flag", defaultValue: "default", context: nil)
        } catch {
            openFeatureError = (error as! OpenFeatureError)
        }
        
        XCTAssertEqual(openFeatureError, OpenFeatureError.flagNotFoundError(key: "flag"))
    }
    
    func testDefaultValueInCaseOfFailure() {
        // This is actually testing the OpenFeature fallback, but since it's at the bridging point,
        // I will leave it here for completeness and in case this behavior changes in the future.
        
        let evaluation = expectation(description: "OpenFeature should evaluate")
        var result: Int64? = nil
        let defaultResult: Int64 = 2
        
        // Setup events observer
        providerCancellable = OpenFeatureAPI.shared.observe().sink { event in
            switch event {
                case .ready:
                    // In this case we are asking an Integer to a flag that evaluates to "on"
                    result = OpenFeatureAPI.shared.getClient().getIntegerValue(key: "test", defaultValue: defaultResult)
                    evaluation.fulfill()
                case .error(_, _):
                    break
                default:
                    break
            }
        }
        
        let context = ImmutableContext(targetingKey: "martin")
        provider = SplitProvider(key: "sofd75fo7w6ao576oshf567jshdkfrbk746")
        let factory = FactoryMock()
        let client = factory.client(matchingKey: "martin") as! ClientMock
        client.treatment = "on"
        provider.factory = factory
        
        // Kickoff Provider
        Task { await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: context) }
        wait(for: [evaluation], timeout: 3)

        XCTAssertEqual(result, defaultResult)
    }
    
    func testOnContextSetSameContext() async throws {
        let provider = SplitProviderMock(key: "dummy-key")
        provider.factory = FactoryMock()
        let oldContext = ImmutableContext(targetingKey: "user_123")
        let newContext = ImmutableContext(targetingKey: "user_123")

        try await provider.onContextSet(oldContext: oldContext, newContext: newContext)

        XCTAssertEqual(provider.initializeCalled, false, "initialize() should NOT be called if context is equal")
    }
    
    func testContextSetDifferentContext() async throws {
        let provider = SplitProviderMock(key: "dummy-key")
        provider.factory = FactoryMock()
        let oldContext = ImmutableContext(targetingKey: "user_123")
        let newContext = ImmutableContext(targetingKey: "user_124")

        try await provider.onContextSet(oldContext: oldContext, newContext: newContext)

        XCTAssertEqual(provider.initializeCalled, true, "initialize() should be called if targeting Key is different")
    }
    
    func testContextSetSameContextWithAttributes() async throws {
        let provider = SplitProviderMock(key: "dummy-key")
        provider.factory = FactoryMock()
        let oldContext = ImmutableContext(targetingKey: "user_123", structure: ImmutableStructure(attributes: ["foo": OpenFeature.Value.string("bar")]))
        let newContext = ImmutableContext(targetingKey: "user_123", structure: ImmutableStructure(attributes: ["foo": OpenFeature.Value.string("bar")]))

        try await provider.onContextSet(oldContext: oldContext, newContext: newContext)

        XCTAssertEqual(provider.initializeCalled, false, "initialize() should NOT be called if context is equal")
    }
    
    func testContextSetDifferentContextSameKey() async throws {
        let provider = SplitProviderMock(key: "dummy-key")
        provider.factory = FactoryMock()
        let oldContext = ImmutableContext(targetingKey: "user_123", structure: ImmutableStructure(attributes: ["foo": OpenFeature.Value.string("bar")]))
        let newContext = ImmutableContext(targetingKey: "user_123", structure: ImmutableStructure(attributes: ["foo": OpenFeature.Value.string("BAR")]))

        try await provider.onContextSet(oldContext: oldContext, newContext: newContext)

        XCTAssertEqual(provider.initializeCalled, true, "initialize() should be called if attributes are different even for the same key")
    }
}

fileprivate class SplitProviderMock: SplitProvider {
    var initializeCalled = false
    override func initialize(initialContext: EvaluationContext?) async throws {
        initializeCalled = true
    }
}
