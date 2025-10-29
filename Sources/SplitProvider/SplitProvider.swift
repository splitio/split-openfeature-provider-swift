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
    private var sdkKey: String
    
    // Open Feature Components
    public var hooks: [any OpenFeature.Hook] = []
    public var metadata: any OpenFeature.ProviderMetadata = SplitProviderMetadata()
    private let eventHandler = EventHandler()
    internal var evaluator: Evaluator!
    
    // MARK: Custom Initialization
    public init(key: String, config: SplitClientConfig? = nil) {
        sdkKey = key
        splitClientConfig = config
    }
    
    public func initialize(initialContext: (any OpenFeature.EvaluationContext)?) async throws {
        
        guard sdkKey != "" else {
            eventHandler.send(.error(errorCode: .invalidContext, message: "API key is missing for Split provider."))
            throw SplitError.missingInitData
        }
        
        guard let initialContext = initialContext else {
            eventHandler.send(.error(errorCode: .invalidContext, message: "Initialization context is missing for Split provider."))
            throw SplitError.missingInitContext
        }
        
        // 1. Unpack Context
        let userKey = initialContext.getTargetingKey()
        guard userKey != "" else {
            eventHandler.send(.error(errorCode: .targetingKeyMissing, message: "Targeting key is missing for Split provider."))
            throw SplitError.missingInitData
        }
        
        // 2. Client setup
        let key: Key = Key(matchingKey: userKey)
        if factory == nil { factory = DefaultSplitFactoryBuilder().setApiKey(sdkKey).setConfig(splitClientConfig ?? SplitClientConfig()).build() }
        splitClient = factory?.client(key: key)
        evaluator = Evaluator(splitClient: splitClient)

        // 3. Subscribe to events and wait for SDK
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var didResume = false

            // Avoid crash by multiple countinuations
            func resumeOnce(timeOut: Bool = false) {
                guard !didResume else { return }
                didResume = true
                
                if timeOut {
                    eventHandler.send(.error(errorCode: .general, message: "Split Provider timed out."))
                } else {
                    continuation.resume() // Pass control to OpenFeature again
                }
            }

            splitClient?.on(event: .sdkReady) { resumeOnce() }
            splitClient?.on(event: .sdkReadyFromCache) { resumeOnce() }
            splitClient?.on(event: .sdkReadyTimedOut) { resumeOnce(timeOut: true) }
        }
    }
    
    // MARK: Context Change
    public func onContextSet(oldContext: (any OpenFeature.EvaluationContext)?, newContext: any OpenFeature.EvaluationContext) async throws {
        guard oldContext?.getTargetingKey() != newContext.getTargetingKey() else { return }
        
        try await initialize(initialContext: newContext)
        eventHandler.send(.contextChanged)
    }
}

// MARK: Evaluation Methods
extension SplitProvider {
    
    public func getBooleanEvaluation(key: String, defaultValue: Bool, context: (any EvaluationContext)?) throws -> ProviderEvaluation<Bool> {
        try evaluator.evaluate(key: key, type: Bool.self, context: context)
    }

    public func getStringEvaluation(key: String, defaultValue: String, context: (any EvaluationContext)?) throws -> ProviderEvaluation<String> {
        try evaluator.evaluate(key: key, type: String.self, context: context)
    }

    public func getIntegerEvaluation(key: String, defaultValue: Int64, context: (any EvaluationContext)?) throws -> ProviderEvaluation<Int64> {
        try evaluator.evaluate(key: key, type: Int64.self, context: context)
    }

    public func getDoubleEvaluation(key: String, defaultValue: Double, context: (any EvaluationContext)?) throws -> ProviderEvaluation<Double> {
        try evaluator.evaluate(key: key, type: Double.self, context: context)
    }

    public func getObjectEvaluation(key: String, defaultValue: Value, context: (any EvaluationContext)?) throws -> ProviderEvaluation<Value> {
        throw OpenFeatureError.generalError(message: "Split SDK does not support object evaluation")
    }

    public func observe() -> AnyPublisher<OpenFeature.ProviderEvent?, Never> {
        eventHandler.publisher.eraseToAnyPublisher()
    }
}

// MARK: Open Feature
struct SplitProviderMetadata: ProviderMetadata {
    let name: String? = Constants.PROVIDER_NAME.rawValue
}
