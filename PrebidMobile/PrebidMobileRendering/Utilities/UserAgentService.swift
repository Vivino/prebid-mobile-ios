/*   Copyright 2018-2021 Prebid.org, Inc.
 
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

import UIKit
import WebKit

/**
 A service that manages the user agent string for the application.
 
 This class provides a singleton instance that allows you to access the user agent string,
 ensuring it is loaded from persistent storage or fetched using a WKWebView if necessary.
 The user agent string is stored in UserDefaults to minimize fetch time on subsequent app launches.
 
 - Note: This class is designed to be thread-safe.
 */
@objc(PBMUserAgentService)
@objcMembers
public class UserAgentService: NSObject {
    
    /// The shared singleton instance of `UserAgentService`.
    public static let shared = UserAgentService()
    
    // Constants
    private var webView: WKWebView?
    private let semaphore = DispatchSemaphore(value: 1)
    private var _userAgent: String = ""
    
    /**
     The user agent string.
     
     This property is thread-safe. The getter and setter use a semaphore to ensure
     that access to the underlying `_userAgent` property is synchronized.
     
     - Returns: The user agent string.
     */
    public private(set) var userAgent: String {
        get {
            semaphore.wait()
            defer { semaphore.signal() }
            return _userAgent
        }
        set {
            semaphore.wait()
            defer { semaphore.signal() }
            _userAgent = newValue
        }
    }
    
    /**
     Initializes a new `UserAgentService` instance.
     
     This initializer attempts to load the user agent from UserDefaults. If it is not found,
     it fetches the user agent using a WKWebView and sets it.
     */
    public override init() {
        super.init()
        if let ua = userAgentFromDefaults {
            _userAgent = ua
        } else {
            fetchUserAgent { [weak self] ua in
                guard let self = self else { return }
                /// Persist the user agnet string for next app launch
                self.userAgentFromDefaults = ua
            }
        }
    }
    
    /**
     Fetches the user agent string using a WKWebView.
     
     This method runs the WKWebView operation on the main thread with a delay and uses a completion handler
     to return the fetched user agent or a fallback value.
     
     - Parameter completion: A closure that is called with the fetched user agent string.
     */
    public func fetchUserAgent(completion: ((String) -> Void)? = nil) {
        // user agent has been already generated
        guard userAgent.isEmpty else {
            completion?(userAgent)
            return
        }
        
        // Create the webView on the main thread
        DispatchQueue.main.async {
            self.webView = WKWebView()
        }
        
        // Evaluate JavaScript with a delay to ensure webView is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, let webView = self.webView else {
                completion?("")
                return
            }
            webView.evaluateJavaScript("navigator.userAgent", completionHandler: { result, error in
                // Deallocate the webview as it's not needed anymore
                self.webView = nil
                
                if let error {
                    Log.error(error.localizedDescription)
                }
                
                if let ua = result as? String, !ua.isEmpty  {
                    self.userAgent = "\(ua)"
                }
                completion?(self.userAgent)
            })
        }
    }
}

/**
 An extension of `UserAgentService` that handles persistence of the user agent string in UserDefaults.
 */
extension UserAgentService {
    
    /// The key used to store the user agent dictionary in UserDefaults.
    private var userDefaultsKey: String {
        "UserAgentDictionary"
    }
    
    /// Computed property to get the current OS version.
    private var osVersion: String {
        UIDevice.current.systemVersion
    }
    
    /// Computed property to get the user agent dictionary from UserDefaults.
    private var userAgentDictionary: [String: String] {
        UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: String] ?? [:]
    }
    
    /// Computed property to get and set the user agent for the current OS version in UserDefaults.
    private var userAgentFromDefaults: String? {
        get {
            return userAgentDictionary[osVersion]
        }
        set {
            // Don't persist nil or empty user agent strings
            guard let val = newValue, !val.isEmpty else { return }
            var userAgentDictionary = userAgentDictionary
            userAgentDictionary[osVersion] = newValue
            UserDefaults.standard.set(userAgentDictionary, forKey: userDefaultsKey)
        }
    }
    
    /**
     Resets the user agent defaults by removing the stored user agent dictionary from UserDefaults.
     */
    func resetDefaults() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
