//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
import StreamChatUI
import UIKit

final class SlackChatMessageContentView: ChatMessageContentView {
    override var maxContentWidthMultiplier: CGFloat { 1 }
    
    public lazy var bottomReactionsView: BottomReactionsView = { BottomReactionsView() }()
    
    override func layout(options: ChatMessageLayoutOptions) {
        super.layout(options: options)

        mainContainer.alignment = .leading
        bubbleThreadMetaContainer.changeOrdering()
        bubbleContentContainer.directionalLayoutMargins = .zero
        
        reactionsView?.isHidden = true

        bottomReactionsView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bottomReactionsView)
        bottomReactionsView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor).isActive = true
        bottomReactionsView.topAnchor.constraint(equalTo: bubbleThreadMetaContainer.layoutMarginsGuide.bottomAnchor, constant: 16)
            .isActive = true
        bottomReactionsView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        bottomReactionsView.leadingAnchor.constraint(equalTo: bubbleThreadMetaContainer.leadingAnchor).isActive = true
        bottomReactionsView.isHidden = true
    }

    override func createTextView() -> UITextView {
        let textView = super.createTextView()
        textView.textContainerInset = .zero
        return textView
    }
    
    override func updateContent() {
        super.updateContent()
        bottomReactionsView.content = content.map {
            BottomReactionsView.Content(
                reactions: $0.reactions,
                didTapOnReaction: nil
            )
        }
    }
}

extension ContainerStackView {
    func changeOrdering() {
        let subviews = self.subviews
        removeAllArrangedSubviews()
        addArrangedSubviews(subviews.reversed())
    }
}

/// StackView which shows Reactions with their scores.
class BottomReactionsView: _View {
    public struct Content {
        public let reactions: [ChatMessageReactionData]
        public let didTapOnReaction: ((MessageReactionType) -> Void)?

        public init(
            reactions: [ChatMessageReactionData],
            didTapOnReaction: ((MessageReactionType) -> Void)?
        ) {
            self.reactions = reactions
            self.didTapOnReaction = didTapOnReaction
        }
    }
    
    var content: Content? {
        didSet {
            updateContent()
        }
    }
    
    public lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.alignment = .leading
        stackView.spacing = UIStackView.spacingUseSystem
       
        return stackView
    }()
    
    override func setUpLayout() {
        super.setUpLayout()
        addSubview(stackView)
        stackView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        stackView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        stackView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        stackView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
    }
    
    override func updateContent() {
        super.updateContent()
        
        // We check if we have available images for the given type of reaction, if not, we hide the reaction.
        guard !(content?.reactions.compactMap { Appearance.default.images.availableReactions[$0.type] }.isEmpty ?? false)
        else {
            isHidden = true
            return
        }
        
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        isHidden = false
        content?.reactions.forEach { reaction in
            let reactionButton = SingleReactionItemButton()
            // self.content?.didTapOnReaction(reaction.type)
            let content = SingleReactionItemButton.Content(useBigIcon: true, reaction: reaction, onTap: nil)
            reactionButton.content = content
            self.stackView.addArrangedSubview(reactionButton)
        }
        // Add spacing so we have leading...
        let trailingSpacer = UIView()
        trailingSpacer.setContentHuggingPriority(.fittingSizeLevel, for: .horizontal)
        trailingSpacer.setContentCompressionResistancePriority(.fittingSizeLevel, for: .horizontal)
        stackView.addArrangedSubview(trailingSpacer)
    }
}

/// Button which displays reaction and it's score.
open class SingleReactionItemButton: _Button {
    public struct Content {
        public let useBigIcon: Bool
        public let reaction: ChatMessageReactionData
        public var onTap: ((MessageReactionType) -> Void)?

        public init(
            useBigIcon: Bool,
            reaction: ChatMessageReactionData,
            onTap: ((MessageReactionType) -> Void)?
        ) {
            self.useBigIcon = useBigIcon
            self.reaction = reaction
            self.onTap = onTap
        }
    }
    
    public var content: Content? {
        didSet {
            updateContentIfNeeded()
        }
    }
    
    override open func setUp() {
        super.setUp()

        addTarget(self, action: #selector(didTap), for: .touchUpInside)
    }
    
    override open func updateContent() {
        guard let content = content else { return }
        setImage(content.reaction.reactionImage(isLarge: false), for: .normal)
        setTitle("\(content.reaction.score)", for: .normal)
    }
    
    override open func setUpAppearance() {
        super.setUpAppearance()
        setTitleColor(Appearance.default.colorPalette.text, for: .normal)
    }
    
    @objc func didTap() {
        if let content = content {
            content.onTap?(content.reaction.type)
        }
    }
}

// MARK: - Convenient extensions

extension ChatMessageReactionData {
    func reactionImage(isLarge: Bool) -> UIImage? {
        let reactions = Appearance.default.images.availableReactions[type]
        return isLarge ? reactions?.largeIcon : reactions?.smallIcon
    }
}

extension _ChatMessage {
    var reactions: [ChatMessageReactionData] {
        let userReactionIDs = Set(currentUserReactions.map(\.type))
        return reactionScores
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { .init(type: $0.key, score: $0.value, isChosenByCurrentUser: userReactionIDs.contains($0.key)) }
    }
}
