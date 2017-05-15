//
// Copyright (c) 2016 Hilton Campbell
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import Foundation
import PSOperations
import Swiftification

/// Instances are lightweight; construct a new instance whenever the user's credentials change.
open class AuthenticatedSession: NSObject {
    
    open let authenticationStatusObservers = ObserverSet<AuthenticationStatus>()
    
    /// The username used to authenticate this session.
    open let username: String
    
    /// The password used to authenticate this session.
    open let password: String
    
    open let authenticationURL: URL?
    open let domain: String
    let trustPolicy: TrustPolicy
    
    public enum AuthenticationStatus {
        case unauthenticated
        case authenticationInProgress
        case authenticationSuccessful
        case authenticationFailed
    }
    
    open var authenticationStatus: AuthenticationStatus = .unauthenticated {
        didSet {
            authenticationStatusObservers.notify(authenticationStatus)
        }
    }
    
    /// Constructs a session.
    public init(username: String, password: String, authenticationURL: URL? = URL(string: "https://beta.lds.org/login.html"), domain: String = "beta.lds.org", trustPolicy: TrustPolicy = .trust) {
        self.username = username
        self.password = password
        self.authenticationURL = authenticationURL
        self.domain = domain
        self.trustPolicy = trustPolicy
    }
    
    open lazy var urlSession: Foundation.URLSession = {
        return Foundation.URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    }()
    
    open let operationQueue = OperationQueue()
    
    var lastSuccessfulAuthenticationDate: Date?
    
    var authenticated: Bool {
        let gracePeriod: TimeInterval = 15 * 60
        if let lastSuccessfulAuthenticationDate = lastSuccessfulAuthenticationDate, Date().timeIntervalSince(lastSuccessfulAuthenticationDate) < gracePeriod {
            return true
        } else {
            return false
        }
    }
    
    /// Authenticates against the server.
    open func authenticate(_ completion: @escaping (NSError?) -> Void) {
        authenticationStatus = .authenticationInProgress
        let operation = AuthenticateOperation(session: self)
        operation.addObserver(BlockObserver(startHandler: nil, produceHandler: nil) { operation, errors in
            self.authenticationStatus = errors.isEmpty ? .AuthenticationSuccessful : .AuthenticationFailed
            completion(errors.first)
        })
        operationQueue.addOperation(operation)
    }
    
}

// MARK: - NSURLSessionDelegate

extension AuthenticatedSession: URLSessionDelegate {
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        switch trustPolicy {
        case .validate:
            completionHandler(.performDefaultHandling, nil)
        case .trust:
            completionHandler(.useCredential, challenge.protectionSpace.serverTrust.flatMap { URLCredential(trust: $0) })
        }
    }
    
}

// MARK: - Auth redirection

extension AuthenticatedSession: URLSessionTaskDelegate {
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        if response.statusCode == 302 {
            completionHandler(nil)
        } else {
            completionHandler(request)
        }
    }
    
}
