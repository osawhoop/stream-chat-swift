//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import AVKit
import StreamChat
import UIKit

public protocol MediaPreviewLoader: AnyObject {
    func loadPreview(for mediaURL: URL, completion: @escaping (Result<UIImage, Error>) -> Void)
}

final class DefaultMediaPreviewLoader: MediaPreviewLoader {
    @Atomic private var cache = Cache<URL, UIImage>()
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning(_:)),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func loadPreview(for mediaURL: URL, completion: @escaping (Result<UIImage, Error>) -> Void) {
        if let cached = cache[mediaURL] {
            return completion(.success(cached))
        }
        
        let asset = AVURLAsset(url: mediaURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        let frameTime = CMTime(seconds: 1, preferredTimescale: 600)
        
        imageGenerator.generateCGImagesAsynchronously(forTimes: [.init(time: frameTime)]) { [weak self] _, image, _, _, error in
            let result: Result<UIImage, Error>
            if let thumbnail = image {
                result = .success(.init(cgImage: thumbnail))
            } else if let error = error {
                result = .failure(error)
            } else {
                log.error("Both error and image are `nil`.")
                return
            }
            
            self?._cache.mutate {
                $0[mediaURL] = try? result.get()
            }
            
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    @objc private func handleMemoryWarning(_ notification: NSNotification) {
        cache.removeAllObjects()
    }
}
