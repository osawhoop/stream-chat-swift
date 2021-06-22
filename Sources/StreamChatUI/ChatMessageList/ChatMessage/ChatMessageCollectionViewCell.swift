//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
import UIKit

/// The cell that displays the message content of a dynamic type and layout.
/// Once the cell is set up it is expected to be dequeued for messages with
/// the same content and layout the cell has already been configured with.
public typealias ChatMessageCollectionViewCell = _ChatMessageCollectionViewCell<NoExtraData>

/// The cell that displays the message content of a dynamic type and layout.
/// Once the cell is set up it is expected to be dequeued for messages with
/// the same content and layout the cell has already been configured with.
public final class _ChatMessageCollectionViewCell<ExtraData: ExtraDataTypes>: _CollectionViewCell {
    public static var reuseId: String { "\(self)" }

    public private(set) var messageContentView: _ChatMessageContentView<ExtraData>?
    
    let label = UILabel().withoutAutoresizingMaskConstraints

    override public func prepareForReuse() {
        super.prepareForReuse()

        messageContentView?.prepareForReuse()
    }

    var topConstraint: NSLayoutConstraint?

    public func setMessageContentIfNeeded(
        contentViewClass: _ChatMessageContentView<ExtraData>.Type,
        attachmentViewInjectorType: _AttachmentViewInjector<ExtraData>.Type?,
        options: ChatMessageLayoutOptions
    ) {
        guard messageContentView == nil else {
            log.assert(type(of: messageContentView!) == contentViewClass, """
            Attempt to setup different content class: ("\(contentViewClass)").
            `СhatMessageCollectionViewCell` is supposed to be configured only once.
            """)
            return
        }

        messageContentView = contentViewClass.init().withoutAutoresizingMaskConstraints
        // We add the content view to the view hierarchy before invoking `setUpLayoutIfNeeded`
        // (where the subviews are instantiated and configured) to use `components` and `appearance`
        // taken from the responder chain.
        contentView.addSubview(messageContentView!)

        messageContentView?.pin(anchors: [.leading, .bottom, .trailing], to: contentView)

        topConstraint = messageContentView?.topAnchor.pin(equalTo: contentView.topAnchor)
        topConstraint?.isActive = true

        messageContentView!.setUpLayoutIfNeeded(options: options, attachmentViewInjectorType: attachmentViewInjectorType)
        
        contentView.addSubview(label)
        contentView.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
        label.pin(anchors: [.top, .leading], to: contentView)
    }

    override public func preferredLayoutAttributesFitting(
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

        preferredAttributes.frame.size = .init(
            width: preferredAttributes.frame.width,
            height: ceil(preferredAttributes.frame.height)
        )
        
        // We need to communicate the current layout options back the the layout such that
        // they can be used later for animation purposes.
        if let attributes = preferredAttributes as? MessageCellLayoutAttributes {
            attributes.previousLayoutOptions = messageContentView?.layoutOptions

            print("    -> preferredLayoutAttributesFitting \(layoutAttributes.indexPath) | \(attributes.label)")
            
            label.text = "y: \(attributes.frame.origin.y)"

//            isHidden = attributes.isChangeAnimated
        }

        return preferredAttributes
    }

    override public func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)

        guard let attributes = layoutAttributes as? MessageCellLayoutAttributes else {
            return
        }
        
//        if attributes.isInitialAttributes {
//            contentView.backgroundColor = UIColor.green.withAlphaComponent(0.3)
//
//        } else if attributes.isFinalAttributes {
//            contentView.backgroundColor = UIColor.red.withAlphaComponent(0.3)
//
//        } else {
//            contentView.backgroundColor = .clear
//        }
        
        messageContentView?.isHidden = attributes.isFinalAttributes

        if attributes.previousLayoutOptions?.contains(.reactions) == false,
           messageContentView?.layoutOptions.contains(.reactions) == true
        {
            if attributes.isInitialAttributes {
                topConstraint?.isActive = false

                messageContentView?.reactionsBubbleView?.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
                    .concatenating(.init(translationX: 10, y: frame.height / 2.0))
                    .concatenating(.init(rotationAngle: -3.14 / 4.0))
                
                messageContentView?.reactionsView?.transform = CGAffineTransform(scaleX: 4, y: 4)
//                    .concatenating(.init(translationX: 20, y: frame.height / 1.5))
//                    .concatenating(.init(rotationAngle: -5 / 4.0))

                messageContentView?.reactionsBubbleView?.alpha = 0
                messageContentView?.reactionsView?.alpha = 0
                
                UIView.performWithoutAnimation {
                    contentView.setNeedsLayout()
                    contentView.layoutIfNeeded()
                }
            }
            
        } else {
            CATransaction.begin()
            CATransaction.setAnimationDuration(2)
        
            topConstraint?.isActive = true

            messageContentView?.reactionsBubbleView?.transform = .identity
            messageContentView?.reactionsBubbleView?.alpha = 1
                
            messageContentView?.reactionsView?.transform = .identity
            messageContentView?.reactionsView?.alpha = 1
                
            messageContentView?.reactionsBubbleView?.setNeedsLayout()
            messageContentView?.setNeedsLayout()

            contentView.setNeedsLayout()
            contentView.layoutIfNeeded()
            CATransaction.commit()
        }
        
//        if attributes.isChangeAnimated {
//            isHidden = false
//        } else {
//       //         These attributes can be invalid. We rather hide the view to prevent any
//       //         visual glitches and unwanted animations
//           isHidden = true
//
//           UIView.performWithoutAnimation {
//               contentView.setNeedsLayout()
//               contentView.layoutIfNeeded()
//
//               messageContentView?.setNeedsLayout()
//               messageContentView?.layoutIfNeeded()
//           }
//
//           layer.removeAllAnimations()
//
//            attributes.isChangeAnimated = true
//       }
                
        //            window?.layer.speed = 0.1
//
        ////            let reactionBubbleHeight = messageContentView?.reactionsBubbleView?.heightAnchor.constraint(equalToConstant: 0)
        ////            let reactionBubbleWidth = messageContentView?.reactionsBubbleView?.widthAnchor.constraint(equalToConstant: 0)
        ////            let reactionHeight = messageContentView?.reactionsView?.heightAnchor.constraint(equalToConstant: 0)
//
//            if attributes.isInitialAttributes {
//                UIView.performWithoutAnimation {
//                    //                reactionBubbleHeight?.isActive = true
//                    //                reactionHeight?.isActive = true
//                    //                reactionBubbleWidth?.isActive = true
//
//                    topConstraint?.isActive = false
//
//                    messageContentView?.isHidden = true
//                    messageContentView?.reactionsBubbleView?.transform = CGAffineTransform(scaleX: 0.05, y: 0.05)
//                        .concatenating(.init(translationX: 10, y: frame.height / 2.0))
//                        .concatenating(.init(rotationAngle: -3.14 / 4.0))
//
//                    messageContentView?.reactionsBubbleView?.alpha = 0
//
//                    messageContentView?.setNeedsLayout()
//
//                    self.setNeedsLayout()
//                    self.layoutIfNeeded()
//                }
//            } else {
//                messageContentView?.reactionsBubbleView?.transform = .identity
//                messageContentView?.reactionsBubbleView?.alpha = 1
//
//                messageContentView?.alpha = 1
//
//                topConstraint?.isActive = true
//
//                messageContentView?.reactionsBubbleView?.layoutIfNeeded()
//
//                messageContentView?.setNeedsLayout()
//                messageContentView?.layoutIfNeeded()
//
//                messageContentView?.setNeedsLayout()
//
//                setNeedsLayout()
//                layoutIfNeeded()
//
        ////                UIView.animate(
        ////                    withDuration: 1,
        ////                    delay: 0,
        ////                    usingSpringWithDamping: 0.5,
        ////                    initialSpringVelocity: 10,
        ////                    options: [],
        ////                    animations: {
        ////                        self.messageContentView?.reactionsBubbleView?.transform = .identity
        ////                        self.messageContentView?.reactionsBubbleView?.alpha = 1
        ////
        ////                        self.messageContentView?.alpha = 1
        ////
        ////                        self.topConstraint?.isActive = true
        ////
        ////                        self.messageContentView?.reactionsBubbleView?.layoutIfNeeded()
        ////
        ////                        self.messageContentView?.setNeedsLayout()
        ////                        self.messageContentView?.layoutIfNeeded()
        ////
        ////                        messageContentView?.setNeedsLayout()
        ////
        ////                        self.setNeedsLayout()
        ////                        self.layoutIfNeeded()
        ////
        ////                    },
        ////                    completion: nil
        ////                )
//            }
//
//            //            reactionBubbleHeight?.isActive = false
//            //            reactionHeight?.isActive = false
//            //            reactionBubbleWidth?.isActive = false
//
//            //            }
//
//            //            self.messageContentView?.layoutIfNeeded()
//        }
//
        ////        UIView.performWithoutAnimation {
        ////
        ////            messageContentView?.setNeedsLayout()
        ////            messageContentView?.layoutIfNeeded()
        ////
        ////            contentView.setNeedsLayout()
        ////            contentView.layoutIfNeeded()
        ////
        ////            setNeedsLayout()
        ////            layoutIfNeeded()
//        ////
//        ////
//        ////            messageContentView?.layoutIfNeeded()
        ////        }
        ////
        ////        if attributes.isCachedAttribute {
        ////            UIView.performWithoutAnimation {
        ////                layer.removeAllAnimations()
        ////
        ////                messageContentView?.setNeedsLayout()
        ////                messageContentView?.layoutIfNeeded()
        ////            }
        ////        }
        ////
//        ////        isHidden = !attributes.isChangeAnimated
        ////
        ////        if attributes.isHidden {
        ////            print()
        ////        }
        ////
        ////        if !attributes.isChangeAnimated {
        ////            isHidden = false
        ////        }
        ////
        ////        if attributes.isInitialAttributes {
        ////            UIView.performWithoutAnimation {
        ////                if let presentationLayer = layer.presentation() {
        ////                    self.frame = presentationLayer.frame
        ////
        ////                    layer.removeAllAnimations()
//        ////                    presentationLayer.isHidden = true
        ////                    presentationLayer.setAffineTransform(CGAffineTransform(rotationAngle: 0.15))
        ////
//        ////                    presentationLayer.isHidden = true
        ////
        ////
        ////
        ////                    setNeedsLayout()
        ////                    layoutIfNeeded()
        ////                }
        ////
        ////            }
        ////        }
        ////
        ////        if attributes.isChangeAnimated {
        ////            self.isHidden = true
        ////            return
        ////        }
//
        ////
        ////
        ////        isHidden = attributes.isChangeAnimated
        ////
        ////        if !attributes.isInitialAttributes  {
        ////            isHidden = false
        ////        }
//
        ////        print(
        ////            "👉 \(String(format: "%p", self)) applying attributes: \(attributes.indexPath) | \(attributes.frame.origin) -> \(attributes.label)"
        ////        )
        ////
//
        ////        layer.removeAllAnimations()
        ////
        ////        UIView.performWithoutAnimation {
        ////
        ////
        ////            messageContentView?.setNeedsLayout()
        ////            messageContentView?.layoutIfNeeded()
        ////        }
//
//        ///
//
        ////        if attributes.isChangeAnimated {
        ////            isHidden = false
        ////
        ////        } else {
//        ////         These attributes can be invalid. We rather hide the view to prevent any
//        ////         visual glitches and unwanted animations
        ////            isHidden = true
        ////
        ////            UIView.performWithoutAnimation {
        ////                contentView.setNeedsLayout()
        ////                contentView.layoutIfNeeded()
        ////
        ////                messageContentView?.setNeedsLayout()
        ////                messageContentView?.layoutIfNeeded()
        ////            }
        ////
        ////            layer.removeAllAnimations()
        ////        }
    }
}
