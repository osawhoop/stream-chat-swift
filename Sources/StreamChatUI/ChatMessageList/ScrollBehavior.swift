//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
import UIKit

/// An object that allows specify custom behavior of the collection with before/after committing batch updates.
public protocol ScrollBehavior {
    /// A flag that determines if the batch updates should be animated.
    var areUpdatesAnimated: Bool { get }

    /// Called before the batch updates are committed to the collection view.
    /// - Parameter collectionView: The collection view that's being updated.
    mutating func preUpdate(_ collectionView: UICollectionView)

    /// Called after the batch updates are committed to the collection view.
    /// - Parameter collectionView: The collection view that's being updated.
    mutating func postUpdate(_ collectionView: UICollectionView)
}

/// A `ScrollBehavior` implementation that tries to restore the same visual scroll position as the one pre updates.
public struct FixScrollPosition: ScrollBehavior {
    public var areUpdatesAnimated: Bool

    var visualDistanceFromBottom: CGFloat?

    public init(areUpdatesAnimated: Bool = false) {
        self.areUpdatesAnimated = areUpdatesAnimated
    }

    public mutating func preUpdate(_ collectionView: UICollectionView) {
        let contentSizeHeight = collectionView.contentSize.height
        let yContentOffset = collectionView.contentOffset.y

        visualDistanceFromBottom = contentSizeHeight - yContentOffset - collectionView.visibleHeight
    }

    public mutating func postUpdate(_ collectionView: UICollectionView) {
        guard let previousDistance = visualDistanceFromBottom else {
            log.assertionFailure("Can't restore scroll position because `preUpdate` method wasn't called.")
            return
        }

        let contentSizeHeight = collectionView.contentSize.height
        let yContentOffset = contentSizeHeight - previousDistance - collectionView.visibleHeight

        Animate {
            collectionView.setContentOffset(CGPoint(x: 0, y: yContentOffset), animated: true)
        }
    }
}

/// A `ScrollBehavior` implementation that tries to restore the same visual scroll position as the one pre updates.
public struct ScrollToLatestMessage: ScrollBehavior {
    public var areUpdatesAnimated: Bool = false

    var previousContentOffset: CGPoint?

    public mutating func preUpdate(_ collectionView: UICollectionView) {
        previousContentOffset = collectionView.contentOffset

        let bottomOffset = collectionView.contentSize.height
            - collectionView.visibleHeight
            - collectionView.contentInset.top

        UIView.performWithoutAnimation {
            collectionView.setContentOffset(CGPoint(x: 0, y: bottomOffset), animated: false)
        }
    }

    public mutating func postUpdate(_ collectionView: UICollectionView) {
        // Then scroll with animation to reveal the latest message
        Animate {
            let bottomOffset = collectionView.contentSize.height
                - collectionView.visibleHeight
                - collectionView.contentInset.top

            collectionView.setContentOffset(CGPoint(x: 0, y: bottomOffset), animated: true)
        }
    }
}

//
///// A `ScrollBehavior` implementation that tries to restore the same visual scroll position as the one pre updates.
// public struct KeepScrolledToBottomIfPossible: ScrollBehavior {
//
//    var visualDistanceFromBottom: CGFloat?
//
//    var areUpdatesAnimated: Bool = false
//
//    public init(areUpdatesAnimated: Bool = false) {
//        self.areUpdatesAnimated = areUpdatesAnimated
//    }
//
//    public mutating func preUpdate(_ collectionView: UICollectionView) {
//        let contentSizeHeight = collectionView.contentSize.height
//        let yContentOffset = collectionView.contentOffset.y
//
//        visualDistanceFromBottom = contentSizeHeight - yContentOffset - collectionView.visibleHeight
//    }
//
//    public mutating func postUpdate(_ collectionView: UICollectionView) {
//        guard let previousDistance = visualDistanceFromBottom else {
//            log.assertionFailure("Can't restore scroll position because `preUpdate` method wasn't called.")
//            return
//        }
//
//        let targetContentOffset: CGPoint
//
//        if previousDistance == 0 {
//            // scroll to the bottom
//        } else {
//            // fix the position
//            let contentSizeHeight = collectionView.contentSize.height
//            let yContentOffset = contentSizeHeight - previousDistance - collectionView.visibleHeight
//
//
//        }
//
//
//    }
// }

private extension UICollectionView {
    /// The height of a single vertical "page" of the collection view.
    var visibleHeight: CGFloat {
        frame.height - adjustedContentInset.top
    }

    /// A Boolean that returns true if the bottom cell is fully visible.
    /// Which is also means that the collection view is fully scrolled to the boom.
    var isLastCellFullyVisible: Bool {
        if numberOfItems(inSection: 0) == 0 { return true }
        let lastIndexPath = IndexPath(item: 0, section: 0)

        guard let attributes = collectionViewLayout.layoutAttributesForItem(at: lastIndexPath) else { return false }
        return bounds.contains(attributes.frame)
    }
}
