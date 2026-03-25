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

    var isLandscape: Bool = false {
        didSet { needsDisplay = true; invalidateIntrinsicContentSize() }
    }

    // Effective dimensions accounting for orientation
    private var effectiveScreenWidth: CGFloat { isLandscape ? deviceModel.screenHeight : deviceModel.screenWidth }
    private var effectiveScreenHeight: CGFloat { isLandscape ? deviceModel.screenWidth : deviceModel.screenHeight }

    // The scale factor to fit the device in the view
    private var renderScale: CGFloat {
        let availableWidth = bounds.width
        let availableHeight = bounds.height
        let totalDeviceWidth = effectiveScreenWidth + deviceModel.bezelWidth * 2 +
            (isLandscape && deviceModel.hasHomeButton ? 100 : 0)
        let totalDeviceHeight = effectiveScreenHeight + deviceModel.bezelWidth * 2 +
            (!isLandscape && deviceModel.hasHomeButton ? 100 : 0)
        let scaleX = availableWidth / totalDeviceWidth
        let scaleY = availableHeight / totalDeviceHeight
        return min(scaleX, scaleY, 1.0)
    }

    /// Returns the frame where the screen content should be placed (in this view's coordinate space)
    var screenContentFrame: CGRect {
        if hideBezel {
            let ratio = isLandscape ? (1.0 / deviceModel.aspectRatio) : deviceModel.aspectRatio
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
        let screenW = effectiveScreenWidth * scale
        let screenH = effectiveScreenHeight * scale
        let bezel = deviceModel.bezelWidth * scale

        if isLandscape {
            let leftExtra: CGFloat = deviceModel.hasHomeButton ? 40 * scale : 0
            let rightExtra: CGFloat = deviceModel.hasHomeButton ? 60 * scale : 0
            let totalWidth = screenW + bezel * 2 + leftExtra + rightExtra
            let totalHeight = screenH + bezel * 2

            let originX = (bounds.width - totalWidth) / 2 + bezel + leftExtra
            let originY = (bounds.height - totalHeight) / 2 + bezel
            return CGRect(x: originX, y: originY, width: screenW, height: screenH)
        } else {
            let totalWidth = screenW + bezel * 2
            let topExtra: CGFloat = deviceModel.hasHomeButton ? 40 * scale : 0
            let bottomExtra: CGFloat = deviceModel.hasHomeButton ? 60 * scale : 0
            let totalHeight = screenH + bezel * 2 + topExtra + bottomExtra

            let originX = (bounds.width - totalWidth) / 2 + bezel
            let originY = (bounds.height - totalHeight) / 2 + bezel + topExtra
            return CGRect(x: originX, y: originY, width: screenW, height: screenH)
        }
    }

    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize {
        let sw = effectiveScreenWidth
        let sh = effectiveScreenHeight
        let totalWidth: CGFloat
        let totalHeight: CGFloat
        if isLandscape {
            let leftExtra: CGFloat = deviceModel.hasHomeButton ? 40 : 0
            let rightExtra: CGFloat = deviceModel.hasHomeButton ? 60 : 0
            totalWidth = sw + deviceModel.bezelWidth * 2 + leftExtra + rightExtra
            totalHeight = sh + deviceModel.bezelWidth * 2
        } else {
            let topExtra: CGFloat = deviceModel.hasHomeButton ? 40 : 0
            let bottomExtra: CGFloat = deviceModel.hasHomeButton ? 60 : 0
            totalWidth = sw + deviceModel.bezelWidth * 2
            totalHeight = sh + deviceModel.bezelWidth * 2 + topExtra + bottomExtra
        }
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
        let screenW = effectiveScreenWidth * scale
        let screenH = effectiveScreenHeight * scale
        let bezel = deviceModel.bezelWidth * scale
        let cornerR = deviceModel.cornerRadius * scale

        let totalW: CGFloat
        let totalH: CGFloat

        if isLandscape {
            let leftExtra: CGFloat = deviceModel.hasHomeButton ? 40 * scale : 0
            let rightExtra: CGFloat = deviceModel.hasHomeButton ? 60 * scale : 0
            totalW = screenW + bezel * 2 + leftExtra + rightExtra
            totalH = screenH + bezel * 2
        } else {
            let topExtra: CGFloat = deviceModel.hasHomeButton ? 40 * scale : 0
            let bottomExtra: CGFloat = deviceModel.hasHomeButton ? 60 * scale : 0
            totalW = screenW + bezel * 2
            totalH = screenH + bezel * 2 + topExtra + bottomExtra
        }

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

        // Side buttons
        if deviceModel.category == .iPhone {
            if isLandscape {
                drawSideButtonsLandscape(in: ctx, deviceRect: deviceRect, scale: scale)
            } else {
                drawSideButtons(in: ctx, deviceRect: deviceRect, scale: scale)
            }
        }

        // Home button for older models
        if deviceModel.hasHomeButton {
            if isLandscape {
                drawHomeButtonLandscape(in: ctx, deviceRect: deviceRect, scale: scale)
            } else {
                drawHomeButton(in: ctx, deviceRect: deviceRect, scale: scale)
            }
        }

        // Notch or Dynamic Island
        switch deviceModel.notchStyle {
        case .notch:
            if isLandscape {
                drawNotchLandscape(in: ctx, screenRect: screenRect, scale: scale)
            } else {
                drawNotch(in: ctx, screenRect: screenRect, scale: scale)
            }
        case .dynamicIsland:
            if isLandscape {
                drawDynamicIslandLandscape(in: ctx, screenRect: screenRect, scale: scale)
            } else {
                drawDynamicIsland(in: ctx, screenRect: screenRect, scale: scale)
            }
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

    // MARK: - Landscape Drawing Helpers

    private func drawSideButtonsLandscape(in ctx: CGContext, deviceRect: CGRect, scale: CGFloat) {
        ctx.saveGState()
        let buttonColor = NSColor(calibratedWhite: 0.18, alpha: 1.0)
        buttonColor.setFill()

        // Power button (bottom in landscape = right side in portrait)
        let powerHeight: CGFloat = 3 * scale
        let powerWidth: CGFloat = 50 * scale
        let powerX = deviceRect.minX + 120 * scale
        let powerRect = CGRect(x: powerX, y: deviceRect.maxY, width: powerWidth, height: powerHeight)
        NSBezierPath(roundedRect: powerRect, xRadius: 1.5 * scale, yRadius: 1.5 * scale).fill()

        // Volume buttons (top in landscape = left side in portrait)
        let volHeight: CGFloat = 3 * scale
        let volWidth: CGFloat = 35 * scale

        let volUpX = deviceRect.maxX - 100 * scale - volWidth
        let volUpRect = CGRect(x: volUpX, y: deviceRect.minY - volHeight, width: volWidth, height: volHeight)
        NSBezierPath(roundedRect: volUpRect, xRadius: 1.5 * scale, yRadius: 1.5 * scale).fill()

        let volDownX = volUpX - volWidth - 10 * scale
        let volDownRect = CGRect(x: volDownX, y: deviceRect.minY - volHeight, width: volWidth, height: volHeight)
        NSBezierPath(roundedRect: volDownRect, xRadius: 1.5 * scale, yRadius: 1.5 * scale).fill()

        // Silent switch
        let silentX = deviceRect.maxX - 75 * scale - 18 * scale
        let silentRect = CGRect(x: silentX, y: deviceRect.minY - volHeight, width: 18 * scale, height: volHeight)
        NSBezierPath(roundedRect: silentRect, xRadius: 1.5 * scale, yRadius: 1.5 * scale).fill()

        ctx.restoreGState()
    }

    private func drawHomeButtonLandscape(in ctx: CGContext, deviceRect: CGRect, scale: CGFloat) {
        ctx.saveGState()

        let buttonRadius: CGFloat = 22 * scale
        let centerX = deviceRect.maxX - 30 * scale
        let centerY = deviceRect.midY

        let buttonRect = CGRect(
            x: centerX - buttonRadius,
            y: centerY - buttonRadius,
            width: buttonRadius * 2,
            height: buttonRadius * 2
        )

        NSColor(calibratedWhite: 0.10, alpha: 1.0).setFill()
        let buttonPath = NSBezierPath(ovalIn: buttonRect)
        buttonPath.fill()

        NSColor(calibratedWhite: 0.25, alpha: 1.0).setStroke()
        buttonPath.lineWidth = 1.5 * scale
        buttonPath.stroke()

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

    private func drawNotchLandscape(in ctx: CGContext, screenRect: CGRect, scale: CGFloat) {
        ctx.saveGState()

        // Notch on the left side (top in portrait → left in landscape)
        let notchHeight: CGFloat = 160 * scale
        let notchWidth: CGFloat = 34 * scale
        let notchCornerR: CGFloat = 20 * scale

        let notchX = screenRect.minX
        let notchY = screenRect.midY - notchHeight / 2

        let notchRect = CGRect(x: notchX, y: notchY, width: notchWidth, height: notchHeight)

        let path = CGMutablePath()
        path.move(to: CGPoint(x: notchRect.minX, y: notchRect.minY - 8 * scale))
        path.addQuadCurve(
            to: CGPoint(x: notchRect.minX + 8 * scale, y: notchRect.minY),
            control: CGPoint(x: notchRect.minX, y: notchRect.minY)
        )
        path.addLine(to: CGPoint(x: notchRect.maxX - notchCornerR, y: notchRect.minY))
        path.addQuadCurve(
            to: CGPoint(x: notchRect.maxX, y: notchRect.minY + notchCornerR),
            control: CGPoint(x: notchRect.maxX, y: notchRect.minY)
        )
        path.addLine(to: CGPoint(x: notchRect.maxX, y: notchRect.maxY - notchCornerR))
        path.addQuadCurve(
            to: CGPoint(x: notchRect.maxX - notchCornerR, y: notchRect.maxY),
            control: CGPoint(x: notchRect.maxX, y: notchRect.maxY)
        )
        path.addLine(to: CGPoint(x: notchRect.minX + 8 * scale, y: notchRect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: notchRect.minX, y: notchRect.maxY + 8 * scale),
            control: CGPoint(x: notchRect.minX, y: notchRect.maxY)
        )
        path.closeSubpath()

        ctx.addPath(path)
        ctx.setFillColor(NSColor(calibratedWhite: 0.12, alpha: 1.0).cgColor)
        ctx.fillPath()

        ctx.restoreGState()
    }

    private func drawDynamicIslandLandscape(in ctx: CGContext, screenRect: CGRect, scale: CGFloat) {
        ctx.saveGState()

        let islandHeight: CGFloat = 120 * scale
        let islandWidth: CGFloat = 36 * scale
        let islandX = screenRect.minX + 12 * scale
        let islandY = screenRect.midY - islandHeight / 2

        let islandRect = CGRect(x: islandX, y: islandY, width: islandWidth, height: islandHeight)
        let islandPath = NSBezierPath(roundedRect: islandRect, xRadius: islandWidth / 2, yRadius: islandWidth / 2)

        NSColor.black.setFill()
        islandPath.fill()

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
