//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
import UIKit

/// A view that shows an arrow from message bubble to thread replies info/thread reply button.
open class ChatThreadArrowView: _View, AppearanceProvider {
    /// A type representing arrow direction.
    public enum Direction {
        case toTrailing
        case toLeading
    }

    /// A direction an arrow is drawn.
    public var content: Direction? {
        didSet { updateContentIfNeeded() }
    }

    /// A view layer which has a shape of an arrow.
    public var shape: CAShapeLayer {
        layer as! CAShapeLayer
    }

    /// Returns the path used to draw an arrow.
    open var arrowPath: CGPath? {
        guard let direction = content else { return nil }

        let isLeftToRightWithTrailing = direction == .toTrailing && traitCollection.layoutDirection == .leftToRight
        let isRightToLeftWithLeading = direction == .toLeading && traitCollection.layoutDirection == .rightToLeft
        let isLeftToRight = isLeftToRightWithTrailing || isRightToLeftWithLeading

        let corner: CGFloat = 16
        let height = bounds.height / 2
        let lineCenter = shape.lineWidth / 2

        let startX = isLeftToRight ? lineCenter : (bounds.width - lineCenter)
        let endX = isLeftToRight ? corner : (bounds.width - corner)

        let path = CGMutablePath()
        path.move(to: CGPoint(x: startX, y: -3 * height))
        path.addLine(to: CGPoint(x: startX, y: height - corner))
        path.addQuadCurve(
            to: CGPoint(x: endX, y: height),
            control: CGPoint(x: startX, y: height)
        )

        return path
    }

    override open func setUpAppearance() {
        super.setUpAppearance()

        shape.contentsScale = layer.contentsScale
        shape.strokeColor = appearance.colorPalette.border.cgColor
        shape.fillColor = nil
        shape.lineWidth = 1
    }

    override open func updateContent() {
        super.updateContent()

        setNeedsDisplay()
    }

    override open func draw(_ rect: CGRect) {
        super.draw(rect)

        shape.path = arrowPath
    }

    override public class var layerClass: AnyClass {
        CAShapeLayer.self
    }
}
