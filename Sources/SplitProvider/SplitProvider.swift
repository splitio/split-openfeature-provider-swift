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
    private var startedClients: [String] = []
    
    // Open Feature Components
    public var hooks: [any OpenFeature.Hook] = []
    public var metadata: any OpenFeature.ProviderMetadata = SplitProviderMetadata()
    private let eventHandler = EventHandler()
    internal var evaluator = Evaluator()
    
    // MARK: Inits
    internal init(key: String, config: SplitClientConfig? = nil) {
        sdkKey = key
        splitClientConfig = config
    }
    
    public init(key: String) {
        sdkKey = key
    }
    
    public func initialize(initialContext: (any OpenFeature.EvaluationContext)?) async throws { // Called by OpenFeature
        
        guard sdkKey != "" else {
            eventHandler.send(.error(errorCode: .providerFatal, message: "API key is missing for Split provider."))
            throw SplitError.missingInitData
        }
        
        // 1. Unpack Context
        guard let initialContext = initialContext else {
            eventHandler.send(.error(errorCode: .invalidContext, message: "Initialization context is missing for Split provider."))
            throw SplitError.missingInitContext
        }
        let userKey = initialContext.getTargetingKey()
        guard userKey != "" else {
            eventHandler.send(.error(errorCode: .targetingKeyMissing, message: "Targeting key is missing for Split provider."))
            throw SplitError.missingInitData
        }
        
        // 2. Client setup
        let key: Key = Key(matchingKey: userKey)
        splitClientConfig?.logLevel = .verbose
        if factory == nil { factory = DefaultSplitFactoryBuilder().setApiKey(sdkKey).setKey(key).setConfig(splitClientConfig ?? SplitClientConfig()).build() }
        guard let splitClient = factory?.client(key: key) else {
            eventHandler.send(.error(errorCode: .providerFatal, message: "Split Provider failed to initialize correctly."))
            return
        }
        evaluator.setClient(splitClient)
        
        if startedClients.contains(userKey) { return }

        // 3. If it's a new client
        await linkEvents(splitClient)
        startedClients.append(userKey) // Register to avoid init deadlock after onContextSet
    }
        
    // MARK: Context change
    public func onContextSet(oldContext: (any OpenFeature.EvaluationContext)?, newContext: any OpenFeature.EvaluationContext) async throws {
        // Even if it's the same targeting key, we need to update the context if the options change
        // since this is the only way to evaluate with attributes.
        guard newContext.isDifferent(oldContext) else { return }
        
        try await initialize(initialContext: newContext)
        eventHandler.send(.contextChanged)
    }
    
    // MARK: Events Linking
    private func linkEvents(_ splitClient: SplitClient) async {
        
        splitClient.on(event: .sdkUpdated) { [weak self] in
            self?.eventHandler.send(.configurationChanged)
        }
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var didResume = false
            
            splitClient.on(event: .sdkReady) {
                // OpenFeature .ready event is fired by OpenFeature, so no need to add it here too
                resume()
            }
            
            splitClient.on(event: .sdkReadyFromCache) { [weak self] in
                self?.eventHandler.send(.stale)
                resume()
            }
            
            splitClient.on(event: .sdkReadyTimedOut) {
                resume(timeOut: true)
            }

            func resume(timeOut: Bool = false) {
                guard !didResume else { return } // Avoid crash by multiple countinuation calls
                didResume = true
                
                if timeOut {
                    eventHandler.send(.error(errorCode: .general, message: "Split Provider timed out."))
                }
                
                // Return control to OpenFeature
                continuation.resume()
            }
        }
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
    let name: String? = "Split"
}

private extension EvaluationContext {
    func isDifferent(_ other: EvaluationContext?) -> Bool {
        getTargetingKey() != other?.getTargetingKey() || asObjectMap() != other?.asObjectMap()
    }
}
