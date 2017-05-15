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
import Locksmith

public class SharedKeychainController {
    
    public static let shared = SharedKeychainController()
    
    fileprivate static let serviceName = "org.lds.account"
    fileprivate static let userAccountName = "credentials"
    
    public struct Account {
        let username: String
        let password: String
        
        public init(username: String, password: String) {
            self.username = username
            self.password = password
        }
    }
    
    public func addOrUpdate(account: Account) throws {
        if var accounts = accounts {
            accounts[account.username] = account.password
            self.accounts = accounts
        } else {
            accounts = [account.username: account.password]
        }
    }
    
    public func delete(username: String) throws {
        guard var accounts = accounts else { return }
        
        accounts.removeValue(forKey: username)
        self.accounts = accounts
    }
    
    public var usernames: [String]? {
        return accounts?.map { $0.key }
    }
    
    public func password(forUsername username: String) -> String? {
        return accounts?[username] as? String
    }
    
    private var accounts: [String: Any]? {
        get {
            return Locksmith.loadDataForUserAccount(userAccount: SharedKeychainController.userAccountName, inService: SharedKeychainController.serviceName)
        }
        set {
            do {
                if let newValue = newValue {
                    if accounts == nil {
                        try Locksmith.saveData(data: newValue, forUserAccount: SharedKeychainController.userAccountName, inService: SharedKeychainController.serviceName)
                    } else {
                        try Locksmith.updateData(data: newValue, forUserAccount: SharedKeychainController.userAccountName, inService: SharedKeychainController.serviceName)
                    }
                } else {
                    try Locksmith.deleteDataForUserAccount(userAccount: SharedKeychainController.userAccountName, inService: SharedKeychainController.serviceName)
                }
            } catch {
                print("Error setting keychain \(error)")
            }
        }
    }
    
}
