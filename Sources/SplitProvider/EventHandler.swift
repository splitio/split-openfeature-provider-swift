//  Created by Martin Cardozo on 22/10/2025.

import Combine
import OpenFeature

internal final class EventHandler { // Used by Combine to propagate events
    private let subject = PassthroughSubject<OpenFeature.ProviderEvent?, Never>()
    
    var publisher: AnyPublisher<OpenFeature.ProviderEvent?, Never> {
        subject.eraseToAnyPublisher()
    }
    
    func send(_ event: OpenFeature.ProviderEvent) {
        subject.send(event)
    }
}
