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

class AuthenticateOperation: Procedure {
    
    let session: AuthenticatedSession
    
    init(session: AuthenticatedSession) {
        self.session = session
        
        super.init()
        
        add(condition: MutuallyExclusive<AuthenticateOperation>())
    }
    
    override func execute() {
        if session.authenticated {
            finish()
            return
        }
        
        guard let url = session.authenticationURL else {
            let error = AuthenticationError.errorWithCode(.unknown, failureReason: "Missing authentication URL")
            Log.error(error)
            finish(withError: error)
            return
        }
        
        var request = URLRequest(url: url)
        
        guard let cookieValue = "wh=\(session.domain) wu=/header wo=1 rh=http://\(session.domain) ru=/header".stringByAddingPercentEscapesForQueryValue(), let cookie = HTTPCookie(properties: [
            HTTPCookiePropertyKey.name: "ObFormLoginCookie",
            HTTPCookiePropertyKey.value: cookieValue,
            HTTPCookiePropertyKey.domain: ".lds.org",
            HTTPCookiePropertyKey.path : "/login.html",
            HTTPCookiePropertyKey.expires: Date(timeIntervalSinceNow: 60 * 60),
        ]) else {
            let error = AuthenticationError.errorWithCode(.unknown, failureReason: "Malformed authentication domain")
            Log.error(error)
            finish(withError: error)
            return
        }
        request.allHTTPHeaderFields = HTTPCookie.requestHeaderFields(with: [cookie])
        
        request.timeoutInterval = 90
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        guard let body = [
            "username": session.username,
            "password": session.password,
        ].map({ key, value in
            return "\(key)=\(value.stringByAddingPercentEscapesForQueryValue()!)"
        }).joined(separator: "&").data(using: String.Encoding.utf8) else {
            let error = AuthenticationError.errorWithCode(.unknown, failureReason: "Malformed parameter")
            Log.error(error)
            finish(withError: error)
            return
        }
        
        request.httpBody = body
        request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
        
        let authenticationDate = Date()
        
        let task = session.urlSession.dataTask(with: request, completionHandler: { data, response, error in
            self.session.networkActivityObservers.notify(.stop)
            if let error = error {
                Log.error(error)
                self.finish(withError: error)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let responseHeaderFields = httpResponse.allHeaderFields as? [String: String], let responseURL = httpResponse.url else {
                let error = AuthenticationError.errorWithCode(.unknown, failureReason: "Unexpected response")
                Log.error(error)
                self.finish(withError: error)
                return
            }
            
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: responseHeaderFields, for: responseURL)
            if cookies.contains(where: { $0.name == "ObFormLoginCookie" && $0.value == "done" }) {
                self.session.lastSuccessfulAuthenticationDate = authenticationDate
                self.session.sessionCookieValue = cookies.find(where: { $0.name == AuthenticatedSession.sessionCookieName })?.value
                self.finish()
                return
            }
            
            let errorKey: String
            if let locationValue = responseHeaderFields["Location"], let errorRange = locationValue.range(of: "error=") {
                errorKey = locationValue.substring(from: errorRange.upperBound)
            } else {
                errorKey = "unknown"
            }
            
            let error: Error
            switch errorKey {
            case "authfailed":
                error = AuthenticationError.errorWithCode(.authenticationFailed, failureReason: "Incorrect username and/or password.")
            case "lockout":
                error = AuthenticationError.errorWithCode(.lockedOut, failureReason: "Account is locked.")
            case "pwdexpired":
                error = AuthenticationError.errorWithCode(.passwordExpired, failureReason: "Password is expired.")
            default:
                error = AuthenticationError.errorWithCode(.unknown, failureReason: "Authentication failed for an unknown reason.")
            }
            Log.error(error)
            self.finish(withError: error)
        }) 
        session.networkActivityObservers.notify(.start)
        task.resume()
    }
    
}
