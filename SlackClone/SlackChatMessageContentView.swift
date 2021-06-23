//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
import StreamChatUI
import UIKit

let chatClient = ChatClient(config: .init(apiKeyString: ""), tokenProvider: .anonymous)

final class SlackChatMessageContentView: ChatMessageContentView {
    override var maxContentWidthMultiplier: CGFloat { 1 }
    
    let reactionsContainer = UIStackView()
    
    override func layout(options: ChatMessageLayoutOptions) {
        super.layout(options: options)
        mainContainer.alignment = .leading
        bubbleThreadMetaContainer.changeOrdering()
        bubbleContentContainer.directionalLayoutMargins = .zero
        
        reactionsView?.removeFromSuperview()
        
        if options.contains(.reactions) {
            bubbleContentContainer.addArrangedSubview(reactionsContainer)
            
            reactionsContainer.axis = .horizontal
            reactionsContainer.alignment = .leading
            reactionsContainer.spacing = UIStackView.spacingUseSystem
        }
    }

    override func createTextView() -> UITextView {
        let textView = super.createTextView()
        textView.textContainerInset = .zero
        return textView
    }
    
    override func updateContent() {
        super.updateContent()
        
        guard let content = content else { return }
        
        reactionsContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        content.reactionScores.forEach { (reactionType, score) in
            // If image for the reaction exists, let's add the reaction.
            // Otherwise do nothing because component would show only number of scores.
            if let image = appearance.images.availableReactions[reactionType]?.smallIcon {
                let button = SingleReactionItemButton()
                button.setImage(image, for: .normal)
                button.setTitle("\(score)", for: .normal)
                button
                    .onTap = {
                        chatClient.messageController(cid: ChannelId(type: .messaging, id: "channel-id"), messageId: "message-id")
                            .addReaction(reactionType)
                    }
                reactionsContainer.addArrangedSubview(button)
            }
        }
        
        let trailingSpacer = UIView()
        trailingSpacer.setContentHuggingPriority(.fittingSizeLevel, for: .horizontal)
        trailingSpacer.setContentCompressionResistancePriority(.fittingSizeLevel, for: .horizontal)
        reactionsContainer.addArrangedSubview(trailingSpacer)
    }
}

/// Button which displays reaction and it's score.
open class SingleReactionItemButton: UIButton {
    var onTap: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setTitleColor(Appearance.default.colorPalette.text, for: .normal)
        addTarget(self, action: #selector(didTap), for: .touchUpInside)
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setTitleColor(Appearance.default.colorPalette.text, for: .normal)
        addTarget(self, action: #selector(didTap), for: .touchUpInside)
    }
    
    @objc func didTap() {
        onTap?()
    }
}

extension ContainerStackView {
    func changeOrdering() {
        let subviews = self.subviews
        removeAllArrangedSubviews()
        addArrangedSubviews(subviews.reversed())
    }
}
