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
    
    override func setUp() {}
    
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
        
        let context = InitContext(apiKey: "sofd75fo7w6ao576oshf567jshdkfrbk746", userKey: "martin")
        provider = SplitProvider()
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
        
        let context = InitContext(apiKey: "", userKey: "martin")
        provider = SplitProvider()
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
        
        let context = InitContext(apiKey: "sofd75fo7w6ao576oshf567jshdkfrbk746", userKey: "")
        provider = SplitProvider()
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
        
        provider = SplitProvider()
        
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
        
        provider = SplitProvider()
        provider.factory = FactoryMock()
        
        // Kickoff Provider
        Task {
            await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: nil)
            openFeatureExp.fulfill()
        }

        wait(for: [openFeatureExp], timeout: 5)
        XCTAssertTrue(errorFired, "If there is no initialContext, an error should be fired")
    }
    
    func testInitializationWithConfig() {
        
        let readyExp = expectation(description: "SDK Ready")
        let openFeatureExp = expectation(description: "OpenFeature Ready")

        // Config if needed
        let context = InitContext(apiKey: "sofd75fo7w6ao576oshf567jshdkfrbk746", userKey: "martin")
        let config = SplitClientConfig()
        config.logLevel = .verbose
        
        provider = SplitProvider(config)
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
        
        let errorExp = expectation(description: "SDK should timeout")
        
        // Setup events observer
        providerCancellable = OpenFeatureAPI.shared.observe().sink { event in
            switch event {
                case .ready:
                    break
                case .error(let errorCode, let message):
                    if errorCode == .general && message == "Provider timed out" {
                        errorExp.fulfill()
                    }
                default:
                    break
            }
        }
        
        let context = InitContext(apiKey: "sofd75fo7w6ao576oshf567jshdkfrbk746", userKey: "martin")
        provider = SplitProvider()
        let factory = FactoryMock()
        factory.getClient().timeout = true // MARK: Fail point
        provider.factory = factory
        
        // Kickoff Provider
        Task { await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: context) }

        wait(for: [errorExp], timeout: 4)
    }
    
    func testNameIsCorrect() {
        XCTAssertTrue(SplitProvider().metadata.name == Constants.PROVIDER_NAME.rawValue)
    }
}

// MARK: Evaluation Tests
extension SplitProviderTests {

    func testBooleanEvaluationTrue() throws {
        let client = ClientMock()
        let evaluator = Evaluator(splitClient: client)
        client.treatment = "true"

        let provider = SplitProvider()
        provider.splitClient = client
        provider.evaluator = evaluator

        let result = try provider.getBooleanEvaluation(key: "flag", defaultValue: false, context: nil)
        XCTAssertEqual(result.value, true)
    }
    
    func testBooleanEvaluationWrong() throws {
        let client = ClientMock()
        let evaluator = Evaluator(splitClient: client)
        client.treatment = "tru"

        let provider = SplitProvider()
        provider.splitClient = client
        provider.evaluator = evaluator

        let result = try provider.getBooleanEvaluation(key: "flag", defaultValue: false, context: nil)
        XCTAssertEqual(result.value, false, "Treatment should be the default value")
    }
    
    func testBooleanEvaluationFalse() throws {
        let client = ClientMock()
        let evaluator = Evaluator(splitClient: client)
        client.treatment = "false"

        let provider = SplitProvider()
        provider.splitClient = client
        provider.evaluator = evaluator

        let result = try provider.getBooleanEvaluation(key: "flag", defaultValue: false, context: nil)
        XCTAssertEqual(result.value, false)
    }

    func testIntegerEvaluation() throws {
        let client = ClientMock()
        let evaluator = Evaluator(splitClient: client)
        client.treatment = "123"

        let provider = SplitProvider()
        provider.splitClient = client
        provider.evaluator = evaluator

        let result = try provider.getIntegerEvaluation(key: "flag", defaultValue: 0, context: nil)
        XCTAssertEqual(result.value, 123)
    }

    func testDoubleEvaluation() throws {
        let client = ClientMock()
        let evaluator = Evaluator(splitClient: client)
        client.treatment = "3.14"

        let provider = SplitProvider()
        provider.splitClient = client
        provider.evaluator = evaluator

        let result = try provider.getDoubleEvaluation(key: "flag", defaultValue: 0.0, context: nil)
        XCTAssertEqual(result.value, 3.14, accuracy: 0.0001)
    }

    func testStringEvaluation() throws {
        let client = ClientMock()
        let evaluator = Evaluator(splitClient: client)
        client.treatment = "hello"

        let provider = SplitProvider()
        provider.splitClient = client
        provider.evaluator = evaluator

        let result = try provider.getStringEvaluation(key: "flag", defaultValue: "default", context: nil)
        XCTAssertEqual(result.value, "hello")
    }
}
