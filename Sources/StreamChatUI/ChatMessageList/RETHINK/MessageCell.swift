//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
import UIKit

class MessageCell<ExtraData: ExtraDataTypes>: _CollectionViewCell, UIConfigProvider {
    static var reuseId: String { "message_cell" }

    private(set) var messageContentView: MessageContentView<ExtraData>?

    override func prepareForReuse() {
        super.prepareForReuse()

        messageContentView?.prepareForReuse()
    }

    func setUpMessageContentIfNeeded(
        contentViewClass: MessageContentView<ExtraData>.Type,
        options: ChatMessageLayoutOptions
    ) {
        guard messageContentView == nil else {
            assert(type(of: messageContentView!) == contentViewClass)
            return
        }

        messageContentView = contentViewClass.init().withoutAutoresizingMaskConstraints
        // We `embed` before `setUpLayoutIfNeeded` to have correct `uiConfig` at the time when
        // messageContentView's subviews are instantiated
        contentView.embed(messageContentView!)
        messageContentView!.setUpLayoutIfNeeded(options: options)
    }

    override open func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        let preferredAttributes = super.preferredLayoutAttributesFitting(layoutAttributes)

        let targetSize = CGSize(
            width: layoutAttributes.frame.width,
            height: UIView.layoutFittingCompressedSize.height
        )

        preferredAttributes.frame.size = contentView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        return preferredAttributes
    }
}
