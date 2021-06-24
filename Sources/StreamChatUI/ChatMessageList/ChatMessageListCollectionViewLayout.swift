//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import UIKit

open class ChatMessageListCollectionViewLayout: UICollectionViewFlowLayout {
    open var mirrorYAxis: Bool { true }
    open var spacing: CGFloat { 2 }
    
    // MARK: - Initialization

    override public required init() {
        super.init()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - Prepare
    
    open override func prepare() {
        super.prepare()
        
        estimatedItemSize = CGSize(width: collectionView?.bounds.width ?? 0, height: 100)
        minimumLineSpacing = spacing
    }
    
    // MARK: - Attributes
    
    open override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        super
            .layoutAttributesForItem(at: indexPath)
            .map(mirrorIfNeeded)
    }
    
    open override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        super
            .layoutAttributesForElements(in: rect)?
            .compactMap(mirrorIfNeeded)
    }
    
    // MARK: - Private
    
    private func mirrorIfNeeded(_ attributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        if mirrorYAxis {
            attributes.transform = .init(scaleX: 1, y: -1)
        }
        return attributes
    }
}
