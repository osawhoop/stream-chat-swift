//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import AVFoundation
import StreamChat
import UIKit

typealias MediaAttachmentCellView = _MediaAttachmentCellView<NoExtraData>

open class _MediaAttachmentCellView<ExtraData: ExtraDataTypes>: _View, ThemeProvider, ImagePreviewable {
    public var content: ChatMessageMediaAttachment? {
        didSet { updateContentIfNeeded() }
    }
    
    public var attachmentId: AttachmentId? {
        content?.id
    }

    public var didTapOnAttachment: ((ChatMessageMediaAttachment) -> Void)?

    open private(set) lazy var imageView = UIImageView()
        .withoutAutoresizingMaskConstraints

    open private(set) lazy var loadingIndicator = components
        .loadingIndicator.init()
        .withoutAutoresizingMaskConstraints

    open private(set) lazy var uploadingOverlay = components
        .imageUploadingOverlay.init()
        .withoutAutoresizingMaskConstraints
    
    open private(set) lazy var playButton = components
        .playButton.init()
        .withoutAutoresizingMaskConstraints
    
    override open func setUpAppearance() {
        super.setUpAppearance()
        
        imageView.backgroundColor = appearance.colorPalette.background1
        imageView.contentMode = .scaleAspectFill
        imageView.layer.masksToBounds = true
    }

    override open func setUp() {
        super.setUp()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapOnAttachment(_:)))
        uploadingOverlay.addGestureRecognizer(tapRecognizer)
        addGestureRecognizer(tapRecognizer)
        
        playButton.addTarget(self, action: #selector(didTapOnPlay), for: .touchUpInside)
    }

    override open func setUpLayout() {
        super.setUpLayout()
        
        addSubview(imageView)
        imageView.pin(to: self)
        
        addSubview(loadingIndicator)
        loadingIndicator.pin(anchors: [.centerX, .centerY], to: self)
        
        addSubview(uploadingOverlay)
        uploadingOverlay.pin(to: self)

        addSubview(playButton)
        playButton.pin(anchors: [.centerY, .centerX], to: self)
    }

    override open func updateContent() {
        super.updateContent()
        
        loadingIndicator.isHidden = false
        imageView.image = nil
        playButton.isVisible = false
        
        if let url = content?.assetURL {
            components.mediaPreviewLoader.loadPreview(for: url) { [weak self] in
                self?.loadingIndicator.isHidden = true
                
                switch $0 {
                case let .success(preview):
                    self?.imageView.image = preview
                    self?.playButton.isVisible = self?.content?.uploadingState == nil
                case .failure:
                    break
                }
            }
        }
        
        uploadingOverlay.content = content?.uploadingState
        uploadingOverlay.isVisible = uploadingOverlay.content != nil
    }

    @objc open func didTapOnAttachment(_ recognizer: UITapGestureRecognizer) {
        guard let attachment = content else { return }
        
        didTapOnAttachment?(attachment)
    }
    
    @objc open func didTapOnPlay(_ recognizer: UIButton) {
        guard let attachment = content else { return }
        
        didTapOnAttachment?(attachment)
    }
}
