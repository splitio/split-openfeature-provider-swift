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

    // MARK: Init
    public init(key: String, config: SplitClientConfig? = nil) {
        sdkKey = key
        splitClientConfig = config
    }

    public func initialize(initialContext: (any OpenFeature.EvaluationContext)?) async throws {

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

        // 3. Subscribe to events and wait for SDK
        await startClient(splitClient, userKey: userKey)
    }

    // MARK: Context change
    public func onContextSet(oldContext: (any OpenFeature.EvaluationContext)?, newContext: any OpenFeature.EvaluationContext) async throws {
        // Even if it's the same targeting key, we need to update the context if the options change
        // since this is the only way to evaluate with attributes.
        guard newContext.isDifferent(oldContext) else { return }

        try await initialize(initialContext: newContext)
        eventHandler.send(.contextChanged)
    }

    // MARK: Client start
    private func startClient(_ splitClient: SplitClient, userKey: String) async {
        evaluator.setClient(splitClient)

        if startedClients.contains(userKey) { return }

        // Subscribe to SDK Events
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var didResume = false

            splitClient.on(event: .sdkReady) {
                resume()
            }

            splitClient.on(event: .sdkReadyFromCache) { [weak self] in
                self?.eventHandler.send(.stale)
                resume()
            }

            splitClient.on(event: .sdkUpdated) { [weak self] in
                self?.eventHandler.send(.configurationChanged)
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

                // Register as already started (to avoid init deadlock after onContextSet)
                startedClients.append(userKey)

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
        try evaluator.evaluateObject(key: key, context: context, parser: parseJSONTreatment)
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

// MARK: JSON Parsing
private extension SplitProvider {

    /// Parses a JSON string treatment into an OpenFeature Value
    func parseJSONTreatment(_ treatment: String) throws -> Value {
        guard let jsonData = treatment.data(using: .utf8) else {
            throw OpenFeatureError.parseError(message: "Failed to parse JSON treatment")
        }

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
        } catch {
            throw OpenFeatureError.parseError(message: "Failed to parse JSON treatment")
        }

        // Ensure it's a JSON object (dictionary), not array or primitive
        guard let dictionary = jsonObject as? [String: Any] else {
            throw OpenFeatureError.parseError(message: "Treatment must be a JSON object")
        }

        // Convert to OpenFeature Value
        return try convertToValue(dictionary)
    }

    /// Converts Any type from JSONSerialization to OpenFeature Value
    private func convertToValue(_ object: Any) throws -> Value {
        switch object {
        case let dict as [String: Any]:
            var structure: [String: Value] = [:]
            for (key, value) in dict {
                structure[key] = try convertToValue(value)
            }
            return .structure(structure)
        case let array as [Any]:
            let values = try array.map { try convertToValue($0) }
            return .list(values)
        case let string as String:
            return .string(string)
        case let bool as Bool:
            return .boolean(bool)
        case let int as Int:
            return .integer(Int64(int))
        case let double as Double:
            return .double(double)
        case is NSNull:
            return .null
        default:
            throw OpenFeatureError.parseError(message: "Unsupported JSON type")
        }
    }
}
