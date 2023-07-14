// 
// Copyright 2023 New Vector Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import UIKit
import WebKit

typealias CompletionHandler<T> = ((T) -> Void)

extension URLPreviewLoader {
    
    func synchronousPreviewLoader(with url: URL) -> String? {
        var string: String?
        let semaphore = DispatchSemaphore(value: 0)

        loadWebPage(from: url) { result in
            string = result
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        
        return string
    }
}

class URLPreviewLoader: NSObject, WKNavigationDelegate {
    static let shareInstance: URLPreviewLoader = URLPreviewLoader()
    
    private var timeoutTimer: Timer?
    private var waitParseURL: [URL] = []
    private var parsingURL: URL?
    private var webView: WKWebView?
    private var completionHandlersMap: [String: [CompletionHandler<String?>]] = [:]
    
    func loadWebPage(from url: URL, completion: @escaping CompletionHandler<String?>) {
        DispatchQueue.main.async {
            guard self.parsingURL == nil else {
                print("[URLPreviewLoader] loadWebPage url need wait: \(url.absoluteString), waitCount: \(self.waitParseURL.count)")
                if self.parsingURL?.absoluteString == url.absoluteString,
                   var completionHandlers = self.completionHandlersMap[url.absoluteString] {
                    completionHandlers.append(completion)
                    self.completionHandlersMap[url.absoluteString] = completionHandlers
                } else {
                    self.waitParseURL.append(url)
                    self.completionHandlersMap[url.absoluteString] = [completion]
                }
                return
            }
            
            print("[URLPreviewLoader] loadWebPage with url \(url.absoluteString)")
            
            let webView = WKWebView()
            if #available(iOS 14.0, *) {
                webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true
            } else {
                // Fallback on earlier versions
            }
            webView.navigationDelegate = self
            
            self.parsingURL = url
            self.completionHandlersMap[url.absoluteString] = [completion]
            
            let request = URLRequest(url: url)
            webView.load(request)
            webView.isHidden = true
            if let mainWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                mainWindow.addSubview(webView)
            }
            
            self.webView = webView
            self.stopTimer()
            self.startTimer()
        }
    }
    
    func parsingWaitingURL() {
        stopTimer()
        if let webView = self.webView,
            let url = waitParseURL.first {
            self.waitParseURL.removeFirst()
            self.parsingURL = url
            print("[URLPreviewLoader] parsingWaitingURL: \(url.absoluteString), waitCount: \(self.waitParseURL.count)")
            let request = URLRequest(url: url)
            webView.load(request)
            startTimer()
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] (result, error) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard error == nil else {
                    self.completionHandlerResult(with: nil)
                    return
                }
                self.completionHandlerResult(with: result as? String)
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[URLPreviewLoader] didFail error \(error.localizedDescription) data:\(Date())")
        completionHandlerResult(with: nil)
    }
    
    func completionHandlerResult(with htmlString: String?) {
        guard let url = self.parsingURL,
              let completionHandlers = self.completionHandlersMap[url.absoluteString],
              completionHandlers.count > 0 else {
            print("[URLPreviewLoader] didFinish but no completionHandler with url \(self.parsingURL?.absoluteString ?? "")")
            return
        }
        print("[URLPreviewLoader] didFinish url \(url.absoluteString), htmlString is nil\(htmlString == nil), data:\(Date())")
        
        self.parsingURL = nil
        self.completionHandlersMap.removeValue(forKey: url.absoluteString)
        self.parsingWaitingURL()
        guard let htmlString = htmlString else {
            completionHandlers.forEach({
                $0(nil)
            })
            return
        }
        completionHandlers.forEach({
            $0(htmlString)
        })
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        var disposition: URLSession.AuthChallengeDisposition = URLSession.AuthChallengeDisposition.performDefaultHandling
        var credential: URLCredential?
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let serverTrust = challenge.protectionSpace.serverTrust {
            disposition = URLSession.AuthChallengeDisposition.useCredential
            credential = URLCredential(trust: serverTrust)
        }
        completionHandler(disposition, credential)
    }
}

// MARK: Timer
extension URLPreviewLoader {
    
    func startTimer() {
        guard let parsingURL = self.parsingURL else {
            return
        }
        print("[URLPreviewLoader] startTimer \(parsingURL.absoluteString), data:\(Date())")
        let timeoutInterval: TimeInterval = 30.0
        timeoutTimer = Timer.scheduledTimer(timeInterval: timeoutInterval, target: self, selector: #selector(timeoutReached), userInfo: nil, repeats: false)
    }
    
    @objc func timeoutReached() {
        guard let parsingURL = self.parsingURL else {
            return
        }
        print("[URLPreviewLoader] timeoutReached url \(parsingURL.absoluteString), data:\(Date())")
        self.completionHandlerResult(with: nil)
    }

    func stopTimer() {
        guard let timeoutTimer = timeoutTimer else { return }
        print("[URLPreviewLoader] stopTimer \(self.parsingURL?.absoluteString ?? ""), data:\(Date())")
        timeoutTimer.invalidate()
        self.timeoutTimer = nil
    }
    
}
