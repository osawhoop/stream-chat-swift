//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
import UIKit

public typealias ChatMessageListRouter = _ChatMessageListRouter<NoExtraData>

open class _ChatMessageListRouter<ExtraData: ExtraDataTypes>: ChatRouter<_ChatMessageListVC<ExtraData>>,
    UIViewControllerTransitioningDelegate {
    public private(set) lazy var zoomTransitionController = ZoomTransitionController()
    public private(set) lazy var transitionController = MessageActionsTransitionController<ExtraData>()
    
    open func showMessageActionsPopUp(
        messageContentViewClass: _ChatMessageContentView<ExtraData>.Type,
        messageContentFrame: CGRect,
        messageContentView: _ChatMessageContentView<ExtraData>,
        messageData: _ChatMessageGroupPart<ExtraData>,
        messageActionsController: _ChatMessageActionsVC<ExtraData>,
        messageReactionsController: _ChatMessageReactionsVC<ExtraData>?
    ) {
        let popup = _ChatMessagePopupVC<ExtraData>()
        popup.messageContentViewClass = messageContentViewClass
        popup.message = messageData
        popup.messageViewFrame = messageContentFrame
        popup.actionsController = messageActionsController
        popup.reactionsController = messageReactionsController
        popup.modalPresentationStyle = .overFullScreen
//        popup.modalTransitionStyle = .crossDissolve
        popup.transitioningDelegate = transitionController
        
        transitionController.messageContentView = messageContentView
        
        rootViewController.present(popup, animated: true)
    }
    
    open func showPreview(for attachment: ChatMessageDefaultAttachment) {
        let preview = ChatMessageAttachmentPreviewVC()
        preview.content = attachment.type == .file ? attachment.url : attachment.imageURL
        
        let navigation = UINavigationController(rootViewController: preview)
        rootViewController.present(navigation, animated: true)
    }
    
    open func openLink(_ link: ChatMessageDefaultAttachment) {
        let preview = ChatMessageAttachmentPreviewVC()
        preview.content = link.url
        
        let navigation = UINavigationController(rootViewController: preview)
        rootViewController.present(navigation, animated: true)
    }
    
    open func showImageGallery(
        for message: _ChatMessage<ExtraData>,
        initialAttachment: ChatMessageDefaultAttachment,
        previews: [_ChatMessageImageGallery<ExtraData>.ImagePreview],
        from chatMessageListVC: _ChatMessageListVC<ExtraData>
    ) {
        guard
            let preview = previews.first(where: { $0.content?.attachment.id == initialAttachment.id })
        else { return }
        let imageGalleryVC = _ImageGalleryVC<ExtraData>()
        imageGalleryVC.modalPresentationStyle = .overFullScreen
        imageGalleryVC.transitioningDelegate = self
        imageGalleryVC.content = message
        imageGalleryVC.initialAttachment = initialAttachment
        imageGalleryVC.transitionController = zoomTransitionController
        
        zoomTransitionController.presentedVCImageView = {
            let cell = imageGalleryVC.attachmentsCollectionView.cellForItem(
                at: IndexPath(item: imageGalleryVC.currentPage, section: 0)
            ) as? ImageCollectionViewCell
            return cell?.imageView
        }
        zoomTransitionController.presentingImageView = {
            let attachment = imageGalleryVC.images[imageGalleryVC.currentPage]
            return previews.first(where: { $0.content?.attachment.id == attachment.id })?.imageView
        }
        zoomTransitionController.fromImageView = preview.imageView
        rootViewController.present(imageGalleryVC, animated: true)
    }

    public func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        zoomTransitionController.animationController(
            forPresented: presented,
            presenting: presenting,
            source: source
        )
    }
    
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        zoomTransitionController.animationController(forDismissed: dismissed)
    }
    
    public func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning)
        -> UIViewControllerInteractiveTransitioning? {
        zoomTransitionController.interactionControllerForDismissal(using: animator)
    }
}

open class MessageActionsTransitionController<ExtraData: ExtraDataTypes>: NSObject, UIViewControllerTransitioningDelegate,
    UIViewControllerAnimatedTransitioning {
    open var isPresenting: Bool = false
    open weak var messageContentView: _ChatMessageContentView<ExtraData>!
    
    public func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        isPresenting = true
        return self
    }
    
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        isPresenting = false
//        return self
        return nil
    }
    
    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
//        0.25
        2
    }
    
    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if isPresenting {
            animatePresent(using: transitionContext)
        } else {
            animateDismiss()
        }
    }
    
    open func animatePresent(using transitionContext: UIViewControllerContextTransitioning) {
        guard
            let toVC = transitionContext.viewController(forKey: .to) as? _ChatMessagePopupVC<ExtraData>,
            let fromVC = transitionContext.viewController(forKey: .from)
        else { return }
        messageContentView.isHidden = true
        toVC.messageContentView.isHidden = true
        
        transitionContext.containerView.addSubview(toVC.view)
        
        let blurSnapshot = toVC.view.snapshotView(afterScreenUpdates: true)!
        blurSnapshot.frame = toVC.view.frame
        transitionContext.containerView.addSubview(blurSnapshot)
        
        let fromVCSnapshot = fromVC.view.snapshotView(afterScreenUpdates: true)
        if let fromVCSnapshot = fromVCSnapshot {
            transitionContext.containerView.addSubview(fromVCSnapshot)
            fromVCSnapshot.frame = fromVC.view.frame
            fromVC.view.isHidden = true
        }
        
//        let toVCSnapshot = toVC.view.snapshotView(afterScreenUpdates: true)
//        if let toVCSnapshot = toVCSnapshot {
//            transitionContext.containerView.addSubview(toVCSnapshot)
//            toVCSnapshot.frame = toVC.view.frame
//            toVCSnapshot.alpha = 0
//            toVC.view.isHidden = true
//        }
        let actionsSnapshot = toVC.actionsController.view.snapshotView(afterScreenUpdates: true)!
        let actionsFrame = toVC.actionsController.view.superview!.convert(toVC.actionsController.view.frame, to: nil)
        actionsSnapshot.frame = actionsFrame
        actionsSnapshot.transform = CGAffineTransform(scaleX: 0, y: 0)
        transitionContext.containerView.addSubview(actionsSnapshot)

        toVC.view.isHidden = true

        messageContentView.isHidden = false
        let frame = messageContentView.superview!.convert(messageContentView.frame, to: nil)
        messageContentView.removeFromSuperview()
        transitionContext.containerView.addSubview(messageContentView)
        messageContentView.frame = frame
        messageContentView.translatesAutoresizingMaskIntoConstraints = true
        
        let duration = transitionDuration(using: transitionContext)
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 4,
            animations: { [self] in
                actionsSnapshot.transform = .identity
                messageContentView.frame.origin = toVC.messageContentContainerView.superview!.convert(
                    toVC.messageContentContainerView.frame,
                    to: nil
                ).origin
//                fromVCSnapshot?.alpha = 0
            },
            completion: { [self] _ in
                toVC.view.isHidden = false
                fromVC.view.isHidden = false
                messageContentView.isHidden = false
                toVC.messageContentContainerView.addSubview(messageContentView)
                messageContentView.translatesAutoresizingMaskIntoConstraints = false
                toVC.messageContentContainerView.embed(messageContentView)
//                toVC.messageContentView.isHidden = false
//                transitionMessageContentView.removeFromSuperview()
                fromVCSnapshot?.removeFromSuperview()
                blurSnapshot.removeFromSuperview()
                
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        )
    }
    
    open func animateDismiss() {}
}
