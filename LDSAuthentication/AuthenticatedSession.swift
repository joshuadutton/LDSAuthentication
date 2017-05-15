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
import ProcedureKit
import Swiftification

/// Communicates with the authentication service.
///
/// Instances are lightweight; construct a new instance whenever the user's credentials change.
open class AuthenticatedSession: NSObject {
    
    public let networkActivityObservers = ObserverSet<NetworkActivity>()
    
    public enum NetworkActivity {
        case start
        case stop
    }
    
    /// The username used to authenticate this session.
    public let username: String
    
    /// The password used to authenticate this session.
    public let password: String
    
    public let userAgent: String
    public let clientVersion: String
    public let clientUsername: String
    public let clientPassword: String
    public let authenticationURL: URL?
    public let domain: String
    public let trustPolicy: TrustPolicy
    
    static let sessionCookieName = "ObSSOCookie"
    var sessionCookieValue: String?
    
    public var obSSOCookieHeader: (name: String, value: String)? {
        guard let sessionCookieValue = sessionCookieValue else { return nil }
        return (name: "Cookie", value: String(format: "%@=%@", AuthenticatedSession.sessionCookieName, sessionCookieValue))
    }
    
      /// Constructs a session.
    public init(username: String, password: String, userAgent: String, clientVersion: String, clientUsername: String, clientPassword: String, authenticationURL: URL? = URL(string: "https://www.lds.org/login.html"), domain: String = "beta.lds.org", trustPolicy: TrustPolicy = .trust) {
        self.username = username
        self.password = password
        self.userAgent = userAgent
        self.clientVersion = clientVersion
        self.clientUsername = clientUsername
        self.clientPassword = clientPassword
        self.authenticationURL = authenticationURL
        self.domain = domain
        self.trustPolicy = trustPolicy
    }
    
    public lazy var urlSession: Foundation.URLSession = {
        return URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    }()
    
    let procedureQueue = ProcedureQueue()
    private let dataQueue = DispatchQueue(label: "LDSAnnotations.session.syncqueue", attributes: [])
    
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
    public func authenticate(_ completion: @escaping (Error?) -> Void) {
        let operation = AuthenticateOperation(session: self)
        operation.add(observer: BlockObserver(didFinish: { operation, errors in
            completion(errors.first)
        }))
        procedureQueue.addOperation(operation)
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
