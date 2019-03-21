//
//  NetworkLogger.swift
//  Tipsy
//
//  Created by Aly Yakan on 12/19/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import UIKit
import os.log

class NetworkLogQuery: NSObject {
    var urlPath: String
    var requestMethod: String
    var startTime: Double
    var requiredLogsCount: Int = 1
    var results = [NetworkLog]()
    var didReachRequiredNumberOfLogs: Bool {
        return requiredLogsCount == results.count
    }
    
    init(urlPath: String, requestMethod: String, startTime: Double, requiredLogsCount: Int = 1) {
        self.urlPath = urlPath
        self.requestMethod = requestMethod
        self.startTime = startTime
        self.requiredLogsCount = requiredLogsCount
    }
    
    func appendToResultsIfDidNotReachRequiredNumberOfLogs(_ networkLog: NetworkLog) {
        if didReachRequiredNumberOfLogs {
            return
        }
        
        results.insert(networkLog, at: 0)
    }
}

public class NetworkCapturer {
    private typealias ValidationBlock = (NetworkLog)->(Bool)
    
    public static let shared: NetworkCapturer = NetworkCapturer()
    
    private(set) var logs = [NetworkLog]()
    
    public var baseURL = "https://example.com/"
    public private(set) var timeOfInitialization = Date().timeIntervalSince1970
    private var currentNetworkLogQuery: NetworkLogQuery?
    private var currentValidationBlock: ValidationBlock?
    private var didEnterDispatchGroup = false
    private var dispatchGroup: DispatchGroup = DispatchGroup()
    
    private init() {}
    
    // MARK: - Public
    
    public func reset() {
        leaveDispatchGroupIfCurrentlyEntered()
        logs = [NetworkLog]()
        currentNetworkLogQuery?.results.removeAll()
        currentNetworkLogQuery = nil
        didEnterDispatchGroup = false
        dispatchGroup = DispatchGroup()
    }
    
    func log(_ networkLog: NetworkLog) {
        logs.insert(networkLog, at: 0)
        checkIfLogMatchesQueryAndLeaveDispatchGroupIfFound(networkLog: networkLog)
        printToConsole(networkLog: networkLog)
    }
    
    public func waitForLog(matchingUrlPath path: String, method: String, startTime: Double, timeout: Int = 1) -> NetworkLog? {
        let query = NetworkLogQuery(urlPath: path, requestMethod: method, startTime: startTime)
        
        currentNetworkLogQuery = query
        
        // Validation block to match logs with the current query.
        let validationBlock: ValidationBlock = { (networkLog) -> Bool in
            guard let currentQuery = self.currentNetworkLogQuery else {
                return false
            }
            let fullPath = self.baseURL + currentQuery.urlPath
            return networkLog.requestMethodIsEqual(to: currentQuery.requestMethod) &&
                networkLog.requestURLHasSame(absoluteString: fullPath) &&
                networkLog.isCreated(after: currentQuery.startTime)
        }
        
        let queryResultsFromAlreadyCapturedLogs = searchInAlreadyCapturedLogs(matchingQuery: query,
                                                                              validationBlock: validationBlock)
        if let firstQueryResult = queryResultsFromAlreadyCapturedLogs.first {
            // Network log was already captured before the query has been made.
            resetQueryAndResult()
            return firstQueryResult
        }
        
        currentValidationBlock = validationBlock
        
        enterAndWaitForDispatchGroupLeave(with: timeout)
        
        if let firstQueryResult = query.results.first {
            resetQueryAndResult()
            return firstQueryResult
        }
        
        resetQueryAndResult()
        
        return nil
    }
    
    public func waitForLogs(matchingUrlPath path: String, method: String, startTime: Double, timeout: Int = 1, requiredLogsCount: Int = 1) -> [NetworkLog] {
        let query = NetworkLogQuery(urlPath: path, requestMethod: method, startTime: startTime, requiredLogsCount: requiredLogsCount)

        currentNetworkLogQuery = query

        // Validation block to match logs with the current query.
        let validationBlock: ValidationBlock = { (networkLog) -> Bool in
            guard let currentQuery = self.currentNetworkLogQuery else {
                return false
            }
            let fullPath = self.baseURL + currentQuery.urlPath
            return networkLog.requestMethodIsEqual(to: currentQuery.requestMethod) &&
                networkLog.requestURLHasSame(absoluteString: fullPath) &&
                networkLog.isCreated(after: currentQuery.startTime)
        }
        
        let queryResultsFromAlreadyCapturedLogs = searchInAlreadyCapturedLogs(matchingQuery: query,
                                                                              validationBlock: validationBlock,
                                                                              requiredNumberOfLogs: requiredLogsCount)

        if queryResultsFromAlreadyCapturedLogs.count == requiredLogsCount {
            resetQueryAndResult()
            return queryResultsFromAlreadyCapturedLogs
        }
        
        currentNetworkLogQuery?.results = queryResultsFromAlreadyCapturedLogs
        
        currentValidationBlock = validationBlock
        
        enterAndWaitForDispatchGroupLeave(with: timeout)
        
        guard let allResults = currentNetworkLogQuery?.results else {
            resetQueryAndResult()
            return queryResultsFromAlreadyCapturedLogs
        }
        
        resetQueryAndResult()
        
        return allResults
    }
    
    // MARK: - Helpers
    
    private func enterAndWaitForDispatchGroupLeave(with timeout: Int = 1) {
        dispatchGroup.enter()
        didEnterDispatchGroup = true
        
        let waitTime = DispatchTime.now() + DispatchTimeInterval.seconds(timeout)
        
        let _ = dispatchGroup.wait(timeout: waitTime)
        
        guard let runLoopInterval = TimeInterval(exactly: timeout) else {
            return
        }
        
        RunLoop.current.run(until: Date(timeIntervalSinceNow: runLoopInterval))
    }
    
    fileprivate func leaveDispatchGroupIfCurrentlyEntered() {
        if didEnterDispatchGroup {
            dispatchGroup.leave()
            didEnterDispatchGroup = false
        }
    }
    
    private func checkIfLogMatchesQueryAndLeaveDispatchGroupIfFound(networkLog: NetworkLog) {
        guard let query = currentNetworkLogQuery, query.didReachRequiredNumberOfLogs == false else {
            leaveDispatchGroupIfCurrentlyEntered()
            return
        }
        
        if self.networkLog(networkLog, matchesQuery: query) {
            query.appendToResultsIfDidNotReachRequiredNumberOfLogs(networkLog)
        }
    }
    
    private func networkLog(_ log: NetworkLog, matchesQuery query: NetworkLogQuery) -> Bool {
        guard let validationBlock = currentValidationBlock else {
            return false
        }
        return validationBlock(log)
    }
    
    private func searchInAlreadyCapturedLogs(matchingQuery query: NetworkLogQuery,
                                             validationBlock: ValidationBlock,
                                             requiredNumberOfLogs: Int = 1) -> [NetworkLog] {
        if requiredNumberOfLogs < 1 {
            return [NetworkLog]()
        }
        
        var result = [NetworkLog]()
        for networkLog in logs {
            if networkLog.isCreated(after: query.startTime) == false || requiredNumberOfLogs == result.count {
                return result
            }
            
            if validationBlock(networkLog) {
                result.append(networkLog)
            }
        }
        return result
    }
    
    private func printToConsole(networkLog: NetworkLog) {
        guard let logRequestURLString = networkLog.request?.url?.absoluteString else {
            print("Saved network log but couldn't get URL")
            return
        }
        print("Saved Network Log: \(logRequestURLString)")
    }
    
    private func resetQueryAndResult() {
        currentNetworkLogQuery?.results.removeAll()
        currentNetworkLogQuery = nil
    }
}
