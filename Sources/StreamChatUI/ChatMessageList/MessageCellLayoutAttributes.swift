//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import UIKit

/// A custom `UICollectionViewLayoutAttributes` subclass used to store additional
/// information about the layout of the message cell.
open class MessageCellLayoutAttributes: UICollectionViewLayoutAttributes {
    /// The current message layout option of the cell
    open var layoutOptions: ChatMessageLayoutOptions?

    /// In case the update causes update of the cell's message layout options,
    /// this variable contains the previous layout option.
    open var previousLayoutOptions: ChatMessageLayoutOptions?

    /// A string that can be used for debug purposes. Has no effect on the functionality.
    open var label: String = ""

    open var isChangeAnimated: Bool = true

    /// If set to `true` this attributes are the initial attributes which can be invalid.
    open var isInitialAttributes: Bool = false

    open var isFinalAttributes: Bool = false

    open var isCachedAttribute: Bool = false

    override open func copy(with zone: NSZone? = nil) -> Any {
        let copy = super.copy(with: zone) as! MessageCellLayoutAttributes
        copy.layoutOptions = layoutOptions
        copy.previousLayoutOptions = previousLayoutOptions
        copy.label = label
        copy.isChangeAnimated = isChangeAnimated
        copy.isInitialAttributes = isInitialAttributes
        copy.isFinalAttributes = isFinalAttributes
        return copy
    }

    override open func isEqual(_ object: Any?) -> Bool {
        guard let rhs = object as? MessageCellLayoutAttributes else { return false }

        return layoutOptions == rhs.layoutOptions
            && previousLayoutOptions == rhs.previousLayoutOptions
            && label == rhs.label
            && isChangeAnimated == rhs.isChangeAnimated
            && isInitialAttributes == rhs.isInitialAttributes
            && isFinalAttributes == rhs.isFinalAttributes
            && super.isEqual(object)
    }
}
