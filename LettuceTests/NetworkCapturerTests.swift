//
//  NetworkCapturerTests.swift
//  LettuceTests
//
//  Created by Aly Yakan on 3/20/19.
//  Copyright © 2019 Instabug. All rights reserved.
//

import XCTest
@testable import Lettuce

let baseURL = "https://api.instabug.com/api/sdk/v3/"

class NetworkCapturerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        NetworkCapturer.shared.reset()
        NetworkCapturer.shared.baseURL = "https://api.instabug.com/api/sdk/v3/"
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
    }
    
    fileprivate func networkLogForTest(path: String = "example", method: String = "GET") -> NetworkLog {
        let request = NSMutableURLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = method
        let data = Data()
        let startTime = Date().timeIntervalSince1970
        return NetworkLog(request: request,
                          responseData: data,
                          requestBody: data,
                          error: nil,
                          response: nil,
                          startTime: startTime,
                          endTime: startTime + 3)
    }
    
    func testWaitForLogThatHasNotBeenFiredWouldReturnCorrectLog() {
        // Given
        let capturer = NetworkCapturer.shared
        let networkLog = networkLogForTest()
        
        // When
        DispatchQueue.global().async {
            sleep(1)
            capturer.log(networkLog)
        }
        
        // That
        guard let captured = capturer.waitForLog(matchingUrlPath: "example", method: "GET", startTime: networkLog.startTime, timeout: 2) else {
            XCTFail("Network request was not captured successfully")
            return
        }
        
        XCTAssertEqual(captured.request?.url?.absoluteString, networkLog.request?.url?.absoluteString)
        XCTAssertTrue(captured.requestMethodIsEqual(to: "GET"))
        XCTAssertEqual(captured.startTime, networkLog.startTime)
    }
    
    func testTimeoutWouldOccurIfNetworkLogHasNotCapturedCorrectLogBeforeTheTimeoutPasses() {
        // Given
        let capturer = NetworkCapturer.shared
        let networkLog = networkLogForTest(path: "timeoutExample")
        
        // When
        DispatchQueue.global().async {
            sleep(3)
            capturer.log(networkLog)
        }
        
        let captured = capturer.waitForLog(matchingUrlPath: "timeoutExample", method: "GET", startTime: networkLog.startTime, timeout: 1)
        
        // That
        XCTAssertNil(captured)
    }
    
    func testLogCapturedBeforeWaitingWouldBeReturned() {
        // Given
        let capturer = NetworkCapturer.shared
        let networkLog = networkLogForTest(path: "beforeWaiting")
        
        // When
        capturer.log(networkLog)
        
        // That
        guard let captured = capturer.waitForLog(matchingUrlPath: "beforeWaiting", method: "GET", startTime: networkLog.startTime, timeout: 2) else {
            XCTFail("Network request was not captured successfully")
            return
        }
        
        XCTAssertEqual(captured.request?.url?.absoluteString, networkLog.request?.url?.absoluteString)
        XCTAssertTrue(captured.requestMethodIsEqual(to: "GET"))
        XCTAssertEqual(captured.startTime, networkLog.startTime)
    }
    
    func testCapturingMultipleLogsWithTheSameURLWouldReturnRequestedNumberOfLogs() {
        // Given
        let capturer = NetworkCapturer.shared
        let networkLog = networkLogForTest(path: "multiple")
        let secondNetworkLog = networkLogForTest(path: "multiple2")
        let thirdNetworkLog = networkLogForTest(path: "multiple3")
        let fourthNetworkLog = networkLogForTest(path: "multiple")
        
        // When
        DispatchQueue.global().async {
            sleep(1)
            capturer.log(networkLog)
            capturer.log(secondNetworkLog)
            capturer.log(thirdNetworkLog)
            capturer.log(fourthNetworkLog)
            capturer.log(networkLog)
        }
        
        // That
        let capturedLogs = capturer.waitForLogs(matchingUrlPath: "multiple", method: "GET", startTime: networkLog.startTime, timeout: 2, requiredLogsCount: 3)
        
        XCTAssertEqual(capturedLogs.count, 3)
        XCTAssertEqual(capturedLogs.first?.request?.url?.absoluteString, networkLog.request?.url?.absoluteString)
        XCTAssertEqual(capturedLogs[1].request?.url?.absoluteString, networkLog.request?.url?.absoluteString)
        XCTAssertEqual(capturedLogs[2].request?.url?.absoluteString, networkLog.request?.url?.absoluteString)
    }
}

