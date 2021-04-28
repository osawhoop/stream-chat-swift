//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
import UIKit

/// A Button subclass that should be used for sharing content
public typealias ShareButton = _ShareButton<NoExtraData>

/// A Button subclass that should be used for sharing content
open class _ShareButton<ExtraData: ExtraDataTypes>: _Button, AppearanceProvider {
    override open func setUpAppearance() {
        super.setUpAppearance()
        
        setImage(appearance.images.share, for: .normal)
        tintColor = appearance.colorPalette.text
    }
}
