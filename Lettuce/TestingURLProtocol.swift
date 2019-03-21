//
//  TestingURLProtocol.swift
//  Tipsy_Example
//
//  Created by Aly Yakan on 12/19/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import UIKit
import GZIP
import os

private let HandledRequestKey = "InstabugHandledRequestKey"

class TestingURLProtocol: URLProtocol, URLSessionDataDelegate {
    private var _task: URLSessionDataTask?
    override var task: URLSessionDataTask? {
        get { return _task }
        set { _task = newValue }
    }
    
    private var loggedRequest: NSMutableURLRequest?
    private var data: Data?
    private var requestBody: Data?
    private var error: Error?
    private var response: URLResponse?
    private var clientThread: Thread?
    private var modes: [Any] = []
    private var startTime: Double = 0.0
    private var endTime: Double = 0.0
    
    override class func canInit(with request: URLRequest) -> Bool {
        // Skip running the request ourselves if, for any weird reasons, it's missing any of its crucial properties.
        if request.url == nil || request.url?.scheme == nil {
            return false
        }
        if URLProtocol.property(forKey: HandledRequestKey, in: request) != nil {
            return false
        }
        return true
    }
    
    override class func canInit(with task: URLSessionTask) -> Bool {
        let request: URLRequest? = task.currentRequest
        if let aRequest = request {
            if URLProtocol.property(forKey: HandledRequestKey, in: aRequest) != nil {
                return false
            }
        }
        if request == nil {
            return false
        }
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override class func requestIsCacheEquivalent(_ a: URLRequest, to b: URLRequest) -> Bool {
        return super.requestIsCacheEquivalent(a, to: b)
    }
    
    override func startLoading() {
        clientThread = Thread.current
        
        var calculatedModes: [AnyHashable] = []
        var currentMode: String
        
        calculatedModes.append(RunLoop.Mode.default)
        currentMode = RunLoop.current.currentMode.map { $0.rawValue } ?? ""
        
        if (currentMode != "") && !currentMode.isEqual(RunLoop.Mode.default) {
            calculatedModes.append(currentMode)
        }
        modes = calculatedModes
        
        // Create new request that's a clone of the request we were initialised with.
        guard let clonedRequest = (self.request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            return
        }
        
        var bodyData: Data?
        loggedRequest = clonedRequest
        bodyData = bodyOf(request)
        requestBody = bodyData
        
        if let anURL = clonedRequest.url {
            print("Start loading request with URL: [\(clonedRequest.httpMethod)] \(anURL)]")
        }
        
        URLProtocol.setProperty(true, forKey: HandledRequestKey, in: clonedRequest)
        
        if bodyData != nil {
            clonedRequest.httpBody = bodyData
        }
        
        guard let task = TestingURLProtocol.sharedDemux()?.dataTask(with: clonedRequest as URLRequest, delegate: self, modes: modes) else {
            return
        }
        
        task.resume()
        startTime = Date().timeIntervalSince1970
    }
    
    func bodyOf(_ request: URLRequest?) -> Data? {
        let clonedRequest = request as? NSMutableURLRequest
        if clonedRequest?.httpBody != nil {
            return clonedRequest?.httpBody
        }
        
        if clonedRequest?.httpBodyStream != nil, let bodyStream = clonedRequest?.httpBodyStream {
            // Apple Documentation: Before you open the stream to begin the streaming of data, send a scheduleInRunLoop:forMode: message to the stream object to schedule it to receive stream events on a run loop. By doing this, you are helping the delegate to avoid blocking when there is no data on the stream to read. If streaming is taking place on another thread, be sure to schedule the stream object on that thread’s run loop. You should never attempt to access a scheduled stream from a thread different than the one owning the stream’s run loop. Finally, send the NSInputStream instance an open message to start the streaming of data from the input source.
            bodyStream.schedule(in: RunLoop.current, forMode: .default)
            bodyStream.open()
            
            var bodyData = Data()
            var buf = [UInt8](repeating: 0, count: 1024)
            var len: Int = 0
            
            while bodyStream.hasBytesAvailable {
                buf = [UInt8](repeating: 0, count: 1024)
                len = bodyStream.read(&buf, maxLength: 1024)
                if len == 0 {
                    break
                }
                bodyData.append(&buf, count: len)
            }
            
            bodyStream.remove(from: RunLoop.current, forMode: .default)
            bodyStream.close()
            
            return bodyData
        }
        return "".data(using: .utf8)
    }
    
    override func stopLoading() {
        task?.cancel()
        clientThread = nil
    }
    
    // MARK: -
    // MARK: - Setter and Getters
    static var sharedDemuxSDemux: URLSessionDemux = URLSessionDemux()
    class func sharedDemux() -> URLSessionDemux? {
        // `dispatch_once()` call was converted to a static variable initializer
        return sharedDemuxSDemux
    }
    
    // MARK: - NSURLSessionTaskDelegate
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let redirectRequest = (newRequest as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            return
        }
        
        URLProtocol.removeProperty(forKey: HandledRequestKey, in: redirectRequest)
        client?.urlProtocol(self, wasRedirectedTo: redirectRequest as URLRequest, redirectResponse: response)
        
        // Stop our load. The CFNetwork infrastructure will create a new NSURLProtocol instance to run
        // the load of the redirect.
        // The following ends up calling -URLSession:task:didCompleteWithError: with NSURLErrorDomain / NSURLErrorCancelled,
        // which specificallys traps and ignores the error.
        self.task?.cancel()
        client?.urlProtocol(self, didFailWithError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil))
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        self.response = response
        data = Data()
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.data?.append(data)
        client?.urlProtocol(self, didLoad: data)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error == nil {
            if (response is HTTPURLResponse) {
                // Create new request that's a clone of the request we were initialised with.
                let clonedRequest: NSMutableURLRequest? = request as? NSMutableURLRequest
                if clonedRequest == nil {
                    return
                }
                endTime = Date().timeIntervalSince1970
                saveLog()
            } else {
                endTime = Date().timeIntervalSince1970
                saveLog()
            }
            client?.urlProtocolDidFinishLoading(self)
        } else if ((error as NSError?)?.domain)?.isEqual(NSURLErrorDomain) ?? false
            && ((error as NSError?)?.code == NSURLErrorCancelled) {
            // Do nothing. This happens in two cases:
            //
            // 1. During a redirect, in which case the redirect code has already told the client about
            //   the failure
            //
            // 2. If the request is cancelled by a call to -stopLoading, in which case the client doesn't
            //   want to know about the failure
        } else {
            let clonedRequest: NSMutableURLRequest? = request as? NSMutableURLRequest
            if clonedRequest != nil {
                self.error = error
                endTime = Date().timeIntervalSince1970
                saveLog()
            }
            if let anError = error {
                client?.urlProtocol(self, didFailWithError: anError)
            }
        }
    }

    // MARK: - Helpers
    func saveLog() {
        var unzippedBodyData = requestBody
        
        if let requestBodyData = unzippedBodyData as NSData?,
            let unzippedData = requestBodyData.gunzipped(),
            unzippedData.isEmpty == false {
            unzippedBodyData = unzippedData
        }

        let networkLog = NetworkLog(request: loggedRequest,
                                    responseData: data,
                                    requestBody: unzippedBodyData,
                                    error: error,
                                    response: response,
                                    startTime: startTime,
                                    endTime: endTime)
        
        DispatchQueue.global().sync {
            NetworkCapturer.shared.log(networkLog)
        }
    }
    
    func perform(on thread: Thread?, modes: [Any]?, block: () -> ()) {
        var thread = thread
        var modes = modes
        
        if thread == nil {
            thread = Thread.main
        }
        
        if modes?.count == 0 {
            modes = [RunLoop.Mode.default]
        }
        
        if let aThread = thread {
            perform(#selector(TestingURLProtocol.onThreadPerformBlock(_:)), on: aThread, with: block(), waitUntilDone: false, modes: modes as? [String])
        }
    }
    
    @objc func onThreadPerformBlock(_ block: () -> ()) {
        block()
    }
}
