//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
import UIKit

/// Gallery view that displays images.
public typealias ChatMessageImageGallery = _ChatMessageImageGallery<NoExtraData>

/// Gallery view that displays images.
open class _ChatMessageImageGallery<ExtraData: ExtraDataTypes>: _View, ThemeProvider {
    /// Content the image gallery should display.
    public var content: [UIView] = [] {
        didSet { updateContentIfNeeded() }
    }
    
    override open var intrinsicContentSize: CGSize { .init(width: .max, height: .max) }

    // Previews indices locations:
    // When one image available:
    // -------
    // |     |
    // |  0  |
    // |     |
    // -------
    // When two images available:
    // -------------
    // |     |     |
    // |  0  |  1  |
    // |     |     |
    // -------------
    // When three images available:
    // -------------
    // |     |     |
    // |  0  |     |
    // |     |     |
    // ------|  1  |
    // |     |     |
    // |  2  |     |
    // |     |     |
    // -------------
    // When four and more images available:
    // -------------
    // |     |     |
    // |  0  |  1  |
    // |     |     |
    // -------------
    // |     |     |
    // |  2  |  3  |
    // |     |     |
    // -------------
    /// Previews for images.
    public private(set) lazy var itemSpots = [
        UIView().withoutAutoresizingMaskConstraints,
        UIView().withoutAutoresizingMaskConstraints,
        UIView().withoutAutoresizingMaskConstraints,
        UIView().withoutAutoresizingMaskConstraints
    ]

    /// Overlay to be displayed when `content` contains more images than the gallery can display.
    public private(set) lazy var moreImagesOverlay = UILabel()
        .withoutAutoresizingMaskConstraints
    
    /// Container holding all previews.
    public private(set) lazy var previewsContainerView = ContainerStackView()
        .withoutAutoresizingMaskConstraints
    
    /// Left container for previews.
    public private(set) lazy var leftPreviewsContainerView = ContainerStackView()
    
    /// Right container for previews.
    public private(set) lazy var rightPreviewsContainerView = ContainerStackView()

    // MARK: - Overrides

    override open func setUpLayout() {
        previewsContainerView.axis = .horizontal
        previewsContainerView.distribution = .equal
        previewsContainerView.alignment = .fill
        previewsContainerView.spacing = 0
        embed(previewsContainerView)
        
        leftPreviewsContainerView.spacing = 0
        leftPreviewsContainerView.axis = .vertical
        leftPreviewsContainerView.distribution = .equal
        leftPreviewsContainerView.alignment = .fill
        previewsContainerView.addArrangedSubview(leftPreviewsContainerView)
        
        leftPreviewsContainerView.addArrangedSubview(itemSpots[0])
        leftPreviewsContainerView.addArrangedSubview(itemSpots[2])
        
        rightPreviewsContainerView.spacing = 0
        rightPreviewsContainerView.axis = .vertical
        rightPreviewsContainerView.distribution = .equal
        rightPreviewsContainerView.alignment = .fill
        previewsContainerView.addArrangedSubview(rightPreviewsContainerView)
        
        rightPreviewsContainerView.addArrangedSubview(itemSpots[1])
        rightPreviewsContainerView.addArrangedSubview(itemSpots[3])
        
        addSubview(moreImagesOverlay)
        moreImagesOverlay.pin(to: itemSpots[3])
    }

    override open func setUpAppearance() {
        super.setUpAppearance()
        moreImagesOverlay.font = appearance.fonts.title
        moreImagesOverlay.adjustsFontForContentSizeCategory = true
        moreImagesOverlay.textAlignment = .center
        moreImagesOverlay.textColor = appearance.colorPalette.staticColorText
        moreImagesOverlay.backgroundColor = appearance.colorPalette.background5
    }

    override open func updateContent() {
        super.updateContent()
        
        // Clear all spots
        itemSpots
            .flatMap(\.subviews)
            .forEach { $0.removeFromSuperview() }
        
        // Add previews to the spots
        for (preview, spot) in zip(content, itemSpots) {
            spot.addSubview(preview)
            preview.pin(to: spot)
        }
        
        // Show taken spots, hide empty ones
        itemSpots.forEach { spot in
            spot.isHidden = spot.subviews.isEmpty
        }
        
        rightPreviewsContainerView.isHidden = rightPreviewsContainerView.subviews
            .allSatisfy(\.isHidden)
        leftPreviewsContainerView.isHidden = leftPreviewsContainerView.subviews
            .allSatisfy(\.isHidden)
        previewsContainerView.isHidden = previewsContainerView.subviews
            .allSatisfy(\.isHidden)

        let notShownPreviewsCount = content.count - itemSpots.count
        moreImagesOverlay.text = notShownPreviewsCount > 0 ? "+\(notShownPreviewsCount)" : nil
        moreImagesOverlay.isHidden = moreImagesOverlay.text == nil
    }
}
