import AppKit
import AVFoundation

enum BackgroundTheme: String, CaseIterable {
    case dark = "Dark"
    case black = "Black"
    case light = "Light"
    case gray = "Gray"
    case sepia = "Sepia"
    case greenScreen = "Green Screen"

    var color: NSColor {
        switch self {
        case .black: return NSColor.black
        case .dark:  return NSColor(calibratedWhite: 0.15, alpha: 1.0)
        case .light: return NSColor(calibratedWhite: 0.95, alpha: 1.0)
        case .gray:  return NSColor(calibratedWhite: 0.55, alpha: 1.0)
        case .sepia: return NSColor(calibratedRed: 0.93, green: 0.89, blue: 0.82, alpha: 1.0)
        case .greenScreen: return NSColor(calibratedRed: 0.0, green: 0.82, blue: 0.09, alpha: 1.0)
        }
    }
}

class MainWindowController: NSWindowController, NSToolbarDelegate, DeviceCaptureDelegate {

    // MARK: - Properties

    private let captureManager = DeviceCaptureManager()
    private let bezelView = DeviceBezelView()
    private let contentContainerView = NSView()
    private var previewLayerContainer = NSView()

    private var selectedModel: DeviceModel = DeviceModelStore.defaultModel()
    private var selectedBackground: BackgroundTheme = .dark
    private var autoDetectEnabled = true

    private var devicePopUp: NSPopUpButton!
    private var modelPopUp: NSPopUpButton!
    private var backgroundPopUp: NSPopUpButton!
    private var recordButton: NSButton!

    private var noDeviceLabel: NSTextField!
    private var statusLabel: NSTextField!

    // Toolbar item identifiers
    private let toolbarDeviceIdentifier = NSToolbarItem.Identifier("device")
    private let toolbarModelIdentifier = NSToolbarItem.Identifier("model")
    private let toolbarBackgroundIdentifier = NSToolbarItem.Identifier("background")
    private let toolbarRecordIdentifier = NSToolbarItem.Identifier("record")
    private let toolbarHelpIdentifier = NSToolbarItem.Identifier("help")

    // MARK: - Init

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "RafScreen"
        window.center()
        window.minSize = NSSize(width: 300, height: 500)
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden

        self.init(window: window)
        setupUI()
        setupToolbar()

        captureManager.delegate = self
    }

    // MARK: - UI Setup

    private func setupUI() {
        guard let window = window else { return }

        contentContainerView.translatesAutoresizingMaskIntoConstraints = false
        contentContainerView.wantsLayer = true
        contentContainerView.layer?.backgroundColor = selectedBackground.color.cgColor
        window.contentView?.addSubview(contentContainerView)

        NSLayoutConstraint.activate([
            contentContainerView.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            contentContainerView.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            contentContainerView.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            contentContainerView.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor),
        ])

        bezelView.translatesAutoresizingMaskIntoConstraints = false
        bezelView.wantsLayer = true
        bezelView.deviceModel = selectedModel
        contentContainerView.addSubview(bezelView)

        NSLayoutConstraint.activate([
            bezelView.topAnchor.constraint(equalTo: contentContainerView.topAnchor, constant: 20),
            bezelView.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor, constant: 20),
            bezelView.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor, constant: -20),
            bezelView.bottomAnchor.constraint(equalTo: contentContainerView.bottomAnchor, constant: -20),
        ])

        previewLayerContainer.translatesAutoresizingMaskIntoConstraints = true
        previewLayerContainer.wantsLayer = true
        previewLayerContainer.layer?.backgroundColor = NSColor.black.cgColor
        previewLayerContainer.autoresizingMask = []
        bezelView.addSubview(previewLayerContainer)

        noDeviceLabel = NSTextField(labelWithString: "Connect an iOS device via USB")
        noDeviceLabel.translatesAutoresizingMaskIntoConstraints = false
        noDeviceLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        noDeviceLabel.textColor = NSColor(calibratedWhite: 0.5, alpha: 1.0)
        noDeviceLabel.alignment = .center
        previewLayerContainer.addSubview(noDeviceLabel)

        NSLayoutConstraint.activate([
            noDeviceLabel.centerXAnchor.constraint(equalTo: previewLayerContainer.centerXAnchor),
            noDeviceLabel.centerYAnchor.constraint(equalTo: previewLayerContainer.centerYAnchor),
        ])

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = NSColor.secondaryLabelColor
        statusLabel.alignment = .center
        contentContainerView.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: contentContainerView.centerXAnchor),
            statusLabel.bottomAnchor.constraint(equalTo: contentContainerView.bottomAnchor, constant: -6),
        ])

        DispatchQueue.main.async { [weak self] in
            self?.updatePreviewLayout()
        }
    }

    private func setupToolbar() {
        guard let window = window else { return }

        let toolbar = NSToolbar(identifier: "RafScreenToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar
    }

    // MARK: - Layout

    private func updatePreviewLayout() {
        let screenFrame = bezelView.screenContentFrame
        previewLayerContainer.frame = screenFrame

        let totalW = selectedModel.screenWidth + selectedModel.bezelWidth * 2
        let totalH = selectedModel.screenHeight + selectedModel.bezelWidth * 2 +
            (selectedModel.hasHomeButton ? 100 : 0)
        let scale = min(
            bezelView.bounds.width / totalW,
            bezelView.bounds.height / totalH,
            1.0
        )
        let cornerR = selectedModel.cornerRadius * max(scale, 0.01)
        previewLayerContainer.layer?.cornerRadius = cornerR
        previewLayerContainer.layer?.masksToBounds = true

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let layer = captureManager.previewLayer {
            layer.frame = previewLayerContainer.bounds
        }
        CATransaction.commit()
    }

    private func selectModelInPopUp(_ model: DeviceModel) {
        guard let popup = modelPopUp else { return }
        if let idx = popup.menu?.items.firstIndex(where: {
            ($0.representedObject as? String) == model.name
        }) {
            popup.selectItem(at: idx)
        }
    }

    // MARK: - Toolbar Delegate

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case toolbarModelIdentifier:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            modelPopUp = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 180, height: 24), pullsDown: false)
            modelPopUp.font = NSFont.systemFont(ofSize: 13)

            // Auto-detect option
            let autoItem = NSMenuItem(title: "Auto-Detect", action: #selector(autoDetectSelected), keyEquivalent: "")
            autoItem.target = self
            modelPopUp.menu?.addItem(autoItem)

            modelPopUp.menu?.addItem(NSMenuItem.separator())

            let iphoneHeader = NSMenuItem(title: "iPhones", action: nil, keyEquivalent: "")
            iphoneHeader.isEnabled = false
            iphoneHeader.attributedTitle = NSAttributedString(
                string: "iPhones",
                attributes: [.font: NSFont.boldSystemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
            )
            modelPopUp.menu?.addItem(iphoneHeader)

            for model in DeviceModelStore.iPhones {
                let menuItem = NSMenuItem(title: model.name, action: #selector(modelSelected(_:)), keyEquivalent: "")
                menuItem.target = self
                menuItem.representedObject = model.name
                menuItem.title = " \u{25AE}  \(model.name)"
                modelPopUp.menu?.addItem(menuItem)
            }

            modelPopUp.menu?.addItem(NSMenuItem.separator())
            let ipadHeader = NSMenuItem(title: "iPads", action: nil, keyEquivalent: "")
            ipadHeader.isEnabled = false
            ipadHeader.attributedTitle = NSAttributedString(
                string: "iPads",
                attributes: [.font: NSFont.boldSystemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
            )
            modelPopUp.menu?.addItem(ipadHeader)

            for model in DeviceModelStore.iPads {
                let menuItem = NSMenuItem(title: model.name, action: #selector(modelSelected(_:)), keyEquivalent: "")
                menuItem.target = self
                menuItem.representedObject = model.name
                menuItem.title = " \u{25AE}  \(model.name)"
                modelPopUp.menu?.addItem(menuItem)
            }

            // Select Auto-Detect by default
            modelPopUp.selectItem(at: 0)

            item.view = modelPopUp
            item.label = "Device Model"
            item.minSize = NSSize(width: 180, height: 24)
            item.maxSize = NSSize(width: 220, height: 24)
            return item

        case toolbarBackgroundIdentifier:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            backgroundPopUp = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 140, height: 24), pullsDown: false)
            backgroundPopUp.font = NSFont.systemFont(ofSize: 13)

            for theme in BackgroundTheme.allCases {
                let menuItem = NSMenuItem(title: theme.rawValue, action: #selector(backgroundSelected(_:)), keyEquivalent: "")
                menuItem.target = self
                menuItem.representedObject = theme.rawValue

                let swatch = NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
                    theme.color.setFill()
                    let path = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 2, yRadius: 2)
                    path.fill()
                    NSColor.separatorColor.setStroke()
                    path.stroke()
                    return true
                }
                menuItem.image = swatch
                backgroundPopUp.menu?.addItem(menuItem)
            }

            backgroundPopUp.selectItem(at: 0)

            item.view = backgroundPopUp
            item.label = "Background Color"
            item.minSize = NSSize(width: 100, height: 24)
            item.maxSize = NSSize(width: 160, height: 24)
            return item

        case toolbarRecordIdentifier:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            recordButton = NSButton(frame: NSRect(x: 0, y: 0, width: 28, height: 24))
            recordButton.bezelStyle = .texturedRounded
            recordButton.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Record")
            recordButton.target = self
            recordButton.action = #selector(toggleRecording)
            recordButton.toolTip = "Start/Stop Recording (Cmd+R)"
            item.view = recordButton
            item.label = "Record"
            return item

        case toolbarHelpIdentifier:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            let button = NSButton(title: "Help", target: self, action: #selector(showHelp))
            button.bezelStyle = .texturedRounded
            button.font = NSFont.systemFont(ofSize: 13)
            item.view = button
            item.label = "Help"
            return item

        case toolbarDeviceIdentifier:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            devicePopUp = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 200, height: 24), pullsDown: false)
            devicePopUp.font = NSFont.systemFont(ofSize: 13)
            updateDevicePopUp()
            item.view = devicePopUp
            item.label = "Connected Device"
            item.minSize = NSSize(width: 160, height: 24)
            item.maxSize = NSSize(width: 250, height: 24)
            return item

        default:
            return nil
        }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            toolbarDeviceIdentifier,
            .flexibleSpace,
            toolbarModelIdentifier,
            toolbarBackgroundIdentifier,
            toolbarRecordIdentifier,
            toolbarHelpIdentifier,
        ]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return toolbarDefaultItemIdentifiers(toolbar)
    }

    // MARK: - Actions

    @objc func autoDetectSelected() {
        autoDetectEnabled = true
        bezelView.hideBezel = false
        captureManager.refreshDevices()
    }

    @objc func modelSelected(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String,
              let model = DeviceModelStore.model(named: name) else { return }
        autoDetectEnabled = false
        applyModel(model)
    }

    private func applyModel(_ model: DeviceModel) {
        selectedModel = model
        bezelView.deviceModel = model
        DispatchQueue.main.async { [weak self] in
            self?.updatePreviewLayout()
        }
    }

    @objc func backgroundSelected(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String,
              let theme = BackgroundTheme(rawValue: name) else { return }
        selectedBackground = theme
        contentContainerView.layer?.backgroundColor = theme.color.cgColor
    }

    @objc func showHelp() {
        let alert = NSAlert()
        alert.messageText = "RafScreen Help"
        alert.informativeText = """
        1. Connect your iPhone or iPad via USB cable
        2. Trust the computer on your device if prompted
        3. The device screen will appear automatically

        Use the toolbar to:
        - Select your connected device
        - Choose a device frame (or Auto-Detect)
        - Change the background color

        Keyboard shortcuts:
        - Cmd+S: Save screenshot to Desktop
        - Cmd+R: Start/Stop recording
        - Cmd+0: Actual size
        - Cmd++: Zoom in
        - Cmd+-: Zoom out
        """
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc func actualSize() {
        guard let window = window else { return }
        let width = selectedModel.screenWidth + selectedModel.bezelWidth * 2 + 40
        let topExtra: CGFloat = selectedModel.hasHomeButton ? 40 : 0
        let bottomExtra: CGFloat = selectedModel.hasHomeButton ? 60 : 0
        let height = selectedModel.screenHeight + selectedModel.bezelWidth * 2 + topExtra + bottomExtra + 40 + 52
        window.setContentSize(NSSize(width: width, height: height))
        DispatchQueue.main.async { [weak self] in
            self?.updatePreviewLayout()
        }
    }

    @objc func zoomIn() {
        guard let window = window else { return }
        let size = window.contentView!.bounds.size
        window.setContentSize(NSSize(width: size.width * 1.15, height: size.height * 1.15))
        DispatchQueue.main.async { [weak self] in
            self?.updatePreviewLayout()
        }
    }

    @objc func zoomOut() {
        guard let window = window else { return }
        let size = window.contentView!.bounds.size
        window.setContentSize(NSSize(width: size.width / 1.15, height: size.height / 1.15))
        DispatchQueue.main.async { [weak self] in
            self?.updatePreviewLayout()
        }
    }

    @objc func deviceSelected(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? AVCaptureDevice else { return }
        captureManager.startCapture(from: device)
    }

    @objc func takeScreenshot() {
        guard let screenshot = captureManager.captureScreenshot() else {
            NSSound.beep()
            return
        }

        // Render the full window (bezel + screen) as an image
        let windowImage = captureWindowImage(screenImage: screenshot)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "RafScreen_\(dateFormatter.string(from: Date())).png"
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let fileURL = desktopURL.appendingPathComponent(filename)

        if let tiffData = windowImage.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            try? pngData.write(to: fileURL)
            statusLabel?.stringValue = "Screenshot saved to Desktop"

            // Reset status after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if let device = self?.captureManager.activeDevice {
                    self?.statusLabel?.stringValue = "Mirroring: \(device.localizedName)"
                }
            }
        }
    }

    private func captureWindowImage(screenImage: NSImage) -> NSImage {
        // Capture the bezel view with the screen content composited
        let bezelBounds = bezelView.bounds
        let image = NSImage(size: bezelBounds.size)
        image.lockFocus()

        // Draw background
        selectedBackground.color.setFill()
        NSBezierPath.fill(bezelBounds)

        // Draw bezel
        if let ctx = NSGraphicsContext.current {
            ctx.saveGraphicsState()
            bezelView.draw(bezelBounds)
            ctx.restoreGraphicsState()
        }

        // Draw screen content
        let screenFrame = bezelView.screenContentFrame
        screenImage.draw(in: screenFrame, from: .zero, operation: .sourceOver, fraction: 1.0)

        image.unlockFocus()
        return image
    }

    @objc func toggleRecording() {
        if captureManager.isRecording {
            captureManager.stopRecording { [weak self] url in
                guard let self = self else { return }
                self.recordButton?.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Record")
                self.recordButton?.contentTintColor = nil
                if let url = url {
                    self.statusLabel?.stringValue = "Recording saved: \(url.lastPathComponent)"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                        if let device = self?.captureManager.activeDevice {
                            self?.statusLabel?.stringValue = "Mirroring: \(device.localizedName)"
                        }
                    }
                }
            }
        } else {
            captureManager.startRecording()
            recordButton?.image = NSImage(systemSymbolName: "stop.circle.fill", accessibilityDescription: "Stop Recording")
            recordButton?.contentTintColor = .systemRed
            statusLabel?.stringValue = "Recording..."
        }
    }

    // MARK: - Device Pop-Up

    private func updateDevicePopUp() {
        guard let popup = devicePopUp else { return }
        popup.removeAllItems()

        let iosDevices = captureManager.connectedDevices
        let allDevices = captureManager.allDetectedDevices

        if iosDevices.isEmpty && allDevices.isEmpty {
            let item = NSMenuItem(title: "No Device Connected", action: nil, keyEquivalent: "")
            item.isEnabled = false
            popup.menu?.addItem(item)
        } else {
            if !iosDevices.isEmpty {
                for device in iosDevices {
                    let item = NSMenuItem(title: device.localizedName, action: #selector(deviceSelected(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = device
                    popup.menu?.addItem(item)
                }
            }

            let otherDevices = allDevices.filter { dev in
                !iosDevices.contains(where: { $0.uniqueID == dev.uniqueID })
            }
            if !otherDevices.isEmpty {
                if !iosDevices.isEmpty {
                    popup.menu?.addItem(NSMenuItem.separator())
                }
                let header = NSMenuItem(title: "Other Cameras", action: nil, keyEquivalent: "")
                header.isEnabled = false
                header.attributedTitle = NSAttributedString(
                    string: "Other Cameras",
                    attributes: [.font: NSFont.boldSystemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
                )
                popup.menu?.addItem(header)
                for device in otherDevices {
                    let item = NSMenuItem(title: device.localizedName, action: #selector(deviceSelected(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = device
                    popup.menu?.addItem(item)
                }
            }

            if iosDevices.isEmpty {
                popup.menu?.insertItem(NSMenuItem.separator(), at: 0)
                let hint = NSMenuItem(title: "No iOS device detected", action: nil, keyEquivalent: "")
                hint.isEnabled = false
                popup.menu?.insertItem(hint, at: 0)
            }
        }
    }

    // MARK: - DeviceCaptureDelegate

    func captureManager(_ manager: DeviceCaptureManager, didDetectDevices devices: [AVCaptureDevice]) {
        updateDevicePopUp()

        if devices.isEmpty {
            noDeviceLabel?.isHidden = false
            noDeviceLabel?.stringValue = "Connect an iOS device via USB"
            statusLabel?.stringValue = ""
            captureManager.previewLayer?.removeFromSuperlayer()
        } else {
            noDeviceLabel?.stringValue = "Starting capture..."
            statusLabel?.stringValue = "Device detected: \(devices.first?.localizedName ?? "")"

            if manager.activeDevice == nil {
                manager.startCaptureFromFirstAvailableDevice()
            }
        }
    }

    func captureManager(_ manager: DeviceCaptureManager, didStartSessionFor device: AVCaptureDevice) {
        noDeviceLabel?.isHidden = true
        statusLabel?.stringValue = "Mirroring: \(device.localizedName)"

        bezelView.layoutSubtreeIfNeeded()

        let screenFrame = bezelView.screenContentFrame
        previewLayerContainer.frame = screenFrame

        if let layer = manager.previewLayer {
            layer.frame = previewLayerContainer.bounds
            layer.videoGravity = .resizeAspectFill
            previewLayerContainer.layer?.addSublayer(layer)
        }

        DispatchQueue.main.async { [weak self] in
            self?.updatePreviewLayout()
        }
    }

    func captureManager(_ manager: DeviceCaptureManager, didStopSession reason: String) {
        noDeviceLabel?.isHidden = false
        noDeviceLabel?.stringValue = reason
        statusLabel?.stringValue = ""
    }

    func captureManager(_ manager: DeviceCaptureManager, didDetectResolution width: Int, height: Int) {
        guard autoDetectEnabled else { return }

        if let model = DeviceModelStore.modelForResolution(width: width, height: height) {
            applyModel(model)
            selectModelInPopUp(model)
            // Update the popup to show the detected model name instead of Auto-Detect
            if let popup = modelPopUp, let idx = popup.menu?.items.firstIndex(where: {
                ($0.representedObject as? String) == model.name
            }) {
                popup.selectItem(at: idx)
            }
        }
    }
}

// MARK: - Window Resize Handling

extension MainWindowController: NSWindowDelegate {
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.delegate = self
    }

    func windowDidResize(_ notification: Notification) {
        updatePreviewLayout()
    }
}
