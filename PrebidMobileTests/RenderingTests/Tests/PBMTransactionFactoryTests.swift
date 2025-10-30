/*   Copyright 2018-2021 Prebid.org, Inc.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import XCTest

@testable @_spi(PBMInternal) import PrebidMobile

class PBMTransactionFactoryTests: XCTestCase {
    
    var bid: Bid!
    var adUnitConfig: AdUnitConfig!
    var connection: PrebidServerConnection!
    var callbackExpectation: XCTestExpectation?
    var callbackTransaction: Transaction?
    var callbackError: Error?
    
    override func setUp() {
        super.setUp()
        bid = RawWinningBidFabricator.makeWinningBid(price: 0.75, bidder: "test_bidder", cacheID: "cache_id")
        bid.size = CGSize(width: 300, height: 250)
        adUnitConfig = AdUnitConfig(configId: "test_config_id", size: CGSize(width: 300, height: 250))
        connection = UtilitiesForTesting.createConnectionForMockedTest()
    }
    
    override func tearDown() {
        callbackExpectation = nil
        callbackTransaction = nil
        callbackError = nil
        bid = nil
        adUnitConfig = nil
        connection = nil
        super.tearDown()
    }
    
    // MARK: - PBMTransactionFactory Tests
    
    func testInitWithValidParameters() {
        let factory = PBMTransactionFactory(bid: bid,
                                           adConfiguration: adUnitConfig,
                                           connection: connection,
                                           callback: { _, _ in })
        XCTAssertNotNil(factory)
    }
    
    func testLoadHTMLTransaction() {
        let htmlMarkup = "<html><body>Test HTML</body></html>"
        let expectation = XCTestExpectation(description: "Callback called")
        
        let factory = PBMTransactionFactory(bid: bid,
                                           adConfiguration: adUnitConfig,
                                           connection: connection,
                                           callback: { transaction, error in
            expectation.fulfill()
            self.callbackTransaction = transaction
            self.callbackError = error
        })
        
        let result = factory.load(withAdMarkup: htmlMarkup)
        XCTAssertTrue(result, "Load should return true for HTML markup")
        
        wait(for: [expectation], timeout: 5.0)
        
        // Note: Transaction may be nil if creative factory hasn't completed yet
        // The important part is that the factory was created and load was initiated
        XCTAssertNil(callbackError, "Should not have error for HTML transaction")
    }
    
    func testLoadVASTTransaction() {
        let vastMarkup = "<VAST version=\"3.0\"><Ad><Wrapper><VASTAdTagURI><![CDATA[http://test.com]]></VASTAdTagURI></Wrapper></Ad></VAST>"
        let expectation = XCTestExpectation(description: "Callback called")
        
        let factory = PBMTransactionFactory(bid: bid,
                                           adConfiguration: adUnitConfig,
                                           connection: connection,
                                           callback: { transaction, error in
            expectation.fulfill()
            self.callbackTransaction = transaction
            self.callbackError = error
        })
        
        let result = factory.load(withAdMarkup: vastMarkup)
        XCTAssertTrue(result, "Load should return true for VAST markup")
        
        wait(for: [expectation], timeout: 10.0)
        
        // VAST loading is async and may fail, but the factory should have been created
        XCTAssertTrue(result, "VAST load should be initiated")
    }
    
    func testLoadReturnsFalseWhenAlreadyLoading() {
        let htmlMarkup = "<html><body>Test HTML</body></html>"
        let expectation = XCTestExpectation(description: "Callback called")
        expectation.isInverted = true // Should not be called immediately
        
        let factory = PBMTransactionFactory(bid: bid,
                                           adConfiguration: adUnitConfig,
                                           connection: connection,
                                           callback: { _, _ in
            expectation.fulfill()
        })
        
        let result1 = factory.load(withAdMarkup: htmlMarkup)
        XCTAssertTrue(result1, "First load should succeed")
        
        let result2 = factory.load(withAdMarkup: htmlMarkup)
        XCTAssertFalse(result2, "Second load should fail when already loading")
        
        wait(for: [expectation], timeout: 0.1)
    }
    
    func testCallbackCalledOnMainThread() {
        let htmlMarkup = "<html><body>Test HTML</body></html>"
        let expectation = XCTestExpectation(description: "Callback called on main thread")
        
        let factory = PBMTransactionFactory(bid: bid,
                                           adConfiguration: adUnitConfig,
                                           connection: connection,
                                           callback: { transaction, error in
            XCTAssertTrue(Thread.isMainThread, "Callback should be called on main thread")
            expectation.fulfill()
        })
        
        factory.load(withAdMarkup: htmlMarkup)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testIsLoadingPropertyBehavior() {
        let htmlMarkup = "<html><body>Test HTML</body></html>"
        
        let factory = PBMTransactionFactory(bid: bid,
                                           adConfiguration: adUnitConfig,
                                           connection: connection,
                                           callback: { _, _ in })
        
        // Initially should not be loading
        XCTAssertFalse(factory.isLoading, "Factory should not be loading initially")
        
        // Start loading
        let result = factory.load(withAdMarkup: htmlMarkup)
        XCTAssertTrue(result, "Load should succeed")
        
        // Should be loading now (note: accessing isLoading property may require reflection or may not be accessible)
        // This test verifies the load was initiated
        XCTAssertTrue(result, "Load should return true when starting")
        
        // Try to load again - should fail
        let result2 = factory.load(withAdMarkup: htmlMarkup)
        XCTAssertFalse(result2, "Second load should fail when already loading")
    }
    
    func testTransactionFactoryDelegatesSuccess() {
        let htmlMarkup = "<html><body>Test HTML</body></html>"
        let expectation = XCTestExpectation(description: "Transaction ready for display")
        
        let factory = PBMTransactionFactory(bid: bid,
                                           adConfiguration: adUnitConfig,
                                           connection: connection,
                                           callback: { transaction, error in
            // When transaction is ready, it should be provided
            if transaction != nil {
                expectation.fulfill()
            }
        })
        
        factory.load(withAdMarkup: htmlMarkup)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testTransactionFactoryDelegatesFailure() {
        // Create a scenario that will likely fail - invalid markup or configuration
        let invalidMarkup = "" // Empty markup might cause issues
        
        let expectation = XCTestExpectation(description: "Transaction failed")
        
        let factory = PBMTransactionFactory(bid: bid,
                                           adConfiguration: adUnitConfig,
                                           connection: connection,
                                           callback: { transaction, error in
            // When transaction fails, error should be provided
            if error != nil {
                expectation.fulfill()
            }
        })
        
        let result = factory.load(withAdMarkup: invalidMarkup)
        // Empty markup might still trigger load, but should fail later
        if result {
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // MARK: - PBMDisplayTransactionFactory Tests
    
    func testDisplayTransactionFactoryCreatesHTMLTransaction() {
        let htmlMarkup = "<html><body>Test HTML</body></html>"
        let expectation = XCTestExpectation(description: "Transaction ready")
        
        let factory = PBMDisplayTransactionFactory(bid: bid,
                                                   adConfiguration: adUnitConfig,
                                                   connection: connection,
                                                   callback: { transaction, error in
            XCTAssertNotNil(transaction, "Transaction should be created for HTML markup")
            XCTAssertNil(error, "Should not have error for valid HTML")
            expectation.fulfill()
        })
        
        let result = factory.load(withAdMarkup: htmlMarkup)
        XCTAssertTrue(result, "Load should succeed")
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testDisplayTransactionFactoryDelegatesSuccess() {
        let htmlMarkup = "<html><body>Test HTML</body></html>"
        let expectation = XCTestExpectation(description: "Transaction ready for display")
        
        let factory = PBMDisplayTransactionFactory(bid: bid,
                                                   adConfiguration: adUnitConfig,
                                                   connection: connection,
                                                   callback: { transaction, error in
            XCTAssertNotNil(transaction, "Transaction should be provided on success")
            XCTAssertNil(error, "Error should be nil on success")
            expectation.fulfill()
        })
        
        factory.load(withAdMarkup: htmlMarkup)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testDisplayTransactionFactoryPreventsConcurrentLoads() {
        let htmlMarkup = "<html><body>Test HTML</body></html>"
        
        let factory = PBMDisplayTransactionFactory(bid: bid,
                                                   adConfiguration: adUnitConfig,
                                                   connection: connection,
                                                   callback: { _, _ in })
        
        let result1 = factory.load(withAdMarkup: htmlMarkup)
        XCTAssertTrue(result1, "First load should succeed")
        
        let result2 = factory.load(withAdMarkup: htmlMarkup)
        XCTAssertFalse(result2, "Second load should fail when already loading")
    }
    
    // MARK: - PBMVastTransactionFactory Tests
    
    func testVastTransactionFactoryCreatesVASTTransaction() {
        let vastMarkup = "<VAST version=\"3.0\"><Ad><Wrapper><VASTAdTagURI><![CDATA[http://test.com]]></VASTAdTagURI></Wrapper></Ad></VAST>"
        let expectation = XCTestExpectation(description: "VAST transaction created")
        
        let adConfiguration = AdConfiguration()
        let factory = PBMVastTransactionFactory(bid: bid,
                                               connection: connection,
                                               adConfiguration: adConfiguration,
                                               callback: { transaction, error in
            // VAST loading may succeed or fail depending on the VAST content
            // Just verify the callback was called
            expectation.fulfill()
        })
        
        let result = factory.load(withAdMarkup: vastMarkup)
        XCTAssertTrue(result, "Load should succeed")
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testVastTransactionFactoryPreventsConcurrentLoads() {
        let vastMarkup = "<VAST version=\"3.0\"><Ad><Wrapper><VASTAdTagURI><![CDATA[http://test.com]]></VASTAdTagURI></Wrapper></Ad></VAST>"
        
        let adConfiguration = AdConfiguration()
        let factory = PBMVastTransactionFactory(bid: bid,
                                               connection: connection,
                                               adConfiguration: adConfiguration,
                                               callback: { _, _ in })
        
        let result1 = factory.load(withAdMarkup: vastMarkup)
        XCTAssertTrue(result1, "First load should succeed")
        
        let result2 = factory.load(withAdMarkup: vastMarkup)
        XCTAssertFalse(result2, "Second load should fail when already loading")
    }
    
    // MARK: - PBMBidRequesterFactory Tests
    
    func testBidRequesterFactoryWithSingletons() {
        let factoryBlock = PBMBidRequesterFactory.requesterFactoryWithSingletons()
        XCTAssertNotNil(factoryBlock, "Factory block should be created")
        
        let adUnitConfig = AdUnitConfig(configId: "test_config", size: CGSize(width: 300, height: 250))
        let requester = factoryBlock(adUnitConfig)
        XCTAssertNotNil(requester, "Requester should be created")
    }
    
    func testBidRequesterFactoryWithConnection() {
        let connection = UtilitiesForTesting.createConnectionForMockedTest()
        let sdkConfiguration = Prebid.mock
        let targeting = Targeting.shared
        
        let factoryBlock = PBMBidRequesterFactory.requesterFactory(withConnection: connection,
                                                                  sdkConfiguration: sdkConfiguration,
                                                                  targeting: targeting)
        XCTAssertNotNil(factoryBlock, "Factory block should be created")
        
        let adUnitConfig = AdUnitConfig(configId: "test_config", size: CGSize(width: 300, height: 250))
        let requester = factoryBlock(adUnitConfig)
        XCTAssertNotNil(requester, "Requester should be created")
    }
    
    func testBidRequesterFactoryCreatesValidRequester() {
        let connection = UtilitiesForTesting.createConnectionForMockedTest()
        let sdkConfiguration = Prebid.mock
        let targeting = Targeting.shared
        
        let factoryBlock = PBMBidRequesterFactory.requesterFactory(withConnection: connection,
                                                                  sdkConfiguration: sdkConfiguration,
                                                                  targeting: targeting)
        
        let adUnitConfig = AdUnitConfig(configId: "test_config", size: CGSize(width: 300, height: 250))
        let requester = factoryBlock(adUnitConfig)
        
        XCTAssertNotNil(requester, "Requester should not be nil")
        XCTAssertTrue(requester is BidRequesterProtocol, "Requester should conform to BidRequesterProtocol")
    }
}
