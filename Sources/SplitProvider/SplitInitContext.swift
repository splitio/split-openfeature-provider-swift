//  Created by Martin Cardozo on 22/10/2025.

import OpenFeature

internal struct SplitInitContext: OpenFeature.EvaluationContext {
    let API_KEY: String
    let USER_KEY: String
    
    func keySet() -> Set<String> {
        ["API_KEY", "USER_KEY"]
    }

    func getTargetingKey() -> String {
        USER_KEY
    }

    func deepCopy() -> any OpenFeature.EvaluationContext {
        SplitInitContext(API_KEY: API_KEY, USER_KEY: USER_KEY)
    }

    func getValue(key: String) -> OpenFeature.Value? {
        switch key {
            case "API_KEY": return OpenFeature.Value.string(API_KEY)
            case "USER_KEY": return OpenFeature.Value.string(USER_KEY)
            default: return nil
        }
    }

    func asMap() -> [String : OpenFeature.Value] {
        ["API_KEY": OpenFeature.Value.string(API_KEY), "USER_KEY": OpenFeature.Value.string(USER_KEY)]
    }

    func asObjectMap() -> [String : AnyHashable?] {
        ["API_KEY": API_KEY, "USER_KEY": USER_KEY]
    }
}
