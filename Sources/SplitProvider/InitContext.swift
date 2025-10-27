//  Created by Martin Cardozo on 22/10/2025.

import OpenFeature

internal struct InitContext: OpenFeature.EvaluationContext {
    let apiKey: String
    let userKey: String
    
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
        switch key {
            case Constants.API_KEY.rawValue: return OpenFeature.Value.string(apiKey)
            case Constants.USER_KEY.rawValue: return OpenFeature.Value.string(userKey)
            default: return nil
        }
    }

    func asMap() -> [String : OpenFeature.Value] {
        [Constants.API_KEY.rawValue: OpenFeature.Value.string(apiKey), Constants.USER_KEY.rawValue: OpenFeature.Value.string(userKey)]
    }

    func asObjectMap() -> [String : AnyHashable?] {
        [Constants.API_KEY.rawValue: apiKey, Constants.USER_KEY.rawValue: userKey]
    }
}
