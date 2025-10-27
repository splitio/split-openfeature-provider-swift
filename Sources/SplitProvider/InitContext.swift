//  Created by Martin Cardozo on 22/10/2025.

import OpenFeature

internal struct InitContext: OpenFeature.EvaluationContext {
    let apiKey: String
    let userKey: String
    
    var props: [String: OpenFeature.Value] {
        [
            "API_KEY": .string(apiKey),
            "USER_KEY": .string(userKey)
        ]
    }
    
    func keySet() -> Set<String> {
        [Constants.API_KEY.rawValue, Constants.USER_KEY.rawValue]
    }

    func getTargetingKey() -> String {
        userKey
    }

    func deepCopy() -> any OpenFeature.EvaluationContext {
        InitContext(apiKey: apiKey, userKey: userKey)
    }

    func getValue(key: String) -> OpenFeature.Value? {
        props[key]
    }

    func asMap() -> [String: OpenFeature.Value] {
        props
    }

    func asObjectMap() -> [String: AnyHashable?] {
        props.mapValues { value in
            switch value {
                case .string(let str): return str
                default: return nil
            }
        }
    }
}
