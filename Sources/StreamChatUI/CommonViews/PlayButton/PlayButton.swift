//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
import UIKit

/// Button used for sending a message, or any type of content.
open class PlayButton: _Button, AppearanceProvider {
    override open var intrinsicContentSize: CGSize {
        imageView?.intrinsicContentSize ?? super.intrinsicContentSize
    }
    
    override open func setUpAppearance() {
        super.setUpAppearance()

        let normalStateImage = appearance.images.play
        setImage(normalStateImage, for: .normal)
    }
}
