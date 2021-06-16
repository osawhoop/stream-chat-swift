//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import AVKit
import StreamChat
import UIKit

open class PlayerView: _View {
    open private(set) lazy var player = AVPlayer()
    
    override open func setUp() {
        super.setUp()
        
        playerLayer.player = player
    }
    
    public var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
    
    override public static var layerClass: AnyClass {
        AVPlayerLayer.self
    }
}

public typealias MediaAttachmentCell = _MediaAttachmentCell<NoExtraData>

open class _MediaAttachmentCell<ExtraData: ExtraDataTypes>: _GalleryAttachmentCell<ExtraData> {
    override open class var reuseId: String { String(describing: self) }

    open var player: AVPlayer {
        playerView.player
    }
    
    /// Content of this view.
    open var content: ChatMessageMediaAttachment? {
        didSet { updateContentIfNeeded() }
    }
    
    open private(set) lazy var playerView = PlayerView()
        .withoutAutoresizingMaskConstraints
    
    override open func setUpLayout() {
        super.setUpLayout()
        
        scrollView.addSubview(playerView)
        playerView.pin(to: scrollView)
        playerView.pin(anchors: [.height, .width], to: contentView)
    }
    
    override open func updateContent() {
        super.updateContent()
        
        if let url = content?.assetURL {
            player.replaceCurrentItem(with: .init(url: url))
        } else {
            player.replaceCurrentItem(with: nil)
        }
    }
    
    override open func prepareForReuse() {
        super.prepareForReuse()
        
        content = nil
    }
    
    override open func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        playerView
    }
}
