//
//  LPMetadataProviderTool.swift
//  TSSwiftLinkPreview
//
//  Created by chaos on 2023/7/25.
//

import Foundation
import LinkPresentation

extension LPMetadataProviderTool {
    
    func synchronousLoadMetadata(response: Response, with url: URL) -> Response? {
        var result: Response?
        let semaphore = DispatchSemaphore(value: 0)

        loadMetadata(response: response, from: url) { res in
            result = res
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        
        return result
    }
}

class LPMetadataProviderTool {
    static let shareInstance: LPMetadataProviderTool = LPMetadataProviderTool()
    
    func loadMetadata(response: Response, from url: URL, completion: @escaping (Response?) -> Void) {
        let provider = LPMetadataProvider()
        DispatchQueue.main.async {
            provider.startFetchingMetadata(for: url) { (metadata, error) in
                guard let md = metadata else {
                    completion(nil)
                    return
                }
                var res = response
                res.title = md.title
                if let siteName = md.value(forKeyPath: "_siteName") as? String {
                    res.site = siteName
                }
                if let summary = md.value(forKeyPath: "_summary") as? String {
                    res.description = summary
                }
                if let icon = md.value(forKeyPath: "_iconMetadata._URL") as? URL {
                    res.icon = icon.absoluteString
                }
                if let image = md.value(forKeyPath: "_imageMetadata._URL") as? URL {
                    res.image = image.absoluteString
                }
                if let video = md.value(forKeyPath: "_videoMetadata._URL") as? URL {
                    res.video = video.absoluteString
                }
                completion(res)
            }
        }
    }
}
