import XCTest
@testable import SplitProvider
@testable import OpenFeature

final class SplitProviderTests: XCTestCase {
    func testSplitProviderImplementsFeatureProvider() throws {
        XCTAssertTrue(SplitProvider() is FeatureProvider)
    }

    func testNameIsCorrect() {
        XCTAssertTrue(SplitProvider().metadata.name == "Split")
    }
}
