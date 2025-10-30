//  Created by Martin Cardozo on 24/10/2025.

import Split
import OpenFeature

final class Evaluator {
    
    private let splitClient: SplitClient?
    
    init(splitClient: SplitClient?) {
        self.splitClient = splitClient
    }
    
    private func parseValue<T>(_ value: String, as type: T.Type) -> T? {
        switch type {
            case is Bool.Type:
                return (value.lowercased() == "true") as? T
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
    
    internal func evaluate<T>(key: String, defaultValue: T, context: (any EvaluationContext)?) -> ProviderEvaluation<T> {
        let treatment = splitClient?.getTreatment(key) ?? Constants.CONTROL.rawValue
        let value = parseValue(treatment, as: T.self) ?? defaultValue
        return ProviderEvaluation(value: value)
    }
}
