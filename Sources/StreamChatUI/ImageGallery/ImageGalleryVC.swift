//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import Foundation
import StreamChat
import UIKit

/// View controller to showcase and slide through multiple images.
typealias ImageGalleryVC = _ImageGalleryVC<NoExtraData>

/// View controller to showcase and slide through multiple images.
open class _ImageGalleryVC<ExtraData: ExtraDataTypes>:
    _ViewController,
    UIGestureRecognizerDelegate,
    AppearanceProvider,
    UICollectionViewDataSource,
    UICollectionViewDelegate,
    UICollectionViewDelegateFlowLayout,
    ComponentsProvider {
    public enum Item {
        case media(ChatMessageMediaAttachment)
        case image(ChatMessageImageAttachment)
        
        public var shareItem: URL {
            switch self {
            case let .media(media):
                return media.assetURL
            case let .image(image):
                return image.imageURL
            }
        }
        
        public var attachmentId: AttachmentId {
            switch self {
            case let .media(media):
                return media.id
            case let .image(image):
                return image.id
            }
        }
    }

    public struct Content {
        public var message: _ChatMessage<ExtraData>
        public var currentPage: Int
        
        public init(
            message: _ChatMessage<ExtraData>,
            currentPage: Int = 0
        ) {
            self.message = message
            self.currentPage = currentPage
        }
    }
    
    /// Content to display.
    open var content: Content! {
        didSet {
            updateContentIfNeeded()
        }
    }
    
    open var items: [Item] {
        let videos: [Item] = content.message.mediaAttachments.map { .media($0) }
        let images: [Item] = content.message.imageAttachments.map { .image($0) }
        return videos + images
    }
    
    /// Controller for handling the transition for dismissal
    open var transitionController: ZoomTransitionController!
    
    /// `DateComponentsFormatter` for showing when the message was sent.
    public private(set) lazy var dateFormatter: DateComponentsFormatter = {
        let df = DateComponentsFormatter()
        df.allowedUnits = [.minute]
        df.unitsStyle = .full
        return df
    }()
    
    /// `UICollectionViewFlowLayout` instance for `attachmentsCollectionView`.
    public private(set) lazy var attachmentsFlowLayout = UICollectionViewFlowLayout()
    
    /// `UICollectionView` instance to display attachments.
    public private(set) lazy var attachmentsCollectionView: UICollectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: attachmentsFlowLayout
    )
    .withoutAutoresizingMaskConstraints
    
    /// Bar view displayed at the top.
    public private(set) lazy var topBarView = UIView()
        .withoutAutoresizingMaskConstraints
    
    /// Label to show information about the user that sent the message.
    public private(set) lazy var userLabel = UILabel()
        .withoutAutoresizingMaskConstraints
    
    /// Label to show information about the date the message was sent at.
    public private(set) lazy var dateLabel = UILabel()
        .withoutAutoresizingMaskConstraints
    
    /// Bar view displayed at the bottom.
    public private(set) lazy var bottomBarView = UIView()
        .withoutAutoresizingMaskConstraints
    
    /// Label to show which photo is currently being displayed.
    public private(set) lazy var currentPhotoLabel = UILabel()
        .withoutAutoresizingMaskConstraints
    
    /// Button for closing this view controller.
    public private(set) lazy var closeButton = CloseButton()
    
    public private(set) lazy var videoPlaybackBar = _VideoPlaybackView<ExtraData>()
        .withoutAutoresizingMaskConstraints
    
    /// Button for sharing content.
    public private(set) lazy var shareButton = ShareButton()
    
    public private(set) var topBarTopConstraint: NSLayoutConstraint?
    
    public private(set) var bottomBarBottomConstraint: NSLayoutConstraint?

    override open func setUpAppearance() {
        super.setUpAppearance()
        
        topBarView.backgroundColor = appearance.colorPalette.popoverBackground
        bottomBarView.backgroundColor = appearance.colorPalette.popoverBackground
        videoPlaybackBar.backgroundColor = appearance.colorPalette.popoverBackground
        
        userLabel.font = appearance.fonts.bodyBold
        userLabel.textColor = appearance.colorPalette.text
        userLabel.adjustsFontForContentSizeCategory = true
        userLabel.textAlignment = .center
        
        dateLabel.font = appearance.fonts.footnote
        dateLabel.textColor = appearance.colorPalette.subtitleText
        dateLabel.adjustsFontForContentSizeCategory = true
        dateLabel.textAlignment = .center
        
        currentPhotoLabel.font = appearance.fonts.bodyBold
        currentPhotoLabel.textColor = appearance.colorPalette.text
        currentPhotoLabel.adjustsFontForContentSizeCategory = true
        currentPhotoLabel.textAlignment = .center
    }
    
    override open func setUp() {
        super.setUp()
        attachmentsFlowLayout.scrollDirection = .horizontal
        attachmentsFlowLayout.minimumInteritemSpacing = 0
        attachmentsFlowLayout.minimumLineSpacing = 0
                
        attachmentsCollectionView.register(
            _ImageAttachmentCell<ExtraData>.self,
            forCellWithReuseIdentifier: _ImageAttachmentCell<ExtraData>.reuseId
        )
        attachmentsCollectionView.register(
            _MediaAttachmentCell<ExtraData>.self,
            forCellWithReuseIdentifier: _MediaAttachmentCell<ExtraData>.reuseId
        )
        attachmentsCollectionView.contentInsetAdjustmentBehavior = .never
        attachmentsCollectionView.isPagingEnabled = true
        attachmentsCollectionView.alwaysBounceVertical = false
        attachmentsCollectionView.alwaysBounceHorizontal = true
        attachmentsCollectionView.dataSource = self
        attachmentsCollectionView.delegate = self
        
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        panGestureRecognizer.delegate = self
        view.addGestureRecognizer(panGestureRecognizer)
    }
    
    override open func setUpLayout() {
        super.setUpLayout()
        
        view.embed(attachmentsCollectionView)
        
        view.addSubview(topBarView)
        topBarView.pin(anchors: [.leading, .trailing], to: view)
        topBarTopConstraint = topBarView.topAnchor.constraint(equalTo: view.topAnchor)
        topBarTopConstraint?.isActive = true
        
        let topBarContainerStackView = ContainerStackView()
            .withoutAutoresizingMaskConstraints
        topBarView.embed(topBarContainerStackView)
        topBarContainerStackView.preservesSuperviewLayoutMargins = true
        topBarContainerStackView.isLayoutMarginsRelativeArrangement = true
        
        topBarContainerStackView.addArrangedSubview(closeButton)
        
        let infoContainerStackView = ContainerStackView()
        infoContainerStackView.axis = .vertical
        infoContainerStackView.alignment = .center
        infoContainerStackView.spacing = 4
        topBarContainerStackView.addArrangedSubview(infoContainerStackView)
        infoContainerStackView.pin(anchors: [.centerX], to: view)
        
        userLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        infoContainerStackView.addArrangedSubview(userLabel)
        
        infoContainerStackView.addArrangedSubview(dateLabel)
        
        topBarContainerStackView.addArrangedSubview(UIView.spacer(axis: .horizontal))
        
        view.addSubview(bottomBarView)
        bottomBarView.pin(anchors: [.leading, .trailing], to: view)
        bottomBarBottomConstraint = bottomBarView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        bottomBarBottomConstraint?.isActive = true
        
        let bottomBarContainerStackView = ContainerStackView()
            .withoutAutoresizingMaskConstraints
        bottomBarContainerStackView.preservesSuperviewLayoutMargins = true
        bottomBarContainerStackView.isLayoutMarginsRelativeArrangement = true
        bottomBarView.embed(bottomBarContainerStackView)
        
        shareButton.setContentHuggingPriority(.streamRequire, for: .horizontal)
        bottomBarContainerStackView.addArrangedSubview(shareButton)

        currentPhotoLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        bottomBarContainerStackView.addArrangedSubview(currentPhotoLabel)
        currentPhotoLabel.pin(anchors: [.centerX], to: view)
        
        bottomBarContainerStackView.addArrangedSubview(.spacer(axis: .horizontal))
        
        view.addSubview(videoPlaybackBar)
        videoPlaybackBar.pin(anchors: [.leading, .trailing], to: view)
        videoPlaybackBar.bottomAnchor.constraint(equalTo: bottomBarView.topAnchor).isActive = true
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
                
        attachmentsCollectionView.reloadData()
        attachmentsCollectionView.performBatchUpdates(nil) { _ in
            self.updateContent()
            self.attachmentsCollectionView.scrollToItem(
                at: .init(item: self.content.currentPage, section: 0),
                at: .centeredHorizontally,
                animated: false
            )
        }
    }
    
    override open func updateContent() {
        super.updateContent()

        if content.message.author.isOnline {
            dateLabel.text = L10n.Message.Title.online
        } else {
            if
                let lastActive = content.message.author.lastActiveAt,
                let minutes = dateFormatter.string(from: lastActive, to: Date()) {
                dateLabel.text = L10n.Message.Title.seeMinutesAgo(minutes)
            } else {
                dateLabel.text = L10n.Message.Title.offline
            }
        }
        
        userLabel.text = content.message.author.name

        currentPhotoLabel.text = L10n.currentSelection(content.currentPage + 1, items.count)
        
        let videoCell = attachmentsCollectionView.cellForItem(
            at: .init(item: content.currentPage, section: 0)
        ) as? _MediaAttachmentCell<ExtraData>
        
        videoPlaybackBar.player = videoCell?.player
        videoPlaybackBar.isHidden = videoPlaybackBar.player == nil
    }
    
    /// Called whenever user pans with a given `gestureRecognizer`.
    @objc
    open func handlePan(with gestureRecognizer: UIPanGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            transitionController.isInteractive = true
            dismiss(animated: true, completion: nil)
        case .ended:
            guard transitionController.isInteractive else { return }
            transitionController.isInteractive = false
            transitionController.handlePan(with: gestureRecognizer)
        default:
            guard transitionController.isInteractive else { return }
            transitionController.handlePan(with: gestureRecognizer)
        }
    }
    
    /// Called when `closeButton` is tapped.
    @objc
    open func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    /// Called when `shareButton` is tapped.
    @objc
    open func shareButtonTapped() {
        let shareItem = items[content.currentPage].shareItem
        let activityViewController = UIActivityViewController(
            activityItems: [shareItem],
            applicationActivities: nil
        )
        present(activityViewController, animated: true)
    }
    
    /// Updates `currentPage`.
    open func updateCurrentPage() {
        content.currentPage = Int(attachmentsCollectionView.contentOffset.x + attachmentsCollectionView.bounds.width / 2) /
            Int(attachmentsCollectionView.bounds.width)
    }
    
    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }
    
    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let item = items[indexPath.item]
        
        let cell: _GalleryAttachmentCell<ExtraData>
        switch item {
        case let .image(image):
            let imageCell = collectionView.dequeueReusableCell(
                withReuseIdentifier: _ImageAttachmentCell<ExtraData>.reuseId,
                for: indexPath
            ) as! _ImageAttachmentCell<ExtraData>
            imageCell.content = image
            cell = imageCell
        case let .media(media):
            let mediaCell = collectionView.dequeueReusableCell(
                withReuseIdentifier: _MediaAttachmentCell<ExtraData>.reuseId,
                for: indexPath
            ) as! _MediaAttachmentCell<ExtraData>
            mediaCell.content = media
            cell = mediaCell
        }
        
        cell.didTapOnce = { [weak self] in
            self?.imageSingleTapped()
        }
        
        return cell
    }
    
    /// Triggered when the current image is single tapped.
    open func imageSingleTapped() {
        let areBarsHidden = bottomBarBottomConstraint?.constant != 0
        
        topBarTopConstraint?.constant = areBarsHidden ? 0 : -topBarView.frame.height
        bottomBarBottomConstraint?.constant = areBarsHidden ? 0 : bottomBarView.frame.height

        Animate {
            self.topBarView.alpha = areBarsHidden ? 1 : 0
            self.bottomBarView.alpha = areBarsHidden ? 1 : 0
            self.videoPlaybackBar.backgroundColor = areBarsHidden ? self.bottomBarView.backgroundColor : .clear
            self.view.layoutIfNeeded()
        }
    }
    
    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        attachmentsFlowLayout.invalidateLayout()
        super.viewWillTransition(to: size, with: coordinator)
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        collectionView.bounds.size
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        targetContentOffsetForProposedContentOffset proposedContentOffset: CGPoint
    ) -> CGPoint {
        CGPoint(
            x: CGFloat(content.currentPage) * collectionView.bounds.width,
            y: proposedContentOffset.y
        )
    }
    
    open func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateCurrentPage()
    }
    
    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        videoPlaybackBar.player?.pause()
    }
}
