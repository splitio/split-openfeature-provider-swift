import Combine
import Foundation
import OpenFeature
import Split

public final class SplitProvider: FeatureProvider {
    
    // Split Components
    private var splitClient: SplitClient?
    private var splitFactory: SplitFactory?
    private var splitContext: SplitInitContext?
    private var splitClientConfig: SplitClientConfig?
    
    // Open Feature Components
    public var hooks: [any OpenFeature.Hook] = []
    public var metadata: any OpenFeature.ProviderMetadata = SwiftProviderMetadata()
    private let eventHandler = EventHandler()
    
    // MARK: Custom Initialization
    public init(_ config: SplitClientConfig? = nil) {
        self.splitClientConfig = config
    }
    
    public func initialize(initialContext: (any OpenFeature.EvaluationContext)?) async throws {
        
        guard let initialContext = initialContext else {
            eventHandler.send(.error(message: "Initialization context is missing for Split provider."))
            throw Errors.missingInitContext
        }
        
        // 1. Unpack Context
        let apiKeyValue = initialContext.getValue(key: "API_KEY")?.asString()
        let userKeyValue = initialContext.getValue(key: "USER_KEY")?.asString()
        guard let API_KEY = apiKeyValue, apiKeyValue != "",
              let USER_KEY = userKeyValue, userKeyValue != ""
        else {
            eventHandler.send(.error(message: "Initialization data is missing for Split provider."))
            throw Errors.missingInitData
        }
        
        // 2. Client setup
        let context = SplitInitContext(API_KEY: API_KEY, USER_KEY: USER_KEY)
        let key: Key = Key(matchingKey: USER_KEY)
        let factoryBuilder = DefaultSplitFactoryBuilder()
        factoryBuilder.setApiKey(API_KEY).setKey(key).setConfig(splitClientConfig ?? SplitClientConfig())
        splitFactory = factoryBuilder.build()
        splitClient  = splitFactory?.client
        let manager  = splitFactory?.manager
        
        splitClient?.on(event: .sdkReady) { [weak self] in
            self?.eventHandler.send(ProviderEvent.ready)
        }
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

// MARK: Open Feature Components
struct SwiftProviderMetadata: ProviderMetadata {
    let name: String? = "Split"
    let version: String? = "3.4.0"
}
