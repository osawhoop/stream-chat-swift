//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
import StreamChatTestTools
@testable import StreamChatUI
import XCTest

final class ChatThreadArrowView_Tests: XCTestCase {
    func test_appearanceCustomization_usingAppearance() {
        // Create custom appearance
        var appearance = Appearance()
        appearance.colorPalette.border = Appearance.default.colorPalette.background4

        // Create a leading arrow with custom appearance
        let arrow = ChatThreadArrowView()
        arrow.content = .toLeading
        arrow.appearance = appearance

        // Assert arrow is rendered correctly
        AssertSnapshot(arrow.embeddedIntoContainer, variants: .onlyUserInterfaceStyles)
    }

    func test_appearanceCustomization_usingSubclassing() {
        // Declare custom arrow type
        class TestThreadArrowView: ChatThreadArrowView {
            override func setUpAppearance() {
                super.setUpAppearance()

                shape.strokeColor = appearance.colorPalette.background1.cgColor
                shape.lineWidth = 2
            }
        }

        // Create a custom leading arrow
        let arrow = TestThreadArrowView()
        arrow.content = .toLeading

        // Assert arrow is rendered correctly
        AssertSnapshot(arrow.embeddedIntoContainer)
    }

    func test_appearance_noContent() {
        // Create an arrow
        let arrow = ChatThreadArrowView()

        // Reset the content
        arrow.content = nil

        // Assert arrow is rendered correctly
        AssertSnapshot(arrow.embeddedIntoContainer, variants: .onlyUserInterfaceStyles)
    }

    func test_appearance_toLeading() {
        // Create an arrow
        let leadingArrow = ChatThreadArrowView()

        // Make it leading
        leadingArrow.content = .toLeading

        // Assert arrow is rendered correctly
        AssertSnapshot(leadingArrow.embeddedIntoContainer)
    }

    func test_appearance_toTrailing() {
        // Create an arrow
        let trailingArrow = ChatThreadArrowView()

        // Make it trailing
        trailingArrow.content = .toTrailing

        // Assert arrow is rendered correctly
        AssertSnapshot(trailingArrow.embeddedIntoContainer)
    }
}

private extension ChatThreadArrowView {
    // We wrap an arrow into a larger container because it is drawn outside the bounds.
    var embeddedIntoContainer: UIView {
        let arrowSize = CGSize(width: 16, height: 16)
        heightAnchor.constraint(equalToConstant: arrowSize.height).isActive = true
        widthAnchor.constraint(equalToConstant: arrowSize.width).isActive = true

        let container = UIView().withoutAutoresizingMaskConstraints
        container.heightAnchor.constraint(equalToConstant: arrowSize.height * 3).isActive = true
        container.widthAnchor.constraint(equalToConstant: arrowSize.width).isActive = true
        container.addSubview(withoutAutoresizingMaskConstraints)
        pin(anchors: [.leading, .trailing, .bottom], to: container)

        return container
    }
}
