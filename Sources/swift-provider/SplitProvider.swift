import Combine
import Foundation
import OpenFeature
import Split

public class SplitProvider: FeatureProvider {
    public var hooks: [any OpenFeature.Hook] = []

    public var metadata: any OpenFeature.ProviderMetadata = SwiftProviderMetadata()

    public init() {
        let config: SplitClientConfig = SplitClientConfig()
    }

    public func initialize(initialContext: (any OpenFeature.EvaluationContext)?) async throws {
        throw ProviderError.notImplemented
    }

    public func onContextSet(
        oldContext: (any OpenFeature.EvaluationContext)?,
        newContext: any OpenFeature.EvaluationContext
    ) async throws {
        throw ProviderError.notImplemented
    }

    public func getBooleanEvaluation(
        key: String, defaultValue: Bool, context: (any OpenFeature.EvaluationContext)?
    ) throws -> OpenFeature.ProviderEvaluation<Bool> {
        throw ProviderError.notImplemented
    }

    public func getStringEvaluation(
        key: String, defaultValue: String, context: (any OpenFeature.EvaluationContext)?
    ) throws -> OpenFeature.ProviderEvaluation<String> {
        throw ProviderError.notImplemented
    }

    public func getIntegerEvaluation(
        key: String, defaultValue: Int64, context: (any OpenFeature.EvaluationContext)?
    ) throws -> OpenFeature.ProviderEvaluation<Int64> {
        throw ProviderError.notImplemented
    }

    public func getDoubleEvaluation(
        key: String, defaultValue: Double, context: (any OpenFeature.EvaluationContext)?
    ) throws -> OpenFeature.ProviderEvaluation<Double> {
        throw ProviderError.notImplemented
    }

    public func getObjectEvaluation(
        key: String, defaultValue: OpenFeature.Value, context: (any OpenFeature.EvaluationContext)?
    ) throws -> OpenFeature.ProviderEvaluation<OpenFeature.Value> {
        throw ProviderError.notImplemented
    }

    public func observe() -> AnyPublisher<OpenFeature.ProviderEvent?, Never> {
        return Empty().eraseToAnyPublisher()
    }
}

struct SwiftProviderMetadata: ProviderMetadata {
    var name: String? = "Split"
}

enum ProviderError: Error {
    case notImplemented
}
