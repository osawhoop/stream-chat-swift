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
        popup.transitioningDelegate = transitionController
        
        transitionController.messageContentViewFrame = messageContentFrame
        transitionController.messageContentView = messageContentView
        transitionController.messageContentViewSuperview = messageContentView.superview
        
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
    open var messageContentViewFrame: CGRect = .zero
    open var messageContentViewActivateConstraints: [NSLayoutConstraint] = []
    open weak var messageContentView: _ChatMessageContentView<ExtraData>!
    open weak var messageContentViewSuperview: UIView!
    public private(set) lazy var impactFeedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
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
        return self
    }
    
    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.25
//        2
    }
    
    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if isPresenting {
            animatePresent(using: transitionContext)
        } else {
            animateDismiss(using: transitionContext)
        }
    }
    
    open func animatePresent(using transitionContext: UIViewControllerContextTransitioning) {
        guard
            let toVC = transitionContext.viewController(forKey: .to) as? _ChatMessagePopupVC<ExtraData>,
            let fromVC = transitionContext.viewController(forKey: .from)
        else { return }
        messageContentView.isHidden = true
        
        transitionContext.containerView.addSubview(toVC.view)
        
        let fromVCSnapshot = fromVC.view.snapshotView(afterScreenUpdates: true)
        if let fromVCSnapshot = fromVCSnapshot {
            transitionContext.containerView.addSubview(fromVCSnapshot)
            fromVCSnapshot.frame = fromVC.view.frame
            fromVC.view.isHidden = true
        }

        let blurView = UIVisualEffectView()
        blurView.frame = toVC.view.frame
        transitionContext.containerView.addSubview(blurView)
        
        let reactionsSnapshot: UIView?
        if let reactionsController = toVC.reactionsController {
            reactionsSnapshot = reactionsController.view.snapshotView(afterScreenUpdates: true)
            reactionsSnapshot?.frame = reactionsController.view.superview!.convert(reactionsController.view.frame, to: nil)
            reactionsSnapshot?.transform = CGAffineTransform(scaleX: 0, y: 0)
            reactionsSnapshot?.alpha = 0.0
            reactionsSnapshot.map(transitionContext.containerView.addSubview)
        } else {
            reactionsSnapshot = nil
        }
        
        let actionsSnapshot = toVC.actionsController.view.snapshotView(afterScreenUpdates: true)!
        let actionsFrame = toVC.actionsController.view.superview!.convert(toVC.actionsController.view.frame, to: nil)
        actionsSnapshot.frame = actionsFrame
        actionsSnapshot.transform = CGAffineTransform(scaleX: 0, y: 0)
        actionsSnapshot.alpha = 0.0
        transitionContext.containerView.addSubview(actionsSnapshot)

        toVC.view.isHidden = true

        messageContentView.isHidden = false
        let frame = messageContentView.superview!.convert(messageContentView.frame, to: nil)
        let allMessageContentViewSuperviewConstraints = Set(messageContentViewSuperview.constraints)
        messageContentView.removeFromSuperview()
        messageContentViewActivateConstraints = Array(
            allMessageContentViewSuperviewConstraints.subtracting(messageContentViewSuperview.constraints)
        )
        transitionContext.containerView.addSubview(messageContentView)
        messageContentView.frame = frame
        messageContentView.translatesAutoresizingMaskIntoConstraints = true
        
        let duration = transitionDuration(using: transitionContext)
        UIView.animate(
            withDuration: 0.2 * duration,
            delay: 0,
            options: [.curveEaseOut],
            animations: { [self] in
                messageContentView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            },
            completion: { [self] _ in
                impactFeedbackGenerator.impactOccurred()
            }
        )
        UIView.animate(
            withDuration: 0.8 * duration,
            delay: 0.2 * duration,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 4,
            animations: { [self] in
                actionsSnapshot.transform = .identity
                actionsSnapshot.alpha = 1.0
                reactionsSnapshot?.transform = .identity
                reactionsSnapshot?.alpha = 1.0
                messageContentView.transform = .identity
                messageContentView.frame.origin = toVC.messageContentContainerView.superview!.convert(
                    toVC.messageContentContainerView.frame,
                    to: nil
                )
                .origin
                if let effect = (toVC.blurView as? UIVisualEffectView)?.effect {
                    blurView.effect = effect
                }
            },
            completion: { [self] _ in
                toVC.view.isHidden = false
                fromVC.view.isHidden = false
                messageContentView.isHidden = false
                toVC.messageContentContainerView.addSubview(messageContentView)
                messageContentView.translatesAutoresizingMaskIntoConstraints = false
                toVC.messageContentContainerView.embed(messageContentView)
                fromVCSnapshot?.removeFromSuperview()
                blurView.removeFromSuperview()
                reactionsSnapshot?.removeFromSuperview()
                actionsSnapshot.removeFromSuperview()
                
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        )
    }
    
    open func animateDismiss(using transitionContext: UIViewControllerContextTransitioning) {
        guard
            let fromVC = transitionContext.viewController(forKey: .from) as? _ChatMessagePopupVC<ExtraData>,
            let toVC = transitionContext.viewController(forKey: .to)
        else { return }
        messageContentView.isHidden = true
        
        let toVCSnapshot = toVC.view.snapshotView(afterScreenUpdates: true)
        if let toVCSnapshot = toVCSnapshot {
            transitionContext.containerView.addSubview(toVCSnapshot)
            toVCSnapshot.frame = toVC.view.frame
            toVC.view.isHidden = true
        }

        let blurView = UIVisualEffectView()
        if let effect = (fromVC.blurView as? UIVisualEffectView)?.effect {
            blurView.effect = effect
        }
        blurView.frame = fromVC.view.frame
        transitionContext.containerView.addSubview(blurView)
        
        let reactionsSnapshot: UIView?
        if let reactionsController = fromVC.reactionsController {
            reactionsSnapshot = reactionsController.view.snapshotView(afterScreenUpdates: true)
            reactionsSnapshot?.frame = reactionsController.view.superview!.convert(reactionsController.view.frame, to: nil)
            reactionsSnapshot?.transform = .identity
            reactionsSnapshot.map(transitionContext.containerView.addSubview)
        } else {
            reactionsSnapshot = nil
        }
        
        let actionsSnapshot = fromVC.actionsController.view.snapshotView(afterScreenUpdates: true)!
        actionsSnapshot.frame = fromVC.actionsController.view.superview!.convert(fromVC.actionsController.view.frame, to: nil)
        transitionContext.containerView.addSubview(actionsSnapshot)

//        fromVC.view.isHidden = true

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
            animations: { [self] in
                actionsSnapshot.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
                reactionsSnapshot?.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
                actionsSnapshot.alpha = 0.0
                reactionsSnapshot?.alpha = 0.0
                messageContentView.frame = messageContentViewFrame
                blurView.effect = nil
            },
            completion: { [self] _ in
                toVC.view.isHidden = false
                fromVC.view.isHidden = false
                messageContentView.translatesAutoresizingMaskIntoConstraints = false
                messageContentView.removeFromSuperview()
                messageContentViewSuperview.addSubview(messageContentView)
                NSLayoutConstraint.activate(messageContentViewActivateConstraints)
                toVCSnapshot?.removeFromSuperview()
                blurView.removeFromSuperview()
                reactionsSnapshot?.removeFromSuperview()
                actionsSnapshot.removeFromSuperview()
                
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        )
    }
}
