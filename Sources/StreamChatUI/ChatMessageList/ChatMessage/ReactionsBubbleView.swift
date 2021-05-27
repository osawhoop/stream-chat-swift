//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
import UIKit

/// A view that shows a bubble around reactions in message content view.
open class ReactionsBubbleView: _View, AppearanceProvider, SwiftUIRepresentable {
    /// A type representing bubble arrow direction.
    public enum TailDirection {
        case toTrailing
        case toLeading
    }

    /// A bubble tail direction.
    open var content: TailDirection? {
        didSet { updateContentIfNeeded() }
    }

    /// A bubble the color is filled with.
    open var bubbleFillColor: UIColor? {
        content.map {
            $0 == .toTrailing ?
                appearance.colorPalette.popoverBackground :
                appearance.colorPalette.background2
        }
    }

    /// A bubble's border color.
    open var bubbleStrokeColor: UIColor? {
        content.map {
            $0 == .toTrailing ?
                appearance.colorPalette.border :
                appearance.colorPalette.background2
        }
    }

    /// A path used to draw a bubble.
    open var bubblePath: UIBezierPath? {
        guard content != nil else { return nil }

        let borderLineWidth: CGFloat = 1
        let dr = borderLineWidth / 2

        let bubbleBodyRect = CGRect(
            center: bubbleBodyCenter,
            size: .init(
                width: bounds.width + dr,
                height: bounds.height - tailHeight + dr
            )
        )

        let bubbleBodyPath = UIBezierPath(
            roundedRect: bubbleBodyRect,
            cornerRadius: bubbleBodyRect.height / 2
        )

        let bigTailPath = UIBezierPath(
            ovalIn: .circleBounds(
                center: bigTailCircleCenter,
                radius: 4 + dr
            )
        )

        let smallTailPath = UIBezierPath(
            ovalIn: .circleBounds(
                center: smallTailCircleCenter,
                radius: 2 + dr
            )
        )

        let path = UIBezierPath()
        path.lineWidth = borderLineWidth
        path.append(bubbleBodyPath)
        path.append(bigTailPath)
        path.append(smallTailPath)
        return path
    }

    override open func setUpLayout() {
        super.setUpLayout()

        directionalLayoutMargins.bottom += tailHeight
    }

    override open func updateContent() {
        super.updateContent()

        setNeedsDisplay()
    }

    override open func draw(_ rect: CGRect) {
        super.draw(rect)

        bubbleStrokeColor?.setStroke()
        bubbleFillColor?.setFill()

        if let path = bubblePath {
            path.stroke()
            path.fill()
        }
    }
}

private extension ReactionsBubbleView {
    var tailHeight: CGFloat {
        6
    }

    var bubbleBodyCenter: CGPoint {
        bounds
            .inset(by: .init(top: 0, left: 0, bottom: tailHeight, right: 0))
            .center
    }

    var bigTailCircleCenter: CGPoint {
        bubbleBodyCenter.offsetBy(
            dx: isTailLeftToRight ? 10 : -10,
            dy: 14
        )
    }

    var smallTailCircleCenter: CGPoint {
        bigTailCircleCenter.offsetBy(
            dx: isTailLeftToRight ? 4 : -4,
            dy: 6
        )
    }

    var isTailLeftToRight: Bool {
        let isLeftToRightWithTrailing = content == .toTrailing && traitCollection.layoutDirection == .leftToRight
        let isRightToLeftWithLeading = content == .toLeading && traitCollection.layoutDirection == .rightToLeft
        return isLeftToRightWithTrailing || isRightToLeftWithLeading
    }
}
