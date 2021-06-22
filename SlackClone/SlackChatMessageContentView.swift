//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
import StreamChatUI
import UIKit

final class SlackChatMessageContentView: ChatMessageContentView {
    override var maxContentWidthMultiplier: CGFloat { 1 }
    
    override func layout(options: ChatMessageLayoutOptions) {
        super.layout(options: options)

        mainContainer.alignment = .leading
        bubbleThreadMetaContainer.changeOrdering()
        bubbleContentContainer.directionalLayoutMargins = .zero
        
        let reactionsBubbleView = createReactionsBubbleView()
        let reactionsView = createReactionsView()
        reactionsBubbleView.addSubview(reactionsView)
        let reactionsContainer = ContainerStackView()
        reactionsContainer.addArrangedSubview(reactionsBubbleView)
        bubbleThreadMetaContainer.addArrangedSubview(reactionsContainer)
        bubbleThreadMetaContainer.distribution = .natural
        
        reactionsBubbleView.bottomAnchor.constraint(equalTo: bubbleThreadMetaContainer.bottomAnchor).isActive = true
    }

    override func createTextView() -> UITextView {
        let textView = super.createTextView()
        textView.textContainerInset = .zero
        return textView
    }
}

extension ContainerStackView {
    func changeOrdering() {
        let subviews = self.subviews
        removeAllArrangedSubviews()
        addArrangedSubviews(subviews.reversed())
    }
}
