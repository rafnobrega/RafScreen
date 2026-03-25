import AppKit
import CoreGraphics

/// Renders a device bezel frame around the video content
class DeviceBezelView: NSView {
    var deviceModel: DeviceModel = DeviceModelStore.defaultModel() {
        didSet { needsDisplay = true; invalidateIntrinsicContentSize() }
    }

    var hideBezel: Bool = false {
        didSet { needsDisplay = true; invalidateIntrinsicContentSize() }
    }

    // The scale factor to fit the device in the view
    private var renderScale: CGFloat {
        let availableWidth = bounds.width
        let availableHeight = bounds.height
        let totalDeviceWidth = deviceModel.screenWidth + deviceModel.bezelWidth * 2
        let totalDeviceHeight = deviceModel.screenHeight + deviceModel.bezelWidth * 2 +
            (deviceModel.hasHomeButton ? 60 : 0) + // home button area
            (deviceModel.hasHomeButton ? 40 : 0)    // top bezel for home button models
        let scaleX = availableWidth / totalDeviceWidth
        let scaleY = availableHeight / totalDeviceHeight
        return min(scaleX, scaleY, 1.0)
    }

    /// Returns the frame where the screen content should be placed (in this view's coordinate space)
    var screenContentFrame: CGRect {
        if hideBezel {
            // Fill the view, maintaining aspect ratio
            let ratio = deviceModel.aspectRatio
            var w = bounds.width
            var h = w * ratio
            if h > bounds.height {
                h = bounds.height
                w = h / ratio
            }
            let x = (bounds.width - w) / 2
            let y = (bounds.height - h) / 2
            return CGRect(x: x, y: y, width: w, height: h)
        }

        let scale = renderScale
        let deviceWidth = deviceModel.screenWidth * scale
        let deviceHeight = deviceModel.screenHeight * scale
        let bezel = deviceModel.bezelWidth * scale

        let totalWidth = deviceWidth + bezel * 2
        let topExtra: CGFloat = deviceModel.hasHomeButton ? 40 * scale : 0
        let bottomExtra: CGFloat = deviceModel.hasHomeButton ? 60 * scale : 0
        let totalHeight = deviceHeight + bezel * 2 + topExtra + bottomExtra

        let originX = (bounds.width - totalWidth) / 2 + bezel
        let originY: CGFloat
        if isFlipped {
            originY = (bounds.height - totalHeight) / 2 + bezel + topExtra
        } else {
            originY = (bounds.height - totalHeight) / 2 + bezel + bottomExtra
        }
        return CGRect(x: originX, y: originY, width: deviceWidth, height: deviceHeight)
    }

    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize {
        let totalWidth = deviceModel.screenWidth + deviceModel.bezelWidth * 2
        let topExtra: CGFloat = deviceModel.hasHomeButton ? 40 : 0
        let bottomExtra: CGFloat = deviceModel.hasHomeButton ? 60 : 0
        let totalHeight = deviceModel.screenHeight + deviceModel.bezelWidth * 2 + topExtra + bottomExtra
        return NSSize(width: totalWidth * 0.5, height: totalHeight * 0.5)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // No bezel mode — just draw a black screen area
        if hideBezel {
            let screenRect = screenContentFrame
            ctx.saveGState()
            NSColor.black.setFill()
            let cornerR = deviceModel.cornerRadius > 0 ? 20.0 : 0.0
            let path = NSBezierPath(roundedRect: screenRect, xRadius: cornerR, yRadius: cornerR)
            path.fill()
            ctx.restoreGState()
            return
        }

        let scale = renderScale
        let screenW = deviceModel.screenWidth * scale
        let screenH = deviceModel.screenHeight * scale
        let bezel = deviceModel.bezelWidth * scale
        let cornerR = deviceModel.cornerRadius * scale

        let topExtra: CGFloat = deviceModel.hasHomeButton ? 40 * scale : 0
        let bottomExtra: CGFloat = deviceModel.hasHomeButton ? 60 * scale : 0

        let totalW = screenW + bezel * 2
        let totalH = screenH + bezel * 2 + topExtra + bottomExtra

        let startX = (bounds.width - totalW) / 2
        let startY = (bounds.height - totalH) / 2

        let deviceRect = CGRect(x: startX, y: startY, width: totalW, height: totalH)

        // Outer device body
        let outerCornerR: CGFloat
        if deviceModel.hasHomeButton {
            outerCornerR = cornerR + bezel + 8 * scale
        } else {
            outerCornerR = cornerR + bezel
        }

        let devicePath = NSBezierPath(roundedRect: deviceRect, xRadius: outerCornerR, yRadius: outerCornerR)

        // Device body color: dark gray / space gray
        ctx.saveGState()
        NSColor(calibratedWhite: 0.12, alpha: 1.0).setFill()
        devicePath.fill()

        // Subtle edge highlight
        NSColor(calibratedWhite: 0.22, alpha: 1.0).setStroke()
        devicePath.lineWidth = 1.0
        devicePath.stroke()
        ctx.restoreGState()

        // Screen area
        let screenRect = screenContentFrame

        // Screen background (black when no content)
        let screenPath: NSBezierPath
        if deviceModel.cornerRadius > 0 {
            screenPath = NSBezierPath(roundedRect: screenRect, xRadius: cornerR, yRadius: cornerR)
        } else {
            screenPath = NSBezierPath(rect: screenRect)
        }

        ctx.saveGState()
        NSColor.black.setFill()
        screenPath.fill()
        ctx.restoreGState()

        // Side button (power button on right side)
        if deviceModel.category == .iPhone {
            drawSideButtons(in: ctx, deviceRect: deviceRect, scale: scale)
        }

        // Home button for older models
        if deviceModel.hasHomeButton {
            drawHomeButton(in: ctx, deviceRect: deviceRect, scale: scale)
        }

        // Notch or Dynamic Island
        switch deviceModel.notchStyle {
        case .notch:
            drawNotch(in: ctx, screenRect: screenRect, scale: scale)
        case .dynamicIsland:
            drawDynamicIsland(in: ctx, screenRect: screenRect, scale: scale)
        case .none, .iPadCamera:
            break
        }
    }

    // MARK: - Drawing Helpers

    private func drawSideButtons(in ctx: CGContext, deviceRect: CGRect, scale: CGFloat) {
        ctx.saveGState()
        let buttonColor = NSColor(calibratedWhite: 0.18, alpha: 1.0)
        buttonColor.setFill()

        // Power button (right side)
        let powerWidth: CGFloat = 3 * scale
        let powerHeight: CGFloat = 50 * scale
        let powerY = deviceRect.minY + 120 * scale
        let powerRect = CGRect(
            x: deviceRect.maxX,
            y: powerY,
            width: powerWidth,
            height: powerHeight
        )
        let powerPath = NSBezierPath(roundedRect: powerRect, xRadius: 1.5 * scale, yRadius: 1.5 * scale)
        powerPath.fill()

        // Volume buttons (left side)
        let volWidth: CGFloat = 3 * scale
        let volHeight: CGFloat = 35 * scale

        // Volume up
        let volUpY = deviceRect.minY + 100 * scale
        let volUpRect = CGRect(
            x: deviceRect.minX - volWidth,
            y: volUpY,
            width: volWidth,
            height: volHeight
        )
        NSBezierPath(roundedRect: volUpRect, xRadius: 1.5 * scale, yRadius: 1.5 * scale).fill()

        // Volume down
        let volDownY = volUpY + volHeight + 10 * scale
        let volDownRect = CGRect(
            x: deviceRect.minX - volWidth,
            y: volDownY,
            width: volWidth,
            height: volHeight
        )
        NSBezierPath(roundedRect: volDownRect, xRadius: 1.5 * scale, yRadius: 1.5 * scale).fill()

        // Silent switch
        let silentY = deviceRect.minY + 75 * scale
        let silentRect = CGRect(
            x: deviceRect.minX - volWidth,
            y: silentY,
            width: volWidth,
            height: 18 * scale
        )
        NSBezierPath(roundedRect: silentRect, xRadius: 1.5 * scale, yRadius: 1.5 * scale).fill()

        ctx.restoreGState()
    }

    private func drawHomeButton(in ctx: CGContext, deviceRect: CGRect, scale: CGFloat) {
        ctx.saveGState()

        let buttonRadius: CGFloat = 22 * scale
        let centerX = deviceRect.midX
        let centerY = deviceRect.maxY - 30 * scale

        let buttonRect = CGRect(
            x: centerX - buttonRadius,
            y: centerY - buttonRadius,
            width: buttonRadius * 2,
            height: buttonRadius * 2
        )

        // Button circle
        NSColor(calibratedWhite: 0.10, alpha: 1.0).setFill()
        let buttonPath = NSBezierPath(ovalIn: buttonRect)
        buttonPath.fill()

        // Button border
        NSColor(calibratedWhite: 0.25, alpha: 1.0).setStroke()
        buttonPath.lineWidth = 1.5 * scale
        buttonPath.stroke()

        // Inner rounded square (Touch ID ring)
        let innerSize: CGFloat = 16 * scale
        let innerRect = CGRect(
            x: centerX - innerSize / 2,
            y: centerY - innerSize / 2,
            width: innerSize,
            height: innerSize
        )
        NSColor(calibratedWhite: 0.20, alpha: 1.0).setStroke()
        let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: 4 * scale, yRadius: 4 * scale)
        innerPath.lineWidth = 1.0 * scale
        innerPath.stroke()

        ctx.restoreGState()
    }

    private func drawNotch(in ctx: CGContext, screenRect: CGRect, scale: CGFloat) {
        ctx.saveGState()

        let notchWidth: CGFloat = 160 * scale
        let notchHeight: CGFloat = 34 * scale
        let notchCornerR: CGFloat = 20 * scale

        let notchX = screenRect.midX - notchWidth / 2
        let notchY = screenRect.minY

        let notchRect = CGRect(x: notchX, y: notchY, width: notchWidth, height: notchHeight)

        // Create notch path with bottom rounded corners
        let path = CGMutablePath()
        // Top left (square corner, flush with screen top)
        path.move(to: CGPoint(x: notchRect.minX - 8 * scale, y: notchRect.minY))
        // Curve into notch
        path.addQuadCurve(
            to: CGPoint(x: notchRect.minX, y: notchRect.minY + 8 * scale),
            control: CGPoint(x: notchRect.minX, y: notchRect.minY)
        )
        // Left side down
        path.addLine(to: CGPoint(x: notchRect.minX, y: notchRect.maxY - notchCornerR))
        // Bottom left corner
        path.addQuadCurve(
            to: CGPoint(x: notchRect.minX + notchCornerR, y: notchRect.maxY),
            control: CGPoint(x: notchRect.minX, y: notchRect.maxY)
        )
        // Bottom edge
        path.addLine(to: CGPoint(x: notchRect.maxX - notchCornerR, y: notchRect.maxY))
        // Bottom right corner
        path.addQuadCurve(
            to: CGPoint(x: notchRect.maxX, y: notchRect.maxY - notchCornerR),
            control: CGPoint(x: notchRect.maxX, y: notchRect.maxY)
        )
        // Right side up
        path.addLine(to: CGPoint(x: notchRect.maxX, y: notchRect.minY + 8 * scale))
        // Curve out of notch
        path.addQuadCurve(
            to: CGPoint(x: notchRect.maxX + 8 * scale, y: notchRect.minY),
            control: CGPoint(x: notchRect.maxX, y: notchRect.minY)
        )
        path.closeSubpath()

        ctx.addPath(path)
        ctx.setFillColor(NSColor(calibratedWhite: 0.12, alpha: 1.0).cgColor)
        ctx.fillPath()

        ctx.restoreGState()
    }

    private func drawDynamicIsland(in ctx: CGContext, screenRect: CGRect, scale: CGFloat) {
        ctx.saveGState()

        let islandWidth: CGFloat = 120 * scale
        let islandHeight: CGFloat = 36 * scale
        let islandY = screenRect.minY + 12 * scale
        let islandX = screenRect.midX - islandWidth / 2

        let islandRect = CGRect(x: islandX, y: islandY, width: islandWidth, height: islandHeight)
        let islandPath = NSBezierPath(roundedRect: islandRect, xRadius: islandHeight / 2, yRadius: islandHeight / 2)

        NSColor.black.setFill()
        islandPath.fill()

        ctx.restoreGState()
    }
}
