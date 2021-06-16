//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
import UIKit

public typealias ImageAttachmentCell = _ImageAttachmentCell<NoExtraData>

open class _ImageAttachmentCell<ExtraData: ExtraDataTypes>: _GalleryAttachmentCell<ExtraData> {
    override open class var reuseId: String { String(describing: self) }
    
    /// Content of this view.
    open var content: ChatMessageImageAttachment? {
        didSet { updateContentIfNeeded() }
    }
    
    /// Image view showing the single image.
    public private(set) lazy var imageView = UIImageView()
        .withoutAutoresizingMaskConstraints
    
    override open func setUp() {
        super.setUp()
        
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFit
    }
    
    override open func setUpLayout() {
        super.setUpLayout()
        
        scrollView.addSubview(imageView)
        imageView.pin(anchors: [.height, .width], to: contentView)
    }
    
    override open func updateContent() {
        super.updateContent()

        if let url = content?.imageURL {
            imageView.loadImage(
                from: url,
                resize: false,
                components: components
            )
        } else {
            imageView.image = nil
        }
    }
    
    override open func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }
    
    override open func prepareForReuse() {
        super.prepareForReuse()
        
        content = nil
    }
}
