//
//  URLSessionDemux.swift
//  Tipsy
//
//  Created by Aly Yakan on 12/19/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import UIKit

//  Converted to Swift 4 by Swiftify v4.2.16648 - https://objectivec2swift.com/
//
//  URLSessionDemux.m
//  Instabug
//
//  Created by khaled mohamed el morabea on 4/9/17.
//  Copyright © 2017 Moataz. All rights reserved.
//
class URLSessionDemuxTaskInfo: NSObject {
    private(set) var task: URLSessionDataTask?
    private(set) var delegate: URLSessionDataDelegate?
    private(set) var thread: Thread?
    private(set) var modes: [Any]? = []
    
    init(task: URLSessionDataTask?, delegate: URLSessionDataDelegate?, modes: [Any]?) {
        super.init()
        
        self.task = task
        self.delegate = delegate
        self.thread = Thread.current
        self.modes = modes
    }
    
    func performBlock(_ block: @escaping () -> ()) {
        if let aThread = thread {
            perform(#selector(URLSessionDemuxTaskInfo.performBlock(onClientThread:)), on: aThread, with: block, waitUntilDone: false, modes: modes as? [String])
        }
    }
    
    func invalidate() {
        delegate = nil
        thread = nil
    }
    
    @objc func performBlock(onClientThread block: @escaping () -> ()) {
        block()
    }
}

class URLSessionDemux: NSObject, URLSessionDataDelegate {
    private var taskInfoByTaskID: [AnyHashable : Any] = [:]
    private var sessionDelegateQueue: OperationQueue?
    private(set) var configuration: URLSessionConfiguration
    private(set) var session: URLSession?
    
    init(configuration: URLSessionConfiguration = URLSessionConfiguration.default) {
        self.configuration = configuration
        taskInfoByTaskID = [AnyHashable : Any]()
        sessionDelegateQueue = OperationQueue()
        sessionDelegateQueue?.maxConcurrentOperationCount = 1
        sessionDelegateQueue?.name = "QNSURLSessionDemux"
        super.init()
        session = URLSession(configuration: self.configuration, delegate: self, delegateQueue: sessionDelegateQueue)
        session?.sessionDescription = "QNSURLSessionDemux".localizedCapitalized
    }
    
    //performs data with request on the NSURLSession property.
    func dataTask(with request: URLRequest?, delegate: URLSessionDataDelegate?, modes: [Any]?) -> URLSessionDataTask? {
        var modes = modes
        var task: URLSessionDataTask?
        var taskInfo: URLSessionDemuxTaskInfo?
        
        //Check request run loop modes.
        if modes?.count == 0 {
            modes = [RunLoop.Mode.default]
        }
        
        if let aRequest = request {
            task = session?.dataTask(with: aRequest)
        }
        
        taskInfo = URLSessionDemuxTaskInfo(task: task, delegate: delegate, modes: modes)
        
        //Sets dictionary property: task identifier key with task information.
        let lockQueue = DispatchQueue(label: "self")
        lockQueue.sync {
            if let anIdentifier = task?.taskIdentifier, let anInfo = taskInfo {
                taskInfoByTaskID[anIdentifier] = anInfo
            }
        }
        
        //Returns the task
        return task
    }
    
    func setSessionConfiguration(_ sessionConfiguration: URLSessionConfiguration?) {
        guard let sessionConfiguration = sessionConfiguration else {
            return
        }
        
        let protocolsClasses = sessionConfiguration.protocolClasses
        var customizedClasses: [AnyClass] = []
        
        for protocolClass: AnyClass in protocolsClasses ?? [] {
            if !(NSStringFromClass(protocolClass.self) == NSStringFromClass(TestingURLProtocol.self )) {
                customizedClasses.append(protocolClass)
            }
        }
        
        sessionConfiguration.protocolClasses = customizedClasses
        configuration = sessionConfiguration
    }
    
    func taskInfo(for task: URLSessionTask?) -> URLSessionDemuxTaskInfo? {
        var result: URLSessionDemuxTaskInfo?
        let lockQueue = DispatchQueue(label: "self")
        lockQueue.sync {
            guard let taskInfo = taskInfoByTaskID[task?.taskIdentifier ?? 0] as? URLSessionDemuxTaskInfo else {
                return
            }
            result = taskInfo
        }
        return result
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let taskInfo = self.taskInfo(for: task), let delegate = taskInfo.delegate else {
            completionHandler(newRequest)
            return
        }
        
        if delegate.responds(to: #selector(URLSessionDataDelegate.urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:))) {
//            taskInfo.performBlock({
                delegate.urlSession!(session, task: task, willPerformHTTPRedirection: response, newRequest: newRequest, completionHandler: completionHandler)
//            })
        } else {
            completionHandler(newRequest)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let taskInfo = self.taskInfo(for: task), let delegate = taskInfo.delegate else {
            completionHandler(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
            return
        }
        
        if delegate.responds(to: #selector(URLSessionDataDelegate.urlSession(_:task:didReceive:completionHandler:))) {
//            taskInfo.performBlock({
                delegate.urlSession!(session, task: task, didReceive: challenge, completionHandler: completionHandler)
//            })
        } else {
            completionHandler(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
        guard let taskInfo = self.taskInfo(for: task), let delegate = taskInfo.delegate else {
            completionHandler(nil)
            return
        }
        
        if delegate.responds(to: #selector(URLSessionDataDelegate.urlSession(_:task:needNewBodyStream:))) {
//            taskInfo.performBlock({
                delegate.urlSession!(session, task: task, needNewBodyStream: completionHandler)
//            })
        } else {
            completionHandler(nil)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard let taskInfo = self.taskInfo(for: task), let delegate = taskInfo.delegate else {
            return
        }
        
        if delegate.responds(to: #selector(URLSessionDataDelegate.urlSession(_:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:))) {
//            taskInfo.performBlock({
                delegate.urlSession!(session, task: task, didSendBodyData: bytesSent, totalBytesSent: totalBytesSent, totalBytesExpectedToSend: totalBytesExpectedToSend)
//            })
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let taskInfo = self.taskInfo(for: task), let delegate = taskInfo.delegate else {
            return
        }
        
        // This is our last delegate callback so we remove our task info record.
        let lockQueue = DispatchQueue(label: "self")
        _ = lockQueue.sync {
            taskInfoByTaskID.removeValue(forKey: taskInfo.task?.taskIdentifier)
        }
        
        // Call the delegate if required.  In that case we invalidate the task info on the client thread
        // after calling the delegate, otherwise the client thread side of the -performBlock: code can
        // find itself with an invalidated task info.
        if delegate.responds(to: #selector(URLSessionDataDelegate.urlSession(_:task:didCompleteWithError:))) {
//            taskInfo.performBlock({
                delegate.urlSession!(session, task: task, didCompleteWithError: error)
                taskInfo.invalidate()
//            })
        } else {
            taskInfo.invalidate()
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let taskInfo = self.taskInfo(for: dataTask), let delegate = taskInfo.delegate else {
            completionHandler(.allow)
            return
        }
        
        if delegate.responds(to: #selector(URLSessionDataDelegate.urlSession(_:dataTask:didReceive:completionHandler:))) {
//            taskInfo.performBlock({
                delegate.urlSession!(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
//            })
        } else {
            completionHandler(.allow)
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
        guard let taskInfo = self.taskInfo(for: dataTask), let delegate = taskInfo.delegate else {
            return
        }
        
        // The format #selector(URLSessionDataDelegate.urlSession(_:dataTask:didBecome:)) was ambiguous for the compiler.
        let selector = NSSelectorFromString("urlSession:dataTask:didBecome:")
        if delegate.responds(to: selector) {
//            taskInfo.performBlock({
                delegate.urlSession!(session, dataTask: dataTask, didBecome: downloadTask)
//            })
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let taskInfo = self.taskInfo(for: dataTask), let delegate = taskInfo.delegate else {
            return
        }
        
        if delegate.responds(to: #selector(URLSessionDataDelegate.urlSession(_:dataTask:didReceive:))) {
//            taskInfo.performBlock({
                delegate.urlSession!(session, dataTask: dataTask, didReceive: data)
//            })
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        guard let taskInfo = self.taskInfo(for: dataTask), let delegate = taskInfo.delegate else {
            completionHandler(proposedResponse)
            return
        }
        
        if delegate.responds(to: #selector(URLSessionDataDelegate.urlSession(_:dataTask:willCacheResponse:completionHandler:))) {
//            taskInfo.performBlock({
                delegate.urlSession!(session, dataTask: dataTask, willCacheResponse: proposedResponse, completionHandler: completionHandler)
//            })
        } else {
            completionHandler(proposedResponse)
        }
    }
}

