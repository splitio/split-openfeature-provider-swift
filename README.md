# Split OpenFeature Provider for iOS

## Overview
This Provider is designed to enable the use of OpenFeature in iOS, with Split as the backing feature flag & experimentation platform.

## Compatibility
The Split OpenFeature Provider supports:
- iOS 14+

## Getting started
Below is a simple example that describes the instantiation of the Split Provider. Please see the [OpenFeature Documentation](https://docs.openfeature.dev/docs/reference/concepts/evaluation-api) for details on how to use the OpenFeature SDK.

### Installation

Add the Split OpenFeature Provider dependency to your XCode project via Swift Package Manager.

### Usage

The Split OpenFeature Provider requires an iOS `Context` and your Split SDK key. You must also provide an evaluation context with a targeting key when initializing the provider.

```swift
import Split
import Combine
import OpenFeature
import SplitProvider

Task {

    var providerCancellable: AnyCancellable?
    let provider = SplitProvider(key: "API_KEY")
    
    // Setup events observer
    providerCancellable = OpenFeatureAPI.shared.observe().sink { [weak self] event in
        switch event {
            case .ready:
                print("Split Provider is ready")
            case .error(let message):
                print("Split Provider error:", message)
            default:
                break
        }
    }
    
    // Setup OpenFeature
    let context = ImmutableContext(targetingKey: "user_key")
    await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: context)
    
    // Get a client and evaluate a flag
    let client = OpenFeatureAPI.getClient()
    let flagEvaluationResult = client.getBooleanValue("new-feature", false)
}
```

### Configuring the underlying Split client

It is possible to configure the Split client through the SplitClientConfig object, as shown below:

```swift
// Config if needed
let config = SplitClientConfig()
config.logLevel = .verbose

provider = SplitProvider(key: "r71jiucv9pkglvfa4ufhngtgss23ht7lrf23", config: config)
```

### Evaluation Context

The Split OpenFeature Provider requires a targeting key to be set in the evaluation context. This key identifies the user or entity for which you are evaluating feature flags.

#### Setting a targeting key during initialization:

```swift
let initialContext = ImmutableContext(targetingKey = "user-123")
OpenFeatureAPI.setProvider(provider, initialContext = initialContext)
```

#### Changing the targeting key at runtime:

```swift
let newContext = ImmutableContext(targetingKey = "user-456")
OpenFeatureAPI.setEvaluationContext(newContext)
```

#### Using attributes for targeting:

```swift
let context = ImmutableContext(
    targetingKey: "martin", 
    structure: ImmutableStructure(attributes: [ 
        "email": Value.String(someValue),
        "age": Value.Integer(30)
]))
OpenFeatureAPI.shared.setEvaluationContext(evaluationContext: context)

let client = OpenFeatureAPI.getClient()
let result = client.getBooleanDetails("premium-feature", false, context)
```

### Observing Provider Events

The Split OpenFeature Provider emits events when the provider state changes. You can observe these events to react to provider readiness, configuration changes, or errors.

```swift
import Combine

let cancellable = OpenFeatureAPI.shared.observe().sink { event in
    switch event {
    case ProviderEvent.ready:
        // ...
    case ProviderEvent.stale:
        // ...
    case ProviderEvent.configurationChanges:
        // ...
    case ProviderEvent.contextChanged:
        // ...
    case ProviderEvent.error(let errorCode, let message):
        // ...
    default:
        // ...
    }
}
```

Refer to this official documentation to see the supported events: 

## Contributing
Please see [Contributors Guide](CONTRIBUTORS-GUIDE.md) to find all you need to submit a Pull Request (PR).

## License
Licensed under the Apache License, Version 2.0. See: [Apache License](http://www.apache.org/licenses/LICENSE-2.0).
