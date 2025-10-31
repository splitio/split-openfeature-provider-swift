//  Created for SplitProvider integration testing
//  Tests the OpenFeature Client API integration with Split Provider

import XCTest
import Combine
import Foundation
import Swifter
@testable import SplitProvider
@testable import OpenFeature
@testable import Split

/**
 * Client-level integration tests using the OpenFeature SDK/Client API.
 *
 * - Tests through the OpenFeature Client API (not directly calling provider methods)
 * - Verifies that errors are caught and default values are returned (not thrown)
 * - Tests end-to-end behavior as users would interact with the SDK
 * - Uses real Split SDK with mocked HTTP responses (not Split client mocks)
 */
final class OpenFeatureClientIntegrationTests: XCTestCase {

    private var mockServer: SwifterMockServer!
    private var dispatcher: SplitAPIDispatcher!
    private var provider: SplitProvider?
    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        
        mockServer = SwifterMockServer()
        
        // Load split changes data
        let splitChangesData = loadSplitChanges()
        dispatcher = SplitAPIDispatcher(splitChangesData: splitChangesData)
        
        // Start HTTP server
        do {
            try mockServer.start { [weak self] request in
                guard let self = self else { return .internalServerError }
                return self.dispatcher.dispatch(request)
            }
        } catch {
            XCTFail("Failed to start mock server: \(error)")
        }
    }

    override func tearDown() {
        cancellables.removeAll()
        mockServer.stop()
        super.tearDown()
    }

    // MARK: - Basic Typed Evaluation Tests

    func testClientGetBooleanValueReturnsParsedBooleanFromTreatment() async {
        let client = await createAndInitializeClient(userKey: "test-user")

        let result = client.getBooleanValue(key: "boolean-flag", defaultValue: false)

        XCTAssertTrue(result, "Expected boolean-flag to return true (treatment 'on')")
    }

    func testClientGetStringValueReturnsStringTreatment() async {
        let client = await createAndInitializeClient(userKey: "test-user")

        let result = client.getStringValue(key: "string-flag", defaultValue: "default")

        XCTAssertEqual(result, "greeting", "Expected string-flag to return 'greeting'")
    }

    func testClientGetIntegerValueReturnsDefaultForUnparseableTreatment() async {
        let client = await createAndInitializeClient(userKey: "test-user")

        // integer-flag returns "ten" which cannot be parsed
        // Client should catch ParseError and return default
        let result = client.getIntegerValue(key: "integer-flag", defaultValue: 999)

        XCTAssertEqual(result, 999, "Expected default value for unparseable treatment")
    }

    func testClientGetDoubleValueReturnsDefaultForUnparseableTreatment() async {
        let client = await createAndInitializeClient(userKey: "test-user")

        // float-flag returns "half" which cannot be parsed
        // Client should catch ParseError and return default
        let result = client.getDoubleValue(key: "float-flag", defaultValue: 99.9)

        XCTAssertEqual(result, 99.9, accuracy: 0.001, "Expected default value for unparseable treatment")
    }

    func testClientGetObjectValueReturnsParsedJSONObject() async {
        let client = await createAndInitializeClient(userKey: "test-user")

        let result = client.getObjectValue(key: "object-flag", defaultValue: .null)

        guard case .structure(let structure) = result else {
            XCTFail("Expected Value.structure but got \(result)")
            return
        }

        XCTAssertEqual(structure["showImages"]?.asBoolean(), true)
        XCTAssertEqual(structure["title"]?.asString(), "Check out these pics!")
        XCTAssertEqual(structure["imagesPerPage"]?.asInteger(), 100)
    }

    // MARK: - Error Handling - Client Returns Default Values

    func testClientReturnsDefaultValueForNonExistentFlag() async {
        let client = await createAndInitializeClient(userKey: "test-user")

        // Provider throws FlagNotFoundError, but client catches it and returns default
        let result = client.getStringValue(key: "non-existent-flag", defaultValue: "my-default")

        XCTAssertEqual(result, "my-default")
    }

    func testClientReturnsDefaultBooleanForNonExistentFlag() async {
        let client = await createAndInitializeClient(userKey: "test-user")

        let result = client.getBooleanValue(key: "non-existent-flag", defaultValue: true)

        XCTAssertTrue(result)
    }

    func testClientReturnsDefaultIntegerForNonExistentFlag() async {
        let client = await createAndInitializeClient(userKey: "test-user")

        let result = client.getIntegerValue(key: "non-existent-flag", defaultValue: 42)

        XCTAssertEqual(result, 42)
    }

    func testClientReturnsDefaultDoubleForNonExistentFlag() async {
        let client = await createAndInitializeClient(userKey: "test-user")

        let result = client.getDoubleValue(key: "non-existent-flag", defaultValue: 3.14)

        XCTAssertEqual(result, 3.14, accuracy: 0.001)
    }

    func testClientReturnsDefaultObjectForNonExistentFlag() async {
        let defaultObj = Value.structure(["key": .string("default")])
        let client = await createAndInitializeClient(userKey: "test-user")

        let result = client.getObjectValue(key: "non-existent-flag", defaultValue: defaultObj)

        XCTAssertEqual(result, defaultObj)
    }

    func testClientReturnsDefaultValueForDisabledFlag() async {
        let client = await createAndInitializeClient(userKey: "test-user")

        // Provider throws FlagNotFoundError for disabled flags (killed status)
        // Client should catch and return default
        let result = client.getStringValue(key: "string-disabled-flag", defaultValue: "disabled-default")

        XCTAssertEqual(result, "disabled-default")
    }

    func testClientReturnsDefaultBooleanForDisabledFlag() async {
        let client = await createAndInitializeClient(userKey: "test-user")

        let result = client.getBooleanValue(key: "boolean-disabled-flag", defaultValue: false)

        XCTAssertFalse(result)
    }

    // MARK: - Evaluation Details Tests

    func testClientGetDetailsReturnsErrorInfoForNonExistentFlag() async {
        let client = await createAndInitializeClient(userKey: "test-user")

        let details = client.getStringDetails(key: "non-existent-flag", defaultValue: "default")

        XCTAssertEqual(details.value, "default")
        XCTAssertNotNil(details.errorCode)
        XCTAssertNotNil(details.errorMessage)
    }

    func testClientGetDetailsReturnsErrorInfoForParseError() async {
        let client = await createAndInitializeClient(userKey: "test-user")

        // integer-flag returns "ten" which can't be parsed
        let details = client.getIntegerDetails(key: "integer-flag", defaultValue: 999)

        XCTAssertEqual(details.value, 999)
        XCTAssertNotNil(details.errorCode)
    }

    // MARK: - Type Mismatch Tests

    func testClientGetStringValueWorksOnBooleanFlag() async {
        let client = await createAndInitializeClient(userKey: "test-user")

        // Requesting boolean flag as string should return the treatment string
        let result = client.getStringValue(key: "boolean-flag", defaultValue: "default")

        XCTAssertEqual(result, "on")
    }

    func testClientGetBooleanValueReturnsDefaultForNonBooleanTreatment() async {
        let client = await createAndInitializeClient(userKey: "test-user")

        // string-flag returns "greeting" which isn't a valid boolean
        // Client should catch ParseError and return default
        let result = client.getBooleanValue(key: "string-flag", defaultValue: true)

        XCTAssertTrue(result)
    }

    func testClientGetIntegerValueReturnsDefaultForStringTreatment() async {
        let client = await createAndInitializeClient(userKey: "test-user")

        // string-flag returns "greeting" which can't be parsed as integer
        let result = client.getIntegerValue(key: "string-flag", defaultValue: 555)

        XCTAssertEqual(result, 555)
    }

    func testClientGetDoubleValueReturnsDefaultForStringTreatment() async {
        let client = await createAndInitializeClient(userKey: "test-user")

        // string-flag returns "greeting" which can't be parsed as double
        let result = client.getDoubleValue(key: "string-flag", defaultValue: 7.77)

        XCTAssertEqual(result, 7.77, accuracy: 0.001)
    }

    func testClientGetObjectValueReturnsDefaultForInvalidJSON() async {
        let defaultObj = Value.structure(["error": .boolean(true)])
        let client = await createAndInitializeClient(userKey: "test-user")

        // string-flag returns "greeting" which isn't valid JSON
        let result = client.getObjectValue(key: "string-flag", defaultValue: defaultObj)

        // Per spec, when provider returns wrong type (TYPE_MISMATCH),
        // client should return default value
        XCTAssertEqual(result, defaultObj, "Expected default value for TYPE_MISMATCH")
    }

    // MARK: - Provider Status Tests

    func testClientObservesProviderReadyEventAfterInitialization() async {
        let readyExpectation = expectation(description: "Provider ready event")
        var receivedReady = false

        // Start observing before initialization
        OpenFeatureAPI.shared.observe()
            .sink { event in
                if case .ready = event {
                    receivedReady = true
                    readyExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        _ = await createAndInitializeClient(userKey: "test-user")

        await fulfillment(of: [readyExpectation], timeout: 10.0)
        XCTAssertTrue(receivedReady, "Should receive ProviderReady event")
    }

    // MARK: - Metadata Tests

    func testClientReceivesFlagMetadataInDetails() async {
        let client = await createAndInitializeClient(userKey: "test-user")

        let details = client.getStringDetails(key: "metadata-flag", defaultValue: "default")

        XCTAssertNotEqual(details.value, "default")
        // Metadata is available in evaluation details
        XCTAssertNotNil(details)
    }

    // MARK: - Helper Methods

    /// Creates and initializes an OpenFeature client with a real Split SDK and mocked HTTP responses
    private func createAndInitializeClient(userKey: String) async -> any Client {
        // Configure custom endpoints pointing to mock HTTP server
        let baseUrl = "http://localhost:\(mockServer.port)/api"
        let endpoints = ServiceEndpoints.builder()
            .set(sdkEndpoint: baseUrl)
            .set(eventsEndpoint: baseUrl)
            .set(authServiceEndpoint: baseUrl)
            .set(streamingServiceEndpoint: baseUrl)
            .set(telemetryServiceEndpoint: baseUrl)
            .build()
        
        print("Endpoints configured:")
        print("   SDK: \(endpoints.sdkEndpoint)")
        print("   Events: \(endpoints.eventsEndpoint)")
        print("   Valid: \(endpoints.allEndpointsValid)")
        
        // Create Split SDK configuration (URLProtocol already registered in setUp)
        let config = SplitClientConfig()
        config.serviceEndpoints = endpoints
        config.streamingEnabled = false
        config.featuresRefreshRate = 999999
        config.segmentsRefreshRate = 999999
        config.logLevel = .verbose

        // Create Split provider
        provider = SplitProvider(key: "localhost1234567890abcdefghijklmnopqrstuvwxyz", config: config)

        let context = ImmutableContext(targetingKey: userKey)
        await OpenFeatureAPI.shared.setProviderAndWait(provider: provider!, initialContext: context)

        return OpenFeatureAPI.shared.getClient()
    }

    /// Load split changes from test resources
    private func loadSplitChanges() -> Data? {
        guard let url = Bundle.module.url(forResource: "split_changes_test", withExtension: "json") else {
            XCTFail("Could not find split_changes_test.json")
            return nil
        }

        do {
            return try Data(contentsOf: url)
        } catch {
            XCTFail("Failed to load split_changes_test.json: \(error)")
            return nil
        }
    }
}
