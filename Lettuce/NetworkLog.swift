//
//  NetworkLog.swift
//  Tipsy_Example
//
//  Created by Aly Yakan on 12/26/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import Foundation
import os

extension String {
    /**
     Truncates the string to the specified length number of characters and appends an optional trailing string if longer.
     
     - Parameter length: A `String`.
     - Parameter trailing: A `String` that will be appended after the truncation.
     
     - Returns: A `String` object.
     */
    func truncate(length: Int, trailing: String = "…") -> String {
        if self.count > length {
            return String(self.prefix(length)) + trailing
        } else {
            return self
        }
    }
}

struct NetworkLog {
    let dateCreated: Date = Date()
    private(set) var request: NSMutableURLRequest?
    private(set) var responseData: Data?
    private(set) var requestBody: Data?
    private(set) var error: Error?
    private(set) var response: URLResponse?
    private(set) var startTime: Double = 0.0
    private(set) var endTime: Double = 0.0
    
    var duration: Double {
        return (endTime - startTime) * 1000
    }
    
    var responseJsonObject: Any? {
        guard let data = responseData else {
            return nil
        }
        do {
            return try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            os_log("Couldn't serialize response into json object with error: %@", error.localizedDescription)
        }
        return nil
    }
    
    var requestBodyDictionary: Dictionary<String, Any>? {
        if let requestBody = requestBody {
            let json = try? JSONSerialization.jsonObject(with: requestBody, options: JSONSerialization.ReadingOptions.allowFragments)
            if let json = json as? Dictionary<String, Any> {
                return json
            }
        }
        
        return nil
    }
    
    var statusCode: Int {
        guard let httpResponse = response as? HTTPURLResponse else {
            return 0
        }
        return httpResponse.statusCode
    }
    
    init(request: NSMutableURLRequest?, responseData: Data?, requestBody: Data?, error: Error?, response: URLResponse?, startTime: Double, endTime: Double) {
        self.request = request
        self.responseData = responseData
        self.requestBody = requestBody
        self.error = error
        self.response = response
        self.startTime = startTime
        self.endTime = endTime
    }
    
    func description() -> String {
        return "\(dictionaryRepresentation())"
    }
    
    func dictionaryRepresentation() -> Dictionary<String, Any> {
        var representation: Dictionary<String, Any> = [:]
        
        if let httpResponse = response as? HTTPURLResponse {
            representation["Response Code"] = "\(String(describing: httpResponse.statusCode))"
        }
        
        if let bodyDictionary = requestBodyDictionary {
            representation["Body"] = bodyDictionary
        }
        
        representation["URL"] = String(describing: request?.url)
        representation["Error"] = error.debugDescription
        
        return representation
    }
    
    func isCreated(after time: Double) -> Bool {
        return startTime >= time
    }
    
    func requestURLHasSame(absoluteString urlAbsoluteString: String) -> Bool {
        return request?.url?.absoluteString == urlAbsoluteString
    }
    
    func requestMethodIsEqual(to method: String) -> Bool {
        return request?.httpMethod == method
    }
    
    func requestBodyValue(for key: String) -> Any? {
        return requestBodyDictionary?[key]
    }
}
