//  Created by Martin Cardozo on 24/10/2025.

import XCTest
import OpenFeature
@testable import SplitProvider

final class InitContextTests: XCTestCase {
    
    var SUT: InitContext!
    
    override func setUp() {
        SUT = InitContext(API_KEY: "skhjcgkjhfgasdhka", USER_KEY: "martin")
    }
    
    override func tearDown() {}
    
    func testValues() {
        XCTAssertEqual(SUT.getValue(key: Constants.API_KEY.rawValue)?.asString(), "skhjcgkjhfgasdhka")
        XCTAssertEqual(SUT.getValue(key: Constants.USER_KEY.rawValue)?.asString(), "martin")
    }
    
    func testKeySet() {
        XCTAssertEqual(SUT.keySet(), [Constants.API_KEY.rawValue, Constants.USER_KEY.rawValue])
    }

    func testTargetingKey() {
        XCTAssertEqual(SUT.getTargetingKey(), "martin")
    }

    func testDeepCopy() {
        let deepCopy = SUT.deepCopy()
        
        XCTAssertEqual(deepCopy.getValue(key: Constants.API_KEY.rawValue)?.asString(), "skhjcgkjhfgasdhka")
        XCTAssertEqual(deepCopy.getValue(key: Constants.USER_KEY.rawValue)?.asString(), "martin")
    }

    func testAsMap() {
        let map = SUT.asMap()
        
        XCTAssertEqual(map[Constants.API_KEY.rawValue]?.asString(), "skhjcgkjhfgasdhka")
        XCTAssertEqual(map[Constants.USER_KEY.rawValue]?.asString(), "martin")
    }

    func testAsObjectMap() {
        let asObjectMap = SUT.asObjectMap()
        
        XCTAssertEqual(asObjectMap[Constants.API_KEY.rawValue], "skhjcgkjhfgasdhka")
        XCTAssertEqual(asObjectMap[Constants.USER_KEY.rawValue], "martin")
    }
}


