//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
import UIKit

/// A Button subclass that should be used for closing.
public typealias CloseButton = _CloseButton<NoExtraData>

/// A Button subclass that should be used for closing.
open class _CloseButton<ExtraData: ExtraDataTypes>: _Button, AppearanceProvider {
    override open func setUpAppearance() {
        super.setUpAppearance()
        
        setImage(appearance.images.close, for: .normal)
        tintColor = appearance.colorPalette.text
    }
}
