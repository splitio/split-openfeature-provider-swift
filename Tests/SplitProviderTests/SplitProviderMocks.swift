//  Created by Martin Cardozo on 23/10/2025.

import Split
import Foundation

internal final class FactoryMock: SplitFactory {
    
    var client: any SplitClient = ClientMock()
    var manager: any SplitManager = SplitManagerMock()
    var userConsent: UserConsent = .granted
    var version: String = "1"
    var clients = [Key: SplitClient]()
    
    func client(key: Key) -> any SplitClient {
        guard let client = clients[key] else {
            let client = ClientMock()
            clients[key] = client
            return client
        }
        
        return client
    }
    
    func client(matchingKey: String) -> any SplitClient { client(key: Key(matchingKey: matchingKey)) }
    func client(matchingKey: String, bucketingKey: String?) -> any SplitClient { client(matchingKey: matchingKey) }
    func setUserConsent(enabled: Bool) {}
}

internal final class ClientMock: SplitClient {
    var treatment = "Treatment"
    var config: String? = nil
    var timeout = false
    
    init() {
        print(":: Mock Client started")
    }
    
    // MARK: Treatments
    func getTreatment(_ split: String, attributes: [String : Any]?) -> String {
        treatment
    }
    
    func getTreatment(_ split: String) -> String {
        treatment
    }
    
    func getTreatments(splits: [String], attributes: [String : Any]?) -> [String : String] {
        [treatment:treatment]
    }
    
    func getTreatmentWithConfig(_ split: String) -> SplitResult {
        SplitResult(treatment: treatment, config: config)
    }
    
    func getTreatmentWithConfig(_ split: String, attributes: [String : Any]?) -> SplitResult {
        SplitResult(treatment: treatment, config: config)
    }
    
    func getTreatmentsWithConfig(splits: [String], attributes: [String : Any]?) -> [String : SplitResult] {
        [treatment: SplitResult(treatment: treatment, config: config)]
    }
    
    func getTreatment(_ split: String, attributes: [String : Any]?, evaluationOptions: EvaluationOptions?) -> String {
        treatment
    }
    
    func getTreatments(splits: [String], attributes: [String : Any]?, evaluationOptions: EvaluationOptions?) -> [String : String] {
        [treatment:treatment]
    }
    
    func getTreatmentWithConfig(_ split: String, attributes: [String : Any]?, evaluationOptions: EvaluationOptions?) -> SplitResult {
        SplitResult(treatment: treatment, config: config)
    }
    
    func getTreatmentsWithConfig(splits: [String], attributes: [String : Any]?, evaluationOptions: EvaluationOptions?) -> [String : SplitResult] {
        [treatment: SplitResult(treatment: treatment, config: config)]
    }
    
    func getTreatmentsByFlagSet(_ flagSet: String, attributes: [String : Any]?) -> [String : String] {
        [treatment:treatment]
    }

    func getTreatmentsByFlagSets(_ flagSets: [String], attributes: [String : Any]?) -> [String : String] {
        [treatment:treatment]
    }
    
    func getTreatmentsWithConfigByFlagSet(_ flagSet: String, attributes: [String : Any]?) -> [String : SplitResult] {
        [treatment: SplitResult(treatment: treatment, config: config)]
    }
    
    func getTreatmentsWithConfigByFlagSets(_ flagSets: [String], attributes: [String : Any]?) -> [String : SplitResult] {
        [treatment: SplitResult(treatment: treatment, config: config)]
    }
    
    func getTreatmentsByFlagSet(_ flagSet: String, attributes: [String : Any]?, evaluationOptions: EvaluationOptions?) -> [String : String] {
        [treatment: treatment]
    }
    
    func getTreatmentsByFlagSets(_ flagSets: [String], attributes: [String : Any]?, evaluationOptions: EvaluationOptions?) -> [String : String] {
        [treatment: treatment]
    }
    
    func getTreatmentsWithConfigByFlagSet(_ flagSet: String, attributes: [String : Any]?, evaluationOptions: EvaluationOptions?) -> [String : SplitResult] {
        [treatment: SplitResult(treatment: treatment, config: config)]
    }
    
    func getTreatmentsWithConfigByFlagSets(_ flagSets: [String], attributes: [String : Any]?, evaluationOptions: EvaluationOptions?) -> [String : SplitResult] {
        [treatment: SplitResult(treatment: treatment, config: config)]
    }
    
    // MARK: Events
    var events: [SplitEvent: ()->()] = [:]
    
    func on(event: SplitEvent, execute action: @escaping SplitAction) {
        
        events[event] = action

        if timeout {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                print(":: Mock Client :: SDK_TIMEOUT")
                self.events[.sdkReadyTimedOut]!()
            }
            return
        }
        
        switch event {
            case .sdkUpdated:
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    print(":: Mock Client :: SDK_UPDATED")
                    self.events[.sdkUpdated]!()
                }
            case .sdkReady:
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print(":: Mock Client :: SDK_READY")
                    self.events[.sdkReady]!()
                }
            case .sdkReadyTimedOut:
                return
            case .sdkReadyFromCache:
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    print(":: Mock Client :: SDK_READY_FROM_CACHE")
                    self.events[.sdkReadyFromCache]!()
                }
        }
    }
    
    func on(event: SplitEvent, runInBackground: Bool, execute action: @escaping SplitAction) {}
    func on(event: SplitEvent, queue: DispatchQueue, execute action: @escaping SplitAction) {}
    
    // MARK: Attributes
    func setAttribute(name: String, value: Any) -> Bool { true }
    func getAttribute(name: String) -> Any? { nil }
    func setAttributes(_ values: [String : Any]) -> Bool { true}
    func getAttributes() -> [String : Any]? { nil }
    func removeAttribute(name: String) -> Bool { true }
    func clearAttributes() -> Bool { true }
    
    // MARK: Lifecycle
    func flush() {}
    func destroy() {}
    func destroy(completion: (() -> Void)?) {}
    
    // MARK: Track
    func track(trafficType: String, eventType: String, properties: [String : Any]?) -> Bool { true }
    func track(trafficType: String, eventType: String, value: Double, properties: [String : Any]?) -> Bool { true }
    func track(eventType: String, properties: [String : Any]?) -> Bool { true }
    func track(eventType: String, value: Double, properties: [String : Any]?) -> Bool { true }
    func track(trafficType: String, eventType: String) -> Bool { true }
    func track(trafficType: String, eventType: String, value: Double) -> Bool { true }
    func track(eventType: String) -> Bool { true }
    func track(eventType: String, value: Double) -> Bool { true }
}

internal final class SplitManagerMock: SplitManager {
    var splits: [SplitView] = []
    var splitNames: [String] = []
    func split(featureName: String) -> SplitView? { nil }
}
