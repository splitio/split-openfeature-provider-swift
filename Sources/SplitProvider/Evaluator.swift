//  Created by Martin Cardozo on 24/10/2025.

import Split
import OpenFeature

final class Evaluator {

    private var splitClient: SplitClient?

    init(splitClient: SplitClient? = nil) {
        self.splitClient = splitClient
    }

    internal func setClient(_ splitClient: SplitClient) {
        self.splitClient = splitClient
    }

    private func parseValue<T>(_ value: String, as type: T.Type) -> T? {
        switch type {
            case is Bool.Type:
                if value.lowercased() == "on" || value.lowercased() == "true" {
                    return true as? T
                }
                if value.lowercased() == "off" || value.lowercased() == "false" {
                    return false as? T
                }
                return nil
            case is Int64.Type:
                return Int64(value) as? T
            case is Double.Type:
                return Double(value) as? T
            case is String.Type:
                return value as? T
            case is OpenFeature.Value.Type:
                return OpenFeature.Value.string(value) as? T
            default:
                return nil
        }
    }

    internal func evaluate<T>(key: String, type: T.Type, context: (any EvaluationContext)?) throws -> ProviderEvaluation<T> {
        let treatment = try getTreatment(key: key, context: context)

        // If nil throw error so OpenFeature returns the default value
        guard let value = parseValue(treatment.treatment, as: T.self) else {
            throw OpenFeatureError.valueNotConvertableError
        }

        return ProviderEvaluation(value: value, flagMetadata: mapConfig(treatment.config))
    }

    internal func evaluateObject(key: String, context: (any EvaluationContext)?, parser: (String) throws -> OpenFeature.Value) throws -> ProviderEvaluation<OpenFeature.Value> {
        let treatment = try getTreatment(key: key, context: context)

        // Parse JSON treatment using the provided parser
        let value = try parser(treatment.treatment)

        return ProviderEvaluation(value: value, flagMetadata: mapConfig(treatment.config))
    }

    // MARK: - Helper Methods

    /// Gets treatment from Split SDK and validates it
    private func getTreatment(key: String, context: (any EvaluationContext)?) throws -> SplitResult {
        guard let client = splitClient else {
            throw OpenFeatureError.providerFatalError(message: "Split Client not found")
        }

        let treatment = client.getTreatmentWithConfig(key, attributes: mapAttributes(context?.asMap()))

        // Unpack and propagate error if result is CONTROL
        guard treatment.treatment.lowercased() != "control" else {
            throw OpenFeatureError.flagNotFoundError(key: key)
        }

        return treatment
    }

    // Map OpenFeature EvaluationContext to Split SDK attributes
    private func mapAttributes(_ context: [String: OpenFeature.Value]?) -> [String: Any]? {
        guard let context = context else { return nil }

        var result: [String: Any] = [:]

        for (key, value) in context {
            switch value {
                case .string(let str):
                    result[key] = str
                case .boolean(let bool):
                    result[key] = bool
                case .integer(let int):
                    result[key] = int
                case .double(let dbl):
                    result[key] = dbl
                case .structure(_):
                    break
                default:
                    continue
                }
        }
        return result
    }

    // Map Split SDK treatment config to Open Feature FlagMetadata
    private func mapConfig(_ config: String?) -> [String: FlagMetadataValue] {
        ["config": FlagMetadataValue.string(config ?? "")]
    }
}
