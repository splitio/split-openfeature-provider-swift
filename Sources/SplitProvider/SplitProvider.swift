//  Created by Martin Cardozo on 22/10/2025.

import Combine
import Foundation
import OpenFeature
import Split

public class SplitProvider: FeatureProvider {
    
    // Split Components
    internal var splitClient: SplitClient?
    internal var splitClientConfig: SplitClientConfig?
    internal var factory: SplitFactory?
    
    // Open Feature Components
    public var hooks: [any OpenFeature.Hook] = []
    public var metadata: any OpenFeature.ProviderMetadata = SplitProviderMetadata()
    private let eventHandler = EventHandler()
    private var splitContext: InitContext?
    internal var evaluator: Evaluator!
    
    // MARK: Custom Initialization
    public init(_ config: SplitClientConfig? = nil) {
        splitClientConfig = config
    }
    
    public func initialize(initialContext: (any OpenFeature.EvaluationContext)?) async throws {
        
        guard let initialContext = initialContext else {
            eventHandler.send(.error(errorCode: .invalidContext, message: "Initialization context is missing for Split provider."))
            throw SplitError.missingInitContext
        }
        
        // 1. Unpack Context
        let apiKeyValue = initialContext.getValue(key: Constants.API_KEY.rawValue)?.asString()
        let userKeyValue = initialContext.getValue(key: Constants.USER_KEY.rawValue)?.asString()
        guard let API_KEY = apiKeyValue, apiKeyValue != "" else {
            eventHandler.send(.error(errorCode: .invalidContext, message: "Initialization data is missing for Split provider."))
            throw SplitError.missingInitData
        }
        guard let USER_KEY = userKeyValue, userKeyValue != "" else {
            eventHandler.send(.error(errorCode: .targetingKeyMissing, message: "Initialization data is missing for Split provider."))
            throw SplitError.missingInitData
        }
        
        // 2. Client setup
        splitContext = InitContext(API_KEY: API_KEY, USER_KEY: USER_KEY)
        let key: Key = Key(matchingKey: USER_KEY)
        if factory == nil { factory = DefaultSplitFactoryBuilder().setApiKey(API_KEY).setKey(key).setConfig(splitClientConfig ?? SplitClientConfig()).build() }
        splitClient = factory?.client
        if evaluator == nil { evaluator = Evaluator(splitClient: splitClient) }

        // 3. Subscribe to events and wait for SDK
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var didResume = false

            // Avoid crash by multiple countinuations
            func resumeOnce(error: Bool = false) {
                guard !didResume else { return }
                didResume = true
                
                if error {
                    eventHandler.send(.error(errorCode: .general, message: "Provider timed out"))
                } else {
                    continuation.resume() // Pass control to openFeature again
                }
            }

            splitClient?.on(event: .sdkReady) { resumeOnce() }
            splitClient?.on(event: .sdkReadyFromCache) { resumeOnce() }
            splitClient?.on(event: .sdkReadyTimedOut) { resumeOnce(error: true) }
        }
    }
    
    // MARK: Context Change
    public func onContextSet(oldContext: (any OpenFeature.EvaluationContext)?, newContext: any OpenFeature.EvaluationContext) async throws {
        throw SplitError.notImplemented
    }
}

// MARK: Evaluation Methods
extension SplitProvider {
    
    public func getBooleanEvaluation(key: String, defaultValue: Bool, context: (any EvaluationContext)?) throws -> ProviderEvaluation<Bool> {
        evaluator.evaluate(key: key, defaultValue: defaultValue, context: context) ?? ProviderEvaluation(value: defaultValue)
    }

    public func getStringEvaluation(key: String, defaultValue: String, context: (any EvaluationContext)?) throws -> ProviderEvaluation<String> {
        evaluator.evaluate(key: key, defaultValue: defaultValue, context: context) ?? ProviderEvaluation(value: defaultValue)
    }

    public func getIntegerEvaluation(key: String, defaultValue: Int64, context: (any EvaluationContext)?) throws -> ProviderEvaluation<Int64> {
        evaluator.evaluate(key: key, defaultValue: defaultValue, context: context) ?? ProviderEvaluation(value: defaultValue)
    }

    public func getDoubleEvaluation(key: String, defaultValue: Double, context: (any EvaluationContext)?) throws -> ProviderEvaluation<Double> {
        evaluator.evaluate(key: key, defaultValue: defaultValue, context: context) ?? ProviderEvaluation(value: defaultValue)
    }

    public func getObjectEvaluation(key: String, defaultValue: Value, context: (any EvaluationContext)?) throws -> ProviderEvaluation<Value> {
        evaluator.evaluate(key: key, defaultValue: defaultValue, context: context) ?? ProviderEvaluation(value: defaultValue)
    }

    public func observe() -> AnyPublisher<OpenFeature.ProviderEvent?, Never> {
        eventHandler.publisher.eraseToAnyPublisher() 
    }
}

// MARK: Open Feature
struct SplitProviderMetadata: ProviderMetadata {
    let name: String? = Constants.PROVIDER_NAME.rawValue
}

