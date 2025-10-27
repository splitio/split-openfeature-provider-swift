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
        splitContext = InitContext(apiKey: API_KEY, userKey: USER_KEY)
        let key: Key = Key(matchingKey: USER_KEY)
        if factory == nil {
            factory = DefaultSplitFactoryBuilder().setApiKey(API_KEY).setKey(key).setConfig(splitClientConfig ?? SplitClientConfig()).build()
        }
        splitClient = factory?.client

        // 3. Wait for SDK
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var didResume = false

            // Avoid crash by multiple countinuations
            func resumeOnce(error: Bool = false) {
                guard !didResume else { return }
                didResume = true
                
                if error {
                    eventHandler.send(.error(errorCode: .general, message: "Provider timed out"))
                } else {
                    continuation.resume()
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

    public func getBooleanEvaluation(key: String, defaultValue: Bool, context: (any OpenFeature.EvaluationContext)?) throws -> OpenFeature.ProviderEvaluation<Bool> {
        ProviderEvaluation(value: false)
    }

    public func getStringEvaluation(key: String, defaultValue: String, context: (any OpenFeature.EvaluationContext)?) throws -> OpenFeature.ProviderEvaluation<String> {
        ProviderEvaluation(value: splitClient?.getTreatment(key) ?? Constants.CONTROL.rawValue)
    }

    public func getIntegerEvaluation(key: String, defaultValue: Int64, context: (any OpenFeature.EvaluationContext)?) throws -> OpenFeature.ProviderEvaluation<Int64> {
        ProviderEvaluation(value: 1)
    }

    public func getDoubleEvaluation(key: String, defaultValue: Double, context: (any OpenFeature.EvaluationContext)?) throws -> OpenFeature.ProviderEvaluation<Double> {
        ProviderEvaluation(value: 1.0)
    }

    public func getObjectEvaluation(key: String, defaultValue: OpenFeature.Value, context: (any OpenFeature.EvaluationContext)?) throws -> OpenFeature.ProviderEvaluation<OpenFeature.Value> {
        throw SplitError.notImplemented
    }

    public func observe() -> AnyPublisher<OpenFeature.ProviderEvent?, Never> {
        eventHandler.publisher.eraseToAnyPublisher()
    }
}

struct SplitProviderMetadata: ProviderMetadata {
    let name: String? = Constants.PROVIDER_NAME.rawValue
}
