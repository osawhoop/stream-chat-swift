//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import Foundation
import StreamChat
import UIKit

/// Transitions controller for `ChatMessagePopupVC`.
open class MessageActionsTransitionController<ExtraData: ExtraDataTypes>: NSObject, UIViewControllerTransitioningDelegate,
    UIViewControllerAnimatedTransitioning {
    /// Indicates if the transition is for presenting or dismissing.
    open var isPresenting: Bool = false
    /// `messageContentView`'s initial frame.
    open var messageContentViewInitialFrame: CGRect = .zero
    /// `messageContentView`'s constraints to be activated after dismissal.
    open var messageContentViewActivateConstraints: [NSLayoutConstraint] = []
    /// Constraints to be deactivated after dismissal.
    open var messageContentViewDeactivateConstraints: [NSLayoutConstraint] = []
    /// `messageContentView` instance that is animated.
    open weak var messageContentView: _ChatMessageContentView<ExtraData>!
    /// `messageContentView`'s initial superview.
    open weak var messageContentViewSuperview: UIView!
    /// Top anchor for main container.
    open var mainContainerTopAnchor: NSLayoutConstraint?
    /// Feedback generator.
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
        4
    }
    
    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if isPresenting {
            animatePresent(using: transitionContext)
        } else {
            animateDismiss(using: transitionContext)
        }
    }
    
    /// Animates present transition.
    open func animatePresent(using transitionContext: UIViewControllerContextTransitioning) {
        guard
            let toVC = transitionContext.viewController(forKey: .to) as? _ChatMessagePopupVC<ExtraData>,
            let fromVC = transitionContext.viewController(forKey: .from)
        else { return }

        messageContentViewSuperview = messageContentView.superview
        
//        // Create snapshot of the message and set frame of starting position
//        let messageContentViewSnapshot = messageContentView.snapshotView(afterScreenUpdates: true)
//        if let messageContentViewSnapshot = messageContentViewSnapshot {
//            messageContentViewSnapshot.frame = messageContentViewSuperview.convert(messageContentView.frame, to: fromVC.view)
//        }
    
        
        
        // Remove the reactions from the original bubble, take out the message from it's place while keeping placeholder in place and store constraints to be activated when finished
        
        // Hide original message (we have snapshot)
//        messageContentView.isHidden = true
        
        // Prepare `messageContentView` and update its frame to be without reactions.
        if messageContentView.reactionsBubbleView?.isVisible == true {
            messageContentView.reactionsBubbleView?.isVisible = false
            messageContentView.bubbleToReactionsConstraint?.isActive = false
            mainContainerTopAnchor = messageContentView.mainContainer.topAnchor.pin(equalTo: messageContentView.topAnchor)
            mainContainerTopAnchor?.isActive = true
        }
        messageContentView.setNeedsLayout()
        messageContentView.layoutIfNeeded()
        
        // store initial frame of the message without reactions
        var messageContentViewFrame = messageContentViewSuperview.convert(messageContentView.frame, to: nil)
        self.messageContentViewInitialFrame = messageContentViewFrame

        // Remove message from the superview
        let allMessageContentViewSuperviewConstraints = Set(messageContentViewSuperview.constraints)
        messageContentView.removeFromSuperview()
        messageContentViewActivateConstraints = Array(
            allMessageContentViewSuperviewConstraints.subtracting(messageContentViewSuperview.constraints)
        )
        
        // Keep the size of the superview in the meantime
        messageContentViewDeactivateConstraints = [
            messageContentViewSuperview.widthAnchor.constraint(equalToConstant: messageContentViewFrame.width),
            messageContentViewSuperview.heightAnchor.constraint(equalToConstant: messageContentViewFrame.height)
        ]
        
        // Apply the constraints changes
        NSLayoutConstraint.deactivate(messageContentViewActivateConstraints)
        NSLayoutConstraint.activate(messageContentViewDeactivateConstraints)
        
    
        
        
        
        
        
        
        // Update the frame size somehow.
        messageContentViewFrame.size = messageContentView.systemLayoutSizeFitting(
            CGSize(width: messageContentViewFrame.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .streamRequire,
            verticalFittingPriority: .streamLow
        )

        // Store the frame to the popupVC
        toVC.messageViewFrame = messageContentViewFrame
        toVC.setUpLayout()
        
        transitionContext.containerView.addSubview(toVC.view)
        
        // Create snapshot of the message list and hide the actual message list
        let fromVCSnapshot = fromVC.view.snapshotView(afterScreenUpdates: true)
        if let fromVCSnapshot = fromVCSnapshot {
            fromVCSnapshot.frame = fromVC.view.frame
            fromVC.view.isHidden = true
        }

        let blurView = UIVisualEffectView()
        UIView.performWithoutAnimation {
            blurView.frame = toVC.view.frame
        }
        
        let reactionsSnapshot: UIView?
        if let reactionsController = toVC.reactionsController {
            reactionsSnapshot = reactionsController.view.snapshotView(afterScreenUpdates: true)
            reactionsSnapshot?.frame = reactionsController.view.superview!.convert(reactionsController.view.frame, to: nil)
            reactionsSnapshot?.transform = CGAffineTransform(scaleX: 0, y: 0)
            reactionsSnapshot?.alpha = 0.0
        } else {
            reactionsSnapshot = nil
        }
        
        
        let actionsSnapshot = toVC.actionsController.view.snapshotView(afterScreenUpdates: true)
        if let actionsSnapshot = actionsSnapshot {
            let actionsFrame = toVC.actionsController.view.superview!.convert(toVC.actionsController.view.frame, to: nil)
            actionsSnapshot.frame = actionsFrame
            actionsSnapshot.transform = CGAffineTransform(scaleX: 0, y: 0)
            actionsSnapshot.alpha = 0.0
        }
        
        transitionContext.containerView.addSubview(messageContentView)
        // Insert (from the bottom): snapshot of the message list, blur, reactions and actions (Jakub note: maybe reactions should go above?)
//        if let messageContentViewSnapshot = messageContentViewSnapshot {
        fromVCSnapshot.map { transitionContext.containerView.insertSubview($0, belowSubview: messageContentView) }
        transitionContext.containerView.insertSubview(blurView, belowSubview: messageContentView)
        reactionsSnapshot.map { transitionContext.containerView.insertSubview($0, aboveSubview: messageContentView) }
        actionsSnapshot.map { transitionContext.containerView.insertSubview($0, aboveSubview: messageContentView) }
//        }

        // Hide the popupVC so we can perform the custom animation
        toVC.view.isHidden = true

        // Show the message
//        messageContentView.isVisible = true
        
        transitionContext.containerView.addSubview(messageContentView)
        messageContentView.frame = messageContentViewFrame
        messageContentView.translatesAutoresizingMaskIntoConstraints = true
        
//        messageContentViewSnapshot?.removeFromSuperview()
        
        transitionContext.containerView.setNeedsLayout()
        transitionContext.containerView.layoutIfNeeded()
        
        let duration = transitionDuration(using: transitionContext)
//        UIView.animate(
//            withDuration: 0.2 * duration,
//            delay: 0,
//            options: [.curveEaseOut],
//            animations: { [self] in
//                messageContentView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
//            },
//            completion: { [self] _ in
//                impactFeedbackGenerator.impactOccurred()
//            }
//        )
        
        var messageContentViewTargetOrigin: CGPoint {
            let frame = toVC.view.convert(toVC.messageContentContainerView.frame, to: nil)
            // Add status bar height because the status bar will be added after transition and will move the view down.
            // iPhone 12 mini has a bug in statusBarHeight. navBar.origin.y will be used instead (https://developer.apple.com/forums/thread/662466)
            let statusBarHeight = (fromVC as? UINavigationController)?.navigationBar.frame.origin.y ?? 0
            let myTry = CGPoint(x: frame.origin.x, y: frame.origin.y + statusBarHeight)
            
            let previous = toVC.messageContentContainerView.superview!.convert(
                    toVC.messageContentContainerView.frame,
                    to: nil
                )
                .origin
            return previous
        }
        
        UIView.animate(
            withDuration: 0.8 * duration,
            delay: 0.2 * duration,
//            usingSpringWithDamping: 1,
//            initialSpringVelocity: 4,
            options: [.curveEaseInOut],
            animations: { [self] in
                actionsSnapshot?.transform = .identity
                actionsSnapshot?.alpha = 1.0
                reactionsSnapshot?.transform = .identity
                reactionsSnapshot?.alpha = 1.0
                let view = transitionContext.containerView
                messageContentView.transform = .identity
                messageContentView.frame.origin = messageContentViewTargetOrigin
                if let effect = (toVC.blurView as? UIVisualEffectView)?.effect {
                    blurView.effect = effect
                }
            },
            completion: { [self] _ in
                UIView.performWithoutAnimation {
                    toVC.view.isHidden = false
                    fromVC.view.isHidden = false
                    messageContentView.isHidden = false
                    toVC.messageContentContainerView.addSubview(messageContentView)
                    messageContentView.translatesAutoresizingMaskIntoConstraints = false
                    toVC.messageContentContainerView.embed(messageContentView)
                    fromVCSnapshot?.removeFromSuperview()
                    blurView.removeFromSuperview()
                    reactionsSnapshot?.removeFromSuperview()
                    actionsSnapshot?.removeFromSuperview()
                    
                    transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                }
            }
        )
    }
    
    /// Animates dismissal transition.
    open func animateDismiss(using transitionContext: UIViewControllerContextTransitioning) {
        guard
            let fromVC = transitionContext.viewController(forKey: .from) as? _ChatMessagePopupVC<ExtraData>,
            let toVC = transitionContext.viewController(forKey: .to)
        else { return }
        
        let messageContentViewSnapshot = messageContentView.snapshotView(afterScreenUpdates: true)
        if let messageContentViewSnapshot = messageContentViewSnapshot {
            messageContentViewSnapshot.frame = messageContentView.convert(messageContentView.frame, to: fromVC.view)
            transitionContext.containerView.addSubview(messageContentViewSnapshot)
        }
        
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
        
        let reactionsSnapshot: UIView?
        if let reactionsController = fromVC.reactionsController {
            reactionsSnapshot = reactionsController.view.snapshotView(afterScreenUpdates: true)
            reactionsSnapshot?.frame = reactionsController.view.superview!.convert(reactionsController.view.frame, to: nil)
            reactionsSnapshot?.transform = .identity
            reactionsSnapshot.map(transitionContext.containerView.addSubview)
        } else {
            reactionsSnapshot = nil
        }
        
        let actionsSnapshot = fromVC.actionsController.view.snapshotView(afterScreenUpdates: true)
        if let actionsSnapshot = actionsSnapshot {
            actionsSnapshot.frame = fromVC.actionsController.view.superview!.convert(fromVC.actionsController.view.frame, to: nil)
            transitionContext.containerView.addSubview(actionsSnapshot)
        }
        
        if let messageContentViewSnapshot = messageContentViewSnapshot {
            toVCSnapshot.map { transitionContext.containerView.insertSubview($0, belowSubview: messageContentViewSnapshot) }
            transitionContext.containerView.insertSubview(blurView, belowSubview: messageContentViewSnapshot)
            reactionsSnapshot.map { transitionContext.containerView.insertSubview($0, belowSubview: messageContentViewSnapshot) }
            actionsSnapshot.map { transitionContext.containerView.insertSubview($0, belowSubview: messageContentViewSnapshot) }
        }

        messageContentView.isHidden = false
        let frame = messageContentView.convert(messageContentView.frame, to: fromVC.view)
        messageContentView.removeFromSuperview()
        transitionContext.containerView.addSubview(messageContentView)
        messageContentView.translatesAutoresizingMaskIntoConstraints = true
        UIView.performWithoutAnimation {
            messageContentView.frame = frame
        }
        
        messageContentViewSnapshot?.removeFromSuperview()
        
        fromVC.view.isHidden = true
        
        let duration = transitionDuration(using: transitionContext)
        UIView.animate(
            withDuration: duration,
            delay: 0,
            animations: { [self] in
                actionsSnapshot?.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
                reactionsSnapshot?.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
                actionsSnapshot?.alpha = 0.0
                reactionsSnapshot?.alpha = 0.0
                messageContentView.frame = messageContentViewInitialFrame
                blurView.effect = nil
            },
            completion: { [self] _ in
                UIView.performWithoutAnimation {
                    toVC.view.isHidden = false
                    fromVC.view.isHidden = false
                    messageContentView.translatesAutoresizingMaskIntoConstraints = false
                    if let mainContainerTopAnchor = mainContainerTopAnchor {
                        mainContainerTopAnchor.isActive = false
                        messageContentView.reactionsBubbleView?.isVisible = true
                        messageContentView.bubbleToReactionsConstraint?.isActive = true
                    }
                    messageContentView.removeFromSuperview()
                    messageContentViewSuperview.addSubview(messageContentView)
                    NSLayoutConstraint.activate(messageContentViewActivateConstraints)
                    NSLayoutConstraint.deactivate(messageContentViewDeactivateConstraints)
                    toVCSnapshot?.removeFromSuperview()
                    blurView.removeFromSuperview()
                    reactionsSnapshot?.removeFromSuperview()
                    actionsSnapshot?.removeFromSuperview()
                    
                    transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                }
            }
        )
    }
}
