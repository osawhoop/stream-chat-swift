//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
import StreamChatTestTools
import StreamChatUI
import XCTest

final class ChatMessageErrorIndicator_Tests: XCTestCase {
    func test_appearanceCustomization_usingAppearance() {
        var appearance = Appearance()
        appearance.colorPalette.alert = Appearance.default.colorPalette.highlightedAccentBackground1

        let errorIndicator = ChatMessageErrorIndicator()
        errorIndicator.translatesAutoresizingMaskIntoConstraints = false
        errorIndicator.appearance = appearance

        AssertSnapshot(errorIndicator, variants: .onlyUserInterfaceStyles)
    }

    func test_appearanceCustomization_usingSubclassing() {
        class TestErrorIndicator: ChatMessageErrorIndicator {
            override func setUpAppearance() {
                setImage(appearance.images.close, for: .normal)
                tintColor = appearance.colorPalette.highlightedAccentBackground1
            }
        }

        let errorIndicator = TestErrorIndicator()
        errorIndicator.translatesAutoresizingMaskIntoConstraints = false

        AssertSnapshot(errorIndicator, variants: .onlyUserInterfaceStyles)
    }
}
