//  Created by Martin Cardozo on 22/10/2025.

import OpenFeature

internal struct InitContext: OpenFeature.EvaluationContext {
    let API_KEY: String
    let USER_KEY: String
    
    func keySet() -> Set<String> {
        [Constants.API_KEY.rawValue, Constants.USER_KEY.rawValue]
    }

    func getTargetingKey() -> String {
        USER_KEY
    }

    func deepCopy() -> any OpenFeature.EvaluationContext {
        InitContext(API_KEY: API_KEY, USER_KEY: USER_KEY)
    }

    func getValue(key: String) -> OpenFeature.Value? {
        switch key {
            case Constants.API_KEY.rawValue: return OpenFeature.Value.string(API_KEY)
            case Constants.USER_KEY.rawValue: return OpenFeature.Value.string(USER_KEY)
            default: return nil
        }
    }

    func asMap() -> [String : OpenFeature.Value] {
        [Constants.API_KEY.rawValue: OpenFeature.Value.string(API_KEY), Constants.USER_KEY.rawValue: OpenFeature.Value.string(USER_KEY)]
    }

    func asObjectMap() -> [String : AnyHashable?] {
        [Constants.API_KEY.rawValue: API_KEY, Constants.USER_KEY.rawValue: USER_KEY]
    }
}
