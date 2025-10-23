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
    private var splitContext: SplitInitContext?
    
    // MARK: Custom Initialization
    public init(_ config: SplitClientConfig? = nil) {
        self.splitClientConfig = config
    }
    
    public func initialize(initialContext: (any OpenFeature.EvaluationContext)?) async throws {
        
        guard let initialContext = initialContext else {
            eventHandler.send(.error(errorCode: ErrorCode(rawValue: 1) , message: "Initialization context is missing for Split provider."))
            throw Errors.missingInitContext(errorCode: 1)
        }
        
        // 1. Unpack Context
        let apiKeyValue = initialContext.getValue(key: "API_KEY")?.asString()
        let userKeyValue = initialContext.getValue(key: "USER_KEY")?.asString()
        guard let API_KEY = apiKeyValue, apiKeyValue != "",
              let USER_KEY = userKeyValue, userKeyValue != ""
        else {
            eventHandler.send(.error(errorCode: ErrorCode(rawValue: 2) , message: "Initialization data is missing for Split provider."))
            throw Errors.missingInitData(errorCode: 2)
        }
        
        // 2. Client setup
        splitContext = SplitInitContext(API_KEY: API_KEY, USER_KEY: USER_KEY)
        let key: Key = Key(matchingKey: USER_KEY)
        
        if factory == nil { factory = DefaultSplitFactoryBuilder().setApiKey(API_KEY).setKey(key).setConfig(splitClientConfig ?? SplitClientConfig()).build() }
        
        splitClient = factory?.client

        // 3. Wait for Ready signal
        let semaphore = DispatchSemaphore(value: 0)
        splitClient?.on(event: .sdkReady) { [weak self] in
            semaphore.signal()
        }
        semaphore.wait()
    }
    
    // MARK: Context Change
    public func onContextSet(oldContext: (any OpenFeature.EvaluationContext)?, newContext: any OpenFeature.EvaluationContext) async throws {
        throw Errors.notImplemented
    }
}

// MARK: Evaluation Methods
extension SplitProvider {

    public func getBooleanEvaluation(key: String, defaultValue: Bool, context: (any OpenFeature.EvaluationContext)?) throws -> OpenFeature.ProviderEvaluation<Bool> {
        ProviderEvaluation(value: false)
    }

    public func getStringEvaluation(key: String, defaultValue: String, context: (any OpenFeature.EvaluationContext)?) throws -> OpenFeature.ProviderEvaluation<String> {
        ProviderEvaluation(value: splitClient?.getTreatment(key) ?? "CONTROL")
    }

    public func getIntegerEvaluation(key: String, defaultValue: Int64, context: (any OpenFeature.EvaluationContext)?) throws -> OpenFeature.ProviderEvaluation<Int64> {
        ProviderEvaluation(value: 1)
    }

    public func getDoubleEvaluation(key: String, defaultValue: Double, context: (any OpenFeature.EvaluationContext)?) throws -> OpenFeature.ProviderEvaluation<Double> {
        ProviderEvaluation(value: 1.0)
    }

    public func getObjectEvaluation(key: String, defaultValue: OpenFeature.Value, context: (any OpenFeature.EvaluationContext)?) throws -> OpenFeature.ProviderEvaluation<OpenFeature.Value> {
        throw Errors.notImplemented
    }

    public func observe() -> AnyPublisher<OpenFeature.ProviderEvent?, Never> {
        eventHandler.publisher.eraseToAnyPublisher()
    }
}

struct SplitProviderMetadata: ProviderMetadata {
    let name: String? = "Split"
}
