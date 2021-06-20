//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import UIKit

public class MessageLayoutInvalidationContext: UICollectionViewLayoutInvalidationContext {
    public var invalidateVisibleSizeRelatedMetrics: Bool = false

    /// When `true` the layout should recalculate all offsets of the existing items. This usually happens
    /// when the content is smaller than the visible area.
    public var invalidateItemsOffsets: Bool = false

    public var scrollPositionToRestore: ScrollPositionSnapshot?

    public var forceContentSizeChanges: Bool = false
}

public enum ScrollPositionSnapshot {
    case topEdge(offset: CGPoint, topVisibleItem: IndexPath?)
    case distanceFromBottomEdge(offset: CGFloat)
    case bottomEdge

    mutating func adjustPosition(changedItemIndexPath: IndexPath, delta: CGFloat) {
        if case let .topEdge(offset, topVisibleItem) = self, topVisibleItem != nil {
            if changedItemIndexPath > topVisibleItem! {
                self = .topEdge(offset: CGPoint(x: 0, y: offset.y + delta), topVisibleItem: topVisibleItem)
                print("Adjusting position snapshot: \(delta) | total: \(offset.y + delta)")
            }
        } else {
            // Nothing to do here
        }
    }
}

public extension UICollectionView {
    func snapshotScrollPosition(isBottomEdgeFixed: Bool = false) -> ScrollPositionSnapshot {
        let isScrolledToBottom = contentSize.height
            - contentOffset.y
            - bounds.height
            + contentInset.top
            + contentInset.bottom
            <= contentInset.top

        if isScrolledToBottom {
            return .bottomEdge

        } else if isBottomEdgeFixed {
            let distance = contentSize.height
                - contentOffset.y
                - bounds.height
                + contentInset.top
            return .distanceFromBottomEdge(offset: distance)

        } else {
            let topVisibleItem = indexPathsForVisibleItems.max()
            return .topEdge(offset: contentOffset, topVisibleItem: topVisibleItem)
        }
    }
    
    func resolveTargetContentOffset(_ snapshot: ScrollPositionSnapshot, futureContentSize: CGSize? = nil) -> CGPoint {
        switch snapshot {
        case let .topEdge(offset, _):
            return offset

        case .bottomEdge:
            return CGPoint(
                x: 0,
                y: (futureContentSize?.height ?? contentSize.height)
                    - bounds.height
                    + contentInset.top
//                    + contentInset.bottom
            )

        case let .distanceFromBottomEdge(offset: offset):
            let resolved = (futureContentSize?.height ?? contentSize.height)
                - offset
                - bounds.height
                + contentInset.top
            return CGPoint(x: 0, y: resolved)
        }
    }
}

/// Custom Table View like layout that position item at index path 0-0 on bottom of the list.
///
/// Unlike `UICollectionViewFlowLayout` we ignore some invalidation calls and persist items attributes between updates.
/// This resolves problem when on item reload layout would change content offset and user ends up on completely different item.
/// Layout intended for batch updates and right now I have no idea how it will react to `collectionView.reloadData()`.
open class ChatMessageListCollectionViewLayout: UICollectionViewLayout {
    /// Layout items before currently running batch update
    open var previousItems: ContiguousArray<LayoutItem> = []

    /// Actual layout
    open var currentItems: ContiguousArray<LayoutItem> = [] {
        didSet {
//            print("\n======= current items ====== ")
//            currentItems.prefix(10).forEach {
//                print("    -> \($0.offset) | \($0.height)")
//            }
        }
    }

    /// Future layout to be used when the invalidation process finishes
    open var futureItems: ContiguousArray<LayoutItem>? = []
//    {
//        didSet {
//            for (left, right) in zip(currentItems, currentItems.dropFirst()) {
//                if right.offset + right.height + spacing != left.offset {
//                    print()
//                }
//
//            }
//        }
//    }
    
    //    {
    //        didSet {
    //            print("\n======= futureItems items ====== ")
    //            currentItems.forEach {
    //                print("    -> \($0.offset) | \($0.height)")
    //            }
    //        }
    //    }

    open var cachedCurrentItems: [LayoutItem] = []

    open var reloadingItems: Set<IndexPath> = []
    
    /// You can improve scroll performance by tweaking this number. In general, it's better to keep this number a little
    /// bit higher than the average cell height.
    open var estimatedItemHeight: CGFloat = 400

    /// Vertical spacing between items
    open var spacing: CGFloat = 2

    /// Items that have been added to collectionview during currently running batch updates
    open var appearingItems: Set<IndexPath> = []
    /// Items that have been removed from collectionview during currently running batch updates
    open var disappearingItems: Set<IndexPath> = []

    /// We need to cache attributes used for initial/final state of added/removed items to update them after AutoLayout pass.
    /// This will prevent items to appear with `estimatedItemHeight` and animating to real size
//    open var animatingAttributes: [IndexPath: UICollectionViewLayoutAttributes] = [:]

    // =========================

    override open class var invalidationContextClass: AnyClass {
        MessageLayoutInvalidationContext.self
    }

    public var previousContentInsets: UIEdgeInsets = .zero {
        didSet {
            print("previous content inset set: \(previousContentInsets)")
        }
    }

    public var previousContentSize: CGSize = .zero {
        didSet {
            print("previous content size set: \(previousContentSize)")
        }
    }

    /// This is the minimal content size heigh reported to the collection view. We use this constant to easily keep the messages
    /// pinned to the bottom of the screen. This value always be higher than the max visible height of the device. Don't make this
    /// value unnecessarily big because the higher the value the biggest performance penalty.
    open var minimalContentHeight: CGFloat = 1000
    
    override open var collectionViewContentSize: CGSize {
        // This is a workaround for `layoutAttributesForElementsInRect:` not getting invoked enough
        // times if `collectionViewContentSize.width` is not smaller than the width of the collection
        // view, minus horizontal insets. This results in visual defects when performing batch
        // updates. To work around this, we subtract 0.0001 from our content size width calculation;
        // this small decrease in `collectionViewContentSize.width` is enough to work around the
        // incorrect, internal collection view `CGRect` checks, without introducing any visual
        // differences for elements in the collection view.
        // See https://openradar.appspot.com/radar?id=5025850143539200 for more details.
        //
        // Credit to https://github.com/airbnb/MagazineLayout/blob/6f88742c282de208e48cb738a7a14b7dc2651701/MagazineLayout/Public/MagazineLayout.swift#L69

        let result = CGSize(
            width: collectionView!.bounds.width - 0.0001,
            height: max(minimalContentHeight, currentItems.first?.maxY ?? 0)
        )

        return result
    }

    /// Used to prevent layout issues during batch updates.
    ///
    /// Before batch updates collection view says to invalidate layout with `invalidateDataSourceCounts`.
    /// Next it ask us for attributes for new items before says which items are new. So we have no way to properly calculate it.
    /// `UICollectionViewFlowLayout` uses private API to get this info. We are don not have such privilege.
    /// If we return wrong attributes user will see artifacts and broken layout during batch update animation.
    /// By not returning any attributes during batch updates we are able to prevent such artifacts.
    open var preBatchUpdatesCall = false

    open var wasScrolledToBottom = false

    /// As we very often need to preserve scroll offset after performBatchUpdates, the simplest solution is to save original
    /// contentOffset and set it when batch updates end
    private var preUpdateScrollPositionSnapshot: ScrollPositionSnapshot? {
        didSet {
            print("pre update scroll position: \(preUpdateScrollPositionSnapshot)")
        }
    }

    private var topEmptyInset: CGFloat = 0 {
        didSet {
            print("*** topEmptyInset: \(topEmptyInset)")
        }
    }

    /// Flag to make sure the `prepare()` function is only executed when the collection view had been loaded.
    /// The rest of the updates should come from `prepare(forCollectionViewUpdates:)`.
    private var didPerformInitialLayout = false
    
    private var didPerformInitialScrollToBottom = false

    // MARK: - Cache

    // MARK: - Initialization

    override public required init() {
        super.init()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Prepare

    override open func prepare() {
        super.prepare()

        print("\n👉 \(#function)")
        defer { print("\(#function) 👈") }

        guard let collectionView = self.collectionView else {
            print(" * collectionView is `nil`")
            return
        }
        
        previousContentInsets = collectionView.contentInset

        if let futureItems = self.futureItems {
            currentItems = futureItems
            self.futureItems = nil
        }
        
        if let preUpdateScrollPosition = preUpdateScrollPositionSnapshot {
            let target = collectionView.resolveTargetContentOffset(preUpdateScrollPosition)
            print(" * setting the restore content offset to \(target)")
//            collectionView.setContentOffset(target, animated: false)
        }

        // Skipped the rest if we have cached data already
        guard currentItems.isEmpty else { return }

        let itemsCount = collectionView.numberOfItems(inSection: 0)
        guard itemsCount > 0 else {
            print(" * items count is 0, nothing to do here")
            return
        }

        // Save the current scroll position to move the content offset later
//        preUpdateScrollPositionSnapshot = .bottomEdge
        
        // Create initial items
        for _ in 0..<itemsCount {
            // The offset doesn't matter at this case since it will be calculated properly in the next step
            currentItems.append(LayoutItem(offset: 0, height: estimatedItemHeight))
        }

        recalculateItemOffsets(items: &currentItems, visibleHeight: minimalContentHeight)

//        // Set the initial content offset to the last page
//        let lastPageYOffset = collectionView.contentSize.height - visibleBounds.height
//        let initialContentOffset = CGPoint(x: 0, y: lastPageYOffset)
//        print(" * setting the initial content offset to \(initialContentOffset)")
//        collectionView.setContentOffset(initialContentOffset, animated: false)
        
        didPerformInitialLayout = true
    }

    var restoreBottomEdgeDistance: CGFloat = 0

    override open func prepare(forAnimatedBoundsChange oldBounds: CGRect) {
        super.prepare(forAnimatedBoundsChange: oldBounds)

        print("\n👉 \(#function): Old bounds \(oldBounds) | New bounds: \(collectionView!.bounds)")
        defer { print("\(#function) 👈") }

        isAnimatedBoundsChangeInProgress = true
        previousItems = currentItems
    }

    /// Only public by design, if you need to override this method override `_prepare(forCollectionViewUpdates:)`
    override public func prepare(forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]) {
        print("prepare forCollectionViewUpdates")

        // In Xcode 12.5 it is impossible to use own `updateItems` - our solution with `UICollectionViewUpdateItem` subclass stopped working
        // (Apple is probably checking some private API and our customized getters are not called),
        // so instead of testing `prepare(forCollectionViewUpdates:)` we will test our custom function
        _prepare(forCollectionViewUpdates: updateItems)
        super.prepare(forCollectionViewUpdates: updateItems)
    }
    
    var areUpdatesAnimated: Bool = false

    open func _prepare(forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]) {
        print("\n👉 \(#function)")
        defer { print("\(#function) 👈") }

        preBatchUpdatesCall = true
        defer { preBatchUpdatesCall = false }

        areUpdatesAnimated = UIView.areAnimationsEnabled

        preUpdateScrollPositionSnapshot = collectionView!.snapshotScrollPosition()
        previousItems = currentItems
        
        for update in updateItems {
            switch update.updateAction {
            case .delete:
                let indexPath = update.indexPathBeforeUpdate!
                let removedItem = currentItems.remove(at: indexPath.item)
                preUpdateScrollPositionSnapshot?.adjustPosition(
                    changedItemIndexPath: indexPath,
                    delta: -(removedItem.height + spacing)
                )

            case .insert:
                let height = estimatedItemHeight
                let indexPath = update.indexPathAfterUpdate!
                currentItems.insert(LayoutItem(offset: 0, height: estimatedItemHeight), at: indexPath.item)
                preUpdateScrollPositionSnapshot?.adjustPosition(changedItemIndexPath: indexPath, delta: height + spacing)
            
            case .move:
                fatalError("Moves are not supported in the layout")
                
            case .reload:
                let indexPath = update.indexPathBeforeUpdate!
//                let originalHeight = currentItems[indexPath.item].height
//                currentItems[indexPath.item].height = estimatedItemHeight
//                preUpdateScrollPositionSnapshot?.adjustPosition(
//                    changedItemIndexPath: indexPath,
//                    delta: originalHeight - estimatedItemHeight
//                )
                reloadingItems.insert(indexPath)

            case .none: break
            @unknown default: break
            }
        }
        
        // Always recalculate offsets after items change.
        recalculateItemOffsets(items: &currentItems, visibleHeight: minimalContentHeight)
    }

    // MARK: - Finalize

    override open func finalizeCollectionViewUpdates() {
        print("\n👉 \(#function)")
        defer { print("\(#function) 👈") }

        currentInvalidationContent = nil
        preBatchUpdatesCall = false

        if let targetSnapshot = preUpdateScrollPositionSnapshot {
            preUpdateScrollPositionSnapshot = nil

            let target = collectionView!.resolveTargetContentOffset(targetSnapshot)

            let contentSizeDiff = collectionViewContentSize.height - collectionView!.contentSize.height
            let targetOffsetDiff = target.y - collectionView!.contentOffset.y

            let context = MessageLayoutInvalidationContext()
            context.contentSizeAdjustment = CGSize(width: 0, height: contentSizeDiff)
            context.contentOffsetAdjustment = CGPoint(x: 0, y: targetOffsetDiff)
            context.forceContentSizeChanges = true

            invalidateLayout(with: context)
        }
    }

    override open func finalizeAnimatedBoundsChange() {
        super.finalizeAnimatedBoundsChange()

        print("\n👉 \(#function)")
        defer { print("\(#function) 👈") }

        if let offsetSnapshot = currentInvalidationContent?.scrollPositionToRestore {
            let target = collectionView!.resolveTargetContentOffset(offsetSnapshot)
            collectionView?.setContentOffset(target, animated: false)
        }
        
        currentInvalidationContent = nil
        isAnimatedBoundsChangeInProgress = false

        preBatchUpdatesCall = false

        preBoundsChangeContentSize = nil

        super.finalizeCollectionViewUpdates()
    }

    // MARK: - Content offset

    override open func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        print("\n👉 \(#function)")

        if let targetSnapshot = preUpdateScrollPositionSnapshot {
            let target = collectionView!.resolveTargetContentOffset(targetSnapshot)
            return target
        } else {
            return proposedContentOffset
        }
    }

    // MARK: - Layout invalidation

    var currentInvalidationContent: MessageLayoutInvalidationContext?
    var preBoundsChangeContentSize: CGSize?

    override open func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
        print("\n👉 \(#function)")
        defer { print("\(#function) 👈") }

        guard didPerformInitialLayout else {
            super.invalidateLayout(with: context)
            return
        }
        
        let context = context as! MessageLayoutInvalidationContext

        preBatchUpdatesCall = (context.invalidateDataSourceCounts && !context.invalidateEverything)
        currentInvalidationContent = context

        if !context.forceContentSizeChanges && collectionViewContentSize.height == minimalContentHeight {
            print(" * resetting adjustments because contentSize < minimalContentHeight")
            context.contentSizeAdjustment = .zero
            context.contentOffsetAdjustment = .zero
            
        } else {
            print()
        }
        
        print(" * content size adjustment: \(context.contentSizeAdjustment.height)")
        print(" * content offset adjustment: \(context.contentOffsetAdjustment.y)")
                
//        if case let .topEdge(offset: contentOffset) = preUpdateScrollPositionSnapshot {
//            var offset = contentOffset
//            offset.y += context.contentOffsetAdjustment.y
//            preUpdateScrollPositionSnapshot = .topEdge(offset: offset)
//        }
        
//        currentItems = futureItems ?? currentItems
//        futureItems = nil
        
        super.invalidateLayout(with: context)
    }

    // MARK: - Contexts

    override open func invalidationContext(
        forPreferredLayoutAttributes preferredAttributes: UICollectionViewLayoutAttributes,
        withOriginalAttributes originalAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutInvalidationContext {
        print("\n👉 \(#function): \(preferredAttributes.indexPath)")
        defer { print("\(#function) 👈") }
        
        let invalidationContext = super.invalidationContext(
            forPreferredLayoutAttributes: preferredAttributes,
            withOriginalAttributes: originalAttributes
        ) as! MessageLayoutInvalidationContext

        guard didPerformInitialLayout else {
            return invalidationContext
        }
        
        // Start preparing the future layout
        futureItems = futureItems ?? currentItems

        let idx = preferredAttributes.indexPath.item

        // Update the item's height
        var item = futureItems![idx]
        let delta = preferredAttributes.frame.height - currentItems[idx].height
        item.height = preferredAttributes.frame.height
        
        if let cellAttributes = preferredAttributes as? MessageCellLayoutAttributes {
            item.layoutOptions = cellAttributes.layoutOptions
            item.previousLayoutOptions = cellAttributes.previousLayoutOptions
            item.label = cellAttributes.label
            item.isInitial = false
        }

        item.label += "_adjusted"
        futureItems![idx] = item

        let isCurrentContentBiggerThenMin = isContentBiggerThan(items: currentItems, height: minimalContentHeight)
        let isFutureContentBiggerThenMin = isContentBiggerThan(items: futureItems!, height: minimalContentHeight)
 
        switch (isCurrentContentBiggerThenMin, isFutureContentBiggerThenMin) {
        case (true, true):
            // Update the offset of the cells below the updated one
            for i in 0..<idx {
                futureItems![i].offset += delta
            }

            // The content size changes every time
            invalidationContext.contentSizeAdjustment = CGSize(width: 0, height: delta)

            let isItemAboveTopEdge = item.offset < collectionView!.contentOffset.y

            if isItemAboveTopEdge || isScrolledToBottom {
                invalidationContext.contentOffsetAdjustment = CGPoint(x: 0, y: delta)
            }
            
            invalidationContext.forceContentSizeChanges = true
            
        case (false, false):
            // If the content changes such that it affects the initial page, always recreate the whole layout
            recalculateItemOffsets(items: &futureItems!, visibleHeight: minimalContentHeight)
            
        default:
            recalculateItemOffsets(items: &futureItems!, visibleHeight: minimalContentHeight)

            if isCurrentContentBiggerThenMin && !isFutureContentBiggerThenMin {
                let diff = collectionViewContentSize.height - minimalContentHeight
                invalidationContext.contentSizeAdjustment = CGSize(
                    width: 0,
                    height: diff
                )

                invalidationContext.contentOffsetAdjustment = CGPoint(x: 0, y: delta)

            } else {
                let diff = minimalContentHeight - collectionViewContentSize.height
                invalidationContext.contentSizeAdjustment = CGSize(
                    width: 0,
                    height: diff
                )

                invalidationContext.contentOffsetAdjustment = CGPoint(x: 0, y: diff)
            }

            invalidationContext.forceContentSizeChanges = true
        }

        preUpdateScrollPositionSnapshot?.adjustPosition(
            changedItemIndexPath: preferredAttributes.indexPath,
            delta: delta
        )

//
//        // If we crossed the minContent boundary we have to adjust the content size
//        if isCurrentContentBiggerThenMin != isFutureContentBiggerThenMin {
//            let currentTopOverflow = currentItems.last?.offset ?? 0
//            let futureTopOverflow = futureItems!.last?.offset ?? 0
//
//            let contentSizeDelta = currentTopOverflow - futureTopOverflow
//            invalidationContext.contentSizeAdjustment = CGSize(width: 0, height: contentSizeDelta)
//
//        } else if isCurrentContentBiggerThenMin && isFutureContentBiggerThenMin {
//            invalidationContext.contentSizeAdjustment = CGSize(width: 0, height: delta)
//        }
//
//        if !isScrolledToBottom {
//            print()
//
        ////            collectionViewContentSize.height
        ////                - cv.contentOffset.y
        ////                - collectionViewVisibleSize.height
        ////                <= cv.contentInset.top
//        }
//
//        if isScrolledToBottom && isCurrentContentBiggerThenMin && isFutureContentBiggerThenMin {
        ////            invalidationContext.contentSizeAdjustment = CGSize(width: 0, height: delta)
        ////            invalidationContext.contentOffsetAdjustment = CGPoint(x: 0, y: delta)
//
//            let isSizingElementAboveTopEdge = originalAttributes.frame.minY < (collectionView?.contentOffset.y ?? 0)
//
        ////            if isSizingElementAboveTopEdge {
//                invalidationContext.contentOffsetAdjustment = CGPoint(x: 0, y: delta)
        ////            }
//        }
//
//        if wasScrolledToBottom {
//            invalidationContext.contentOffsetAdjustment = CGPoint(x: 0, y: delta)
//            return invalidationContext
//        }

//        if isCurrentContentBiggerThenMin {
//            // when we scrolling up and item above screens top edge changes its attributes it will push all items below it to bottom
//            // making unpleasant jump. To prevent it we need to adjust current content offset by item delta
//            let isSizingElementAboveTopEdge = originalAttributes.frame.minY < (collectionView?.contentOffset.y ?? 0)
//
//            if isSizingElementAboveTopEdge {
//                invalidationContext.contentOffsetAdjustment = CGPoint(x: 0, y: delta)
//            }
//
//        } else {
//
//        }
        
        return invalidationContext
    }

    /// Represent the currently visible rectangle.
    public var visibleBounds: CGRect {
        guard let collectionView = collectionView else {
            return .zero
        }
        return CGRect(
            x: collectionView.contentInset.left,
            y: collectionView.contentOffset.y + collectionView.contentInset.top,
            width: collectionView.bounds.width - collectionView.contentInset.left - collectionView.contentInset.right,
            height: collectionView.bounds.height - collectionView.contentInset.top - collectionView.contentInset.bottom
        )
    }
    
    override open func invalidationContext(forBoundsChange newBounds: CGRect) -> UICollectionViewLayoutInvalidationContext {
        print("\n👉 \(#function) Old bounds \(collectionView!.bounds) | New bounds: \(newBounds)")
        defer { print("\(#function) 👈") }

        let invalidationContext = super.invalidationContext(forBoundsChange: newBounds) as! MessageLayoutInvalidationContext
        guard let collectionView = collectionView else { return invalidationContext }

        guard didPerformInitialLayout else {
            return invalidationContext
        }
        
        if !collectionView.isScrolling {
            // Save the current visual distance from the bottom edge
            invalidationContext.scrollPositionToRestore = collectionView.snapshotScrollPosition(isBottomEdgeFixed: true)
        
        } else {
            print(" * skipping storing the restore offset because the CV is scrolling")
        }

        return invalidationContext
    }

    override open func shouldInvalidateLayout(
        forPreferredLayoutAttributes preferredAttributes: UICollectionViewLayoutAttributes,
        withOriginalAttributes originalAttributes: UICollectionViewLayoutAttributes
    ) -> Bool {
        let item = currentItems[preferredAttributes.indexPath.item]
        return item.height != preferredAttributes.frame.height
    }

    var previousInitialAttributes: [IndexPath: UICollectionViewLayoutAttributes] = [:] {
        didSet {
            print("------ previous initial attributes -----")
            previousInitialAttributes.forEach {
                print("     * \($0.value.frame.origin)")
            }
        }
    }

    override open func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let cv = collectionView else { return true }
        let result = cv.bounds.size != newBounds.size || cv.contentInset != previousContentInsets
        return result
    }

    func isContentBiggerThan(items: ContiguousArray<LayoutItem>, height: CGFloat) -> Bool {
        guard let first = items.first, let last = items.last else { return false }
        return first.maxY - last.offset > height
    }

    var isContentBiggerThanOnePage: Bool {
        currentItems.last!.offset == 0 && currentItems.first!.maxY > visibleBounds.height
    }

    var newBoundsDelta: CGFloat?
    var isAnimatedBoundsChangeInProgress: Bool = false

//    override open func prepare(forAnimatedBoundsChange oldBounds: CGRect) {
//        super.prepare(forAnimatedBoundsChange: oldBounds)
//
//        print("PREPARE FOR ANIMATED BOUNDS CHANGE: \(collectionView!.bounds.height)")
//
//        isAnimatedBoundsChangeInProgress = true
//        newBoundsDelta = collectionView!.bounds.height - oldBounds.height
//
    ////        previousItems = currentItems
//
//        if !isContentBiggerThan(height: collectionView!.bounds.height) {
    ////            recalculateLayout(visibleHeight: collectionViewVisibleSize.height)
//        } else {
//            print("Content not bigger, skipping recalculation.")
//        }
//    }

//    override open func finalizeAnimatedBoundsChange() {
//        super.finalizeAnimatedBoundsChange()
//        isAnimatedBoundsChangeInProgress = false
//        newBoundsDelta = nil
//
    ////        animatingAttributes = [:]
//
//        CATransaction.setCompletionBlock {
//            if !self.isContentBiggerThan(height: self.collectionView!.bounds.height) {
//                let context = self
//                    .invalidationContext(forBoundsChange: self.collectionView!.bounds) as! MessageLayoutInvalidationContext
//                context.invalidateVisibleSizeRelatedMetrics = true
//                self.invalidateLayout(with: context)
//            }
//        }
//
    ////        if let animationKeys = collectionView!.layer.animationKeys(), animationKeys.isEmpty == false {
    ////            print("RUNNING ANIMATI")
    ////        }
    ////
//        print("* FINALIZE BOUNDS CHANGE")
//    }

    var isScrolledToBottom: Bool {
        guard let cv = collectionView else { return false }

        return cv.contentSize.height
            - cv.contentOffset.y
            - visibleBounds.height
            <= cv.contentInset.top
    }

    // MARK: - Animation updates

    // MARK: - Main layout access

    override open func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard !preBatchUpdatesCall else { return nil }

//        let rect = CGRect(
//            x: rect.origin.x,
//            y: rect.origin.y - rect.height / 2.0,
//            width: rect.width,
//            height: rect.height * 2)
        
        let result: [UICollectionViewLayoutAttributes] = currentItems
            .enumerated()
            .filter { _, item in
                let itemFrame = CGRect(x: 0, y: item.offset, width: rect.width, height: item.height)
                return rect.intersects(itemFrame)
            }
            .compactMap {
                let indexPath = IndexPath(item: indexForItem(with: $0.element.id)!, section: 0)
                return layoutAttributesForItem(at: indexPath) as! MessageCellLayoutAttributes
            }
            .sorted(by: { $0.indexPath < $1.indexPath })

//        print("Elements in rect \(rect): \n\t\(result.map({ "\($0.indexPath)" }).joined(separator: " | "))")
        
        return result
    }

    // MARK: - Layout for collection view items

    override open func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard !preBatchUpdatesCall else { return nil }

        guard indexPath.item < currentItems.count else { return nil }
        let idx = indexPath.item

        let attributes = currentItems[idx].attribute(for: idx, width: visibleBounds.width)

        if indexPath.item != 0 && appearingItems.contains(indexPath) {
            // Newly inserted messages at other than 0-0 index paths is a pagination insert -> no animations
//            attributes.isChangeAnimated = false
        }

        if isAnimatedBoundsChangeInProgress {
            // The bounds changes should not be animated on the cell content level
            attributes.isChangeAnimated = false
        }

        attributes.transform = .identity

        return attributes
    }

    override open func targetContentOffset(
        forProposedContentOffset proposedContentOffset: CGPoint,
        withScrollingVelocity velocity: CGPoint
    ) -> CGPoint {
        let maxOffset = collectionViewContentSize.height - visibleBounds.height
        let contentStartOffset = (currentItems.last?.offset ?? maxOffset) - collectionView!.contentInset.top

        var proposedContentOffset = proposedContentOffset
        proposedContentOffset.y = min(maxOffset, max(proposedContentOffset.y, contentStartOffset))

        return proposedContentOffset
    }

    override open func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard reloadingItems.contains(itemIndexPath) else {
            // New message
            if itemIndexPath == [0, 0] {
                let attr = currentItems[itemIndexPath.item]
                    .attribute(for: itemIndexPath.item, width: collectionViewContentSize.width)
                
                attr.isInitialAttributes = true
                attr.transform = CGAffineTransform(translationX: 0, y: 100)
                attr.isChangeAnimated = true
                
                return attr
            }
            
            if previousItems.indices.contains(previousItems.index(0, offsetBy: itemIndexPath.item)) {
                let attr = previousItems[itemIndexPath.item]
                    .attribute(for: itemIndexPath.item, width: collectionViewContentSize.width)
                return attr
            }
            return nil
        }
        
        let attr = previousItems[itemIndexPath.item].attribute(for: itemIndexPath.item, width: collectionViewContentSize.width)
        attr.isInitialAttributes = true
//        attr.isChangeAnimated = false

//        if previousItems.indices.contains(itemIndexPath.item) {
//            let previous = currentItems[itemIndexPath.item].attribute(for: itemIndexPath.item, width: collectionView!.bounds.width)
//            previous.isInitialAttributes = true
//            return previous
//        } else {
//            return currentItems[itemIndexPath.item].attribute(for: itemIndexPath.item, width: collectionView!.bounds.width)
//        }
        return attr
    }

    override open func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        if reloadingItems.contains(itemIndexPath) {
            let attr = previousItems[itemIndexPath.item].attribute(for: itemIndexPath.item, width: collectionViewContentSize.width)
            attr.isHidden = true
            attr.label = "finalLayoutAttributes"
            attr.isFinalAttributes = true
            //        attr.isChangeAnimated = false
            return attr

        } else {
            return super.finalLayoutAttributesForDisappearingItem(at: itemIndexPath)
        }
    }

//
    
//    open override func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
//        guard isAnimatedBoundsChangeInProgress else { return nil }
//
//        if let cached = previousInitialAttributes[itemIndexPath] as? MessageCellLayoutAttributes {
//            cached.label = "cached"
//            cached.isCachedAttribute = true
//            cached.isChangeAnimated = true
//            return cached
//        }
//
//        let attr = previousItems[itemIndexPath.item]
//            .attribute(for: itemIndexPath.item, width: collectionViewContentSize.width)
//
    ////        attr.isChangeAnimated = true
//        attr.alpha = 1
//
//        attr.label = "initial for appearing"
//        attr.isInitialAttributes = true
//        attr.isChangeAnimated = true
//
//
//        attr.frame.size.height = estimatedItemHeight
//
//        print("Initial attributes for \(itemIndexPath): \(attr.frame)")
//
//        previousInitialAttributes[itemIndexPath] = attr
//
//        return attr
//    }

//    open override func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
//
    ////        if let cached = previousInitialAttributes[itemIndexPath] as? MessageCellLayoutAttributes {
    ////            cached.isChangeAnimated = true
    ////            cached.transform = CGAffineTransform(translationX: 0, y: newBoundsDelta!)
    ////            return cached
    ////        }
//
//        let attr = currentItems[itemIndexPath.item].attribute(for: itemIndexPath.item, width: collectionViewVisibleSize.width)
//        attr.label = "finalLayoutAttributes"
//        attr.isChangeAnimated = false
//
//        previousInitialAttributes[itemIndexPath] = attr.copy() as! MessageCellLayoutAttributes
//
//        return attr
//    }

//    open override func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
//        guard isAnimatedBoundsChangeInProgress, let boundsDelta = newBoundsDelta else { return nil }
//
    ////        if let cached = previousInitialAttributes[itemIndexPath] as? MessageCellLayoutAttributes {
    ////            cached.label = "cached"
    ////            cached.isCachedAttribute = true
    ////            cached.isChangeAnimated = true
    ////            return cached
    ////        }
//
//        print(" **** final layou attributes for \(itemIndexPath)")
//
//        let attr = previousItems[itemIndexPath.item]
//            .attribute(for: itemIndexPath.item, width: collectionViewContentSize.width)
//
//        attr.label = "final"
    ////        attr.isChangeAnimated = false
//
    ////        attr.isChangeAnimated = true
    ////        attr.alpha = 0
//
//        // OK, this is a terrible workaround 🙈
    ////        if boundsDelta > 0 {
    ////            attr.transform = CGAffineTransform(translationX: 0, y: -34)
    ////        } else {
    ////            attr.transform = CGAffineTransform(translationX: 0, y: 34)
    ////        }
//
//        return attr
//    }

//    open override func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
//        if let boundsDiff = newBoundsDelta {
//            let attributes = previousItems[itemIndexPath.item]
//                .attribute(for: itemIndexPath.item, width: collectionViewContentSize.width)
    ////            attributes.isChangeAnimated = false
    ////            attributes.center.y -= boundsDiff
//            return attributes
//
//        } else {
//            return nil
//        }
//    }

//    open override func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
//        if let boundsDiff = newBoundsDelta {
//            let attributes = currentItems[itemIndexPath.item]
//                .attribute(for: itemIndexPath.item, width: collectionViewContentSize.width)
    ////            attributes.isChangeAnimated =
    ////            attributes.center.y += boundsDiff
//            attributes.alpha = 1
//            attributes.isChangeAnimated = false
//            return attributes
//
//        } else {
//            return nil
//        }
//    }

//    override open func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
//        let itemIndex = itemIndexPath.item
//        if appearingItems.contains(itemIndexPath) {
//            // this is item that have been inserted into collection view in current batch update
//            let attribute = currentItems[itemIndex].attribute(for: itemIndex, width: collectionViewVisibleSize.width)
//
//            animatingAttributes[itemIndexPath] = attribute
//            return attribute
//        }
//
//        if let itemId = idForItem(at: itemIndex), let oldItemIndex = oldIndexForItem(with: itemId) {
//            // this is item that already presented in collection view, but collection view decided to reload it
//            // by removing and inserting it back (4head)
//            // to properly animate possible change of such item, we need to return its attributes BEFORE batch update
//            let itemStaysInPlace = itemIndex == oldItemIndex
//
//            let attribute = (itemStaysInPlace ? currentItems[itemIndex] : previousItems[oldItemIndex])
//                .attribute(for: itemStaysInPlace ? itemIndex : oldItemIndex, width: collectionViewVisibleSize.width)
//
    ////            if let boundsChangeOffset = self.boundsChangeOffset {
    ////                attribute.center.y += boundsChangeOffset
    ////            }
//
//            return attribute
//        }
//
//        let attribute = currentItems[itemIndex].attribute(for: itemIndex, width: collectionViewVisibleSize.width)
//
//        return  attribute
//
    ////        return super.initialLayoutAttributesForAppearingItem(at: itemIndexPath)
//    }
//
//    override open func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
//        let idx = itemIndexPath.item
//        guard let id = oldIdForItem(at: idx) else { return nil }
//        if disappearingItems.contains(itemIndexPath) {
//            // item gets removed from collection view, we don't do any special delete animations for now, so just return
//            // item attributes BEFORE batch update and let it fade away
//            let attribute = previousItems[idx]
//                .attribute(for: idx, width: collectionViewContentSize.width)
//                .copy() as! UICollectionViewLayoutAttributes
//
//            attribute.alpha = 0
//            return attribute
//
//        } else if let newIdx = indexForItem(with: id) {
//            // this is item that will stay in collection view, but collection view decided to reload it
//            // by removing and inserting it back (4head)
//            // to properly animate possible change of such item, we need to return its attributes AFTER batch update
//            let attribute = currentItems[newIdx]
//                .attribute(for: newIdx, width: collectionViewContentSize.width)
//                .copy() as! UICollectionViewLayoutAttributes
//
//            animatingAttributes[attribute.indexPath] = attribute
    ////            attribute.alpha = 0
//            return attribute
//        }
//
//        if let newBoundsDelta = self.newBoundsDelta {
//            let attributes = currentItems[idx].attribute(for: itemIndexPath.item, width: collectionViewContentSize.width)
//            attributes.center.y += newBoundsDelta
//            attributes.isChangeAnimated = false
//            return attributes
//        }
//
//        return super.finalLayoutAttributesForDisappearingItem(at: itemIndexPath)
//    }

    // MARK: - Access Layout Item

    open func idForItem(at idx: Int) -> UUID? {
        guard currentItems.indices.contains(idx) else { return nil }
        return currentItems[idx].id
    }

    open func indexForItem(with id: UUID) -> Int? {
        currentItems.firstIndex { $0.id == id }
    }

    open func oldIdForItem(at idx: Int) -> UUID? {
        guard previousItems.indices.contains(idx) else { return nil }
        return previousItems[idx].id
    }

    open func oldIndexForItem(with id: UUID) -> Int? {
        previousItems.firstIndex { $0.id == id }
    }
}

extension ChatMessageListCollectionViewLayout {
    public struct LayoutItem {
        let id = UUID()
        public var offset: CGFloat
        public var height: CGFloat

        public var label: String = ""
        public var layoutOptions: ChatMessageLayoutOptions?
        public var previousLayoutOptions: ChatMessageLayoutOptions?

        public var isInitial = true

        public var maxY: CGFloat {
            offset + height
        }

        public init(offset: CGFloat, height: CGFloat) {
            self.offset = offset
            self.height = height
        }

        public func attribute(for index: Int, width: CGFloat) -> MessageCellLayoutAttributes {
            let attribute = MessageCellLayoutAttributes(forCellWith: IndexPath(item: index, section: 0))
            attribute.frame = CGRect(x: 0, y: offset, width: width, height: height)
            // default `zIndex` value is 0, but for some undocumented reason self-sizing
            // (concretely `contentView.systemLayoutFitting(...)`) doesn't work correctly,
            // so we need to make sure we do not use it, we need to add 1 so indexPath 0-0 doesn't have
            // problematic 0 zIndex
            attribute.zIndex = index + 1

            attribute.layoutOptions = layoutOptions
            attribute.previousLayoutOptions = previousLayoutOptions
            attribute.label = label
            attribute.isInitialAttributes = isInitial

            return attribute
        }
    }
}

extension ChatMessageListCollectionViewLayout {
    /// Doesn't change the height of the items just makes sure the spacing and visual ordering of the is correct
    /// by recalculating layout offsets from scratch.
    ///
    /// - Complexity: O(n) - use carefully for layouts with a lot of items.
    ///
    func recalculateItemOffsets(items: inout ContiguousArray<LayoutItem>, visibleHeight: CGFloat) {
        print("👉 Recalculating layout: Bottom -> Top: \(visibleHeight)")

        // Completely recreate the layout such that it fits the last screen completely
        var offset = visibleHeight

        for i in 0..<items.count {
            var item = items[i]
            item.offset = offset - item.height
            offset -= (item.height + spacing)
            items[i] = item
        }

        // If the current items don't fit to the preferred height, recalculate again with top -> bottom approach
        let topOverflow = items.last?.offset ?? 0
        if topOverflow < 0 {
            print("  * Recalculating layout: Top -> Bottom: \(visibleHeight)")
            var offset: CGFloat = 0
            for i in (0..<items.count).reversed() {
                var item = items[i]
                item.offset = offset
                items[i] = item
                offset += spacing + item.height
            }
        }
        print()
    }

    func getRestoreOffset() -> CGFloat {
        collectionViewContentSize.height
            - collectionView!.contentOffset.y
            - visibleBounds.height
    }

    func resolveRestoreOffset(_ restoreOffset: CGFloat) -> CGFloat {
        collectionViewContentSize.height
            - restoreOffset
            - visibleBounds.height
    }
}

private extension UIScrollView {
    /// Return `true` if the scroll views is scrolling.
    var isScrolling: Bool {
        isDragging || isDecelerating
    }
}
