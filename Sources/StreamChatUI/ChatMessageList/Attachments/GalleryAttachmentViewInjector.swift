//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
import UIKit

/// The delegate used `GalleryAttachmentViewInjector` to communicate user interactions.
public protocol GalleryContentViewDelegate: ChatMessageContentViewDelegate {
    /// Called when the user taps on one of the image attachments.
    func didTapOnImageAttachment(
        _ attachment: ChatMessageImageAttachment,
        previews: [ImagePreviewable],
        at indexPath: IndexPath
    )
    
    /// Called when the user taps on one of the media attachments.
    func didTapOnMediaAttachment(
        _ attachment: ChatMessageMediaAttachment,
        previews: [ImagePreviewable],
        at indexPath: IndexPath
    )
}

public typealias GalleryAttachmentViewInjector = _GalleryAttachmentViewInjector<NoExtraData>

open class _GalleryAttachmentViewInjector<ExtraData: ExtraDataTypes>: _AttachmentViewInjector<ExtraData> {
    open private(set) lazy var galleryView = contentView
        .components
        .imageGalleryView
        .init()
        .withoutAutoresizingMaskConstraints

    override open func contentViewDidLayout(options: ChatMessageLayoutOptions) {
        contentView.bubbleView?.clipsToBounds = true
        contentView.bubbleContentContainer.insertArrangedSubview(galleryView, at: 0, respectsLayoutMargins: false)

        NSLayoutConstraint.activate([
            galleryView.widthAnchor.pin(equalTo: galleryView.heightAnchor)
        ])
    }
    
    override open func contentViewDidUpdateContent() {
        galleryView.content = imageAttachments.map(preview) + mediaAttachments.map(preview)
    }

    open func handleTapOnAttachment(_ attachment: ChatMessageImageAttachment) {
        guard let indexPath = contentView.indexPath?() else { return }
        
        (contentView.delegate as? GalleryContentViewDelegate)?.didTapOnImageAttachment(
            attachment,
            previews: galleryView.content.compactMap { $0 as? ImagePreviewable },
            at: indexPath
        )
    }
    
    open func handleTapOnAttachment(_ attachment: ChatMessageMediaAttachment) {
        guard let indexPath = contentView.indexPath?() else { return }
        
        (contentView.delegate as? GalleryContentViewDelegate)?.didTapOnMediaAttachment(
            attachment,
            previews: galleryView.content.compactMap { $0 as? ImagePreviewable },
            at: indexPath
        )
    }
}

private extension _GalleryAttachmentViewInjector {
    var imageAttachments: [ChatMessageImageAttachment] {
        contentView.content?.imageAttachments ?? []
    }
    
    var mediaAttachments: [ChatMessageMediaAttachment] {
        contentView.content?.mediaAttachments ?? []
    }
    
    func preview(for mediaAttachment: ChatMessageMediaAttachment) -> UIView {
        let preview = contentView
            .components
            .mediaAttachmentCellView
            .init()
            .withoutAutoresizingMaskConstraints
        
        preview.didTapOnAttachment = { [weak self] in
            self?.handleTapOnAttachment($0)
        }
        
        preview.content = mediaAttachment

        return preview
    }
    
    func preview(for imageAttachment: ChatMessageImageAttachment) -> UIView {
        let preview = contentView
            .components
            .imageAttachmentCellView
            .init()
            .withoutAutoresizingMaskConstraints
        
        preview.didTapOnAttachment = { [weak self] in
            self?.handleTapOnAttachment($0)
        }
        
        preview.content = imageAttachment

        return preview
    }
}
