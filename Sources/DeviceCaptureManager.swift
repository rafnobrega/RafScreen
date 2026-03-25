import AVFoundation
import CoreMediaIO
import AppKit

protocol DeviceCaptureDelegate: AnyObject {
    func captureManager(_ manager: DeviceCaptureManager, didDetectDevices devices: [AVCaptureDevice])
    func captureManager(_ manager: DeviceCaptureManager, didStartSessionFor device: AVCaptureDevice)
    func captureManager(_ manager: DeviceCaptureManager, didStopSession reason: String)
    func captureManager(_ manager: DeviceCaptureManager, didDetectResolution width: Int, height: Int)
}

class DeviceCaptureManager: NSObject {
    weak var delegate: DeviceCaptureDelegate?

    private(set) var captureSession: AVCaptureSession?
    private(set) var displayLayer: CALayer?
    private(set) var connectedDevices: [AVCaptureDevice] = []
    private(set) var allDetectedDevices: [AVCaptureDevice] = []
    private(set) var activeDevice: AVCaptureDevice?

    private var muxedDiscovery: AVCaptureDevice.DiscoverySession?
    private var allDiscovery: AVCaptureDevice.DiscoverySession?
    private var muxedObservation: NSKeyValueObservation?
    private var allObservation: NSKeyValueObservation?

    // For frame capture (screenshots) and recording
    private var videoOutput: AVCaptureVideoDataOutput?
    private var latestSampleBuffer: CMSampleBuffer?
    private let bufferQueue = DispatchQueue(label: "com.rnobrega.rafscreen.buffer")
    private var lastReportedWidth: Int = 0
    private var lastReportedHeight: Int = 0
    private let ciContext = CIContext(options: [
        .useSoftwareRenderer: false,
        .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
    ])

    // Display target size (set by MainWindowController)
    var displayTargetSize: CGSize = .zero
    var displayBackingScale: CGFloat = 2.0

    // Recording
    private(set) var isRecording = false
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var assetWriterAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var recordingStartTime: CMTime?
    private(set) var recordingURL: URL?

    override init() {
        super.init()
        enableIOSDeviceDiscovery()
        setupDiscoverySessions()
    }

    // MARK: - CoreMediaIO Setup

    private func enableIOSDeviceDiscovery() {
        var property = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        var allow: UInt32 = 1
        CMIOObjectSetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject),
            &property, 0, nil,
            UInt32(MemoryLayout<UInt32>.size),
            &allow
        )
    }

    // MARK: - Device Discovery

    static func isIOSDevice(_ device: AVCaptureDevice) -> Bool {
        if device.modelID.lowercased().contains("ios device") {
            return true
        }
        if device.hasMediaType(.muxed) {
            return true
        }
        return false
    }

    private func setupDiscoverySessions() {
        muxedDiscovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.externalUnknown],
            mediaType: .muxed,
            position: .unspecified
        )

        allDiscovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.externalUnknown],
            mediaType: nil,
            position: .unspecified
        )

        muxedObservation = muxedDiscovery?.observe(\.devices, options: [.new, .initial]) { [weak self] _, _ in
            self?.mergeAndNotifyDevices()
        }

        allObservation = allDiscovery?.observe(\.devices, options: [.new, .initial]) { [weak self] _, _ in
            self?.mergeAndNotifyDevices()
        }
    }

    private func mergeAndNotifyDevices() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            var seen = Set<String>()
            var merged: [AVCaptureDevice] = []

            let muxedDevices = self.muxedDiscovery?.devices ?? []
            let allDevices = self.allDiscovery?.devices ?? []

            for device in muxedDevices + allDevices {
                if seen.insert(device.uniqueID).inserted {
                    merged.append(device)
                }
            }

            self.allDetectedDevices = merged
            let iosDevices = merged.filter { DeviceCaptureManager.isIOSDevice($0) }

            let previousIDs = Set(self.connectedDevices.map { $0.uniqueID })
            let currentIDs = Set(iosDevices.map { $0.uniqueID })

            self.connectedDevices = iosDevices

            if let active = self.activeDevice, !currentIDs.contains(active.uniqueID) {
                self.stopCapture()
            }

            let newDeviceIDs = currentIDs.subtracting(previousIDs)
            if !newDeviceIDs.isEmpty, self.activeDevice == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.startCaptureFromFirstAvailableDevice()
                }
            }

            self.delegate?.captureManager(self, didDetectDevices: iosDevices)
        }
    }

    func refreshDevices() {
        mergeAndNotifyDevices()
    }

    // MARK: - Capture Session

    func startCapture(from device: AVCaptureDevice) {
        stopCapture()
        lastReportedWidth = 0
        lastReportedHeight = 0

        let session = AVCaptureSession()

        do {
            let input = try AVCaptureDeviceInput(device: device)

            session.beginConfiguration()
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                session.commitConfiguration()
                delegate?.captureManager(self, didStopSession: "Cannot add device as input")
                return
            }

            // Select the highest resolution format for best scaling quality
            if let bestFormat = device.formats
                .filter({ CMFormatDescriptionGetMediaType($0.formatDescription) == kCMMediaType_Video })
                .max(by: { fmt1, fmt2 in
                    let d1 = CMVideoFormatDescriptionGetDimensions(fmt1.formatDescription)
                    let d2 = CMVideoFormatDescriptionGetDimensions(fmt2.formatDescription)
                    return (Int(d1.width) * Int(d1.height)) < (Int(d2.width) * Int(d2.height))
                }) {
                try device.lockForConfiguration()
                device.activeFormat = bestFormat
                device.unlockForConfiguration()
                let dims = CMVideoFormatDescriptionGetDimensions(bestFormat.formatDescription)
                NSLog("RafScreen: Selected format %dx%d", dims.width, dims.height)
            } else {
                session.sessionPreset = .high
            }

            session.commitConfiguration()
        } catch {
            delegate?.captureManager(self, didStopSession: "Error: \(error.localizedDescription)")
            return
        }

        // Video data output for frame rendering, screenshots, and recording
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: bufferQueue)
        output.alwaysDiscardsLateVideoFrames = true

        if session.canAddOutput(output) {
            session.addOutput(output)
            self.videoOutput = output
        }

        // Manual CALayer for Lanczos-scaled frame rendering
        let layer = CALayer()
        layer.contentsGravity = .resizeAspect
        layer.backgroundColor = NSColor.black.cgColor

        self.captureSession = session
        self.displayLayer = layer
        self.activeDevice = device

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            DispatchQueue.main.async {
                self.delegate?.captureManager(self, didStartSessionFor: device)
            }
        }
    }

    func stopCapture() {
        if isRecording {
            stopRecording(completion: nil)
        }
        captureSession?.stopRunning()
        displayLayer?.removeFromSuperlayer()
        captureSession = nil
        displayLayer = nil
        videoOutput = nil
        activeDevice = nil
        latestSampleBuffer = nil
    }

    func startCaptureFromFirstAvailableDevice() {
        guard let device = connectedDevices.first else { return }
        startCapture(from: device)
    }

    // MARK: - Screenshot

    func captureScreenshot() -> NSImage? {
        guard let sampleBuffer = latestSampleBuffer,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        guard let cgImage = ciContext.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: width, height: height)) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }

    // MARK: - Recording

    func startRecording() {
        guard !isRecording, captureSession?.isRunning == true else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "RafScreen_\(dateFormatter.string(from: Date())).mov"

        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let fileURL = desktopURL.appendingPathComponent(filename)

        var width = 1170
        var height = 2532
        if let buffer = latestSampleBuffer, let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) {
            width = CVPixelBufferGetWidth(pixelBuffer)
            height = CVPixelBufferGetHeight(pixelBuffer)
        }

        do {
            let writer = try AVAssetWriter(outputURL: fileURL, fileType: .mov)

            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
            ]

            let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            writerInput.expectsMediaDataInRealTime = true

            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: writerInput,
                sourcePixelBufferAttributes: nil
            )

            if writer.canAdd(writerInput) {
                writer.add(writerInput)
            }

            writer.startWriting()
            writer.startSession(atSourceTime: .zero)

            self.assetWriter = writer
            self.assetWriterInput = writerInput
            self.assetWriterAdaptor = adaptor
            self.recordingStartTime = nil
            self.recordingURL = fileURL
            self.isRecording = true
        } catch {
            NSLog("RafScreen: Failed to start recording: %@", error.localizedDescription)
        }
    }

    func stopRecording(completion: ((URL?) -> Void)?) {
        guard isRecording else {
            completion?(nil)
            return
        }

        isRecording = false
        let url = recordingURL

        assetWriterInput?.markAsFinished()
        assetWriter?.finishWriting { [weak self] in
            DispatchQueue.main.async {
                completion?(url)
                self?.assetWriter = nil
                self?.assetWriterInput = nil
                self?.assetWriterAdaptor = nil
                self?.recordingStartTime = nil
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension DeviceCaptureManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        latestSampleBuffer = sampleBuffer

        // Report resolution on first frame and on orientation changes
        if let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) {
            let dims = CMVideoFormatDescriptionGetDimensions(formatDesc)
            let w = Int(dims.width)
            let h = Int(dims.height)
            if w != lastReportedWidth || h != lastReportedHeight {
                lastReportedWidth = w
                lastReportedHeight = h
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.captureManager(self, didDetectResolution: w, height: h)
                }
            }
        }

        // Render frame to display layer using Lanczos scaling
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
           displayTargetSize.width > 0, displayTargetSize.height > 0 {

            let sourceWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
            let sourceHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))

            // Calculate target size in backing pixels, maintaining aspect ratio
            let targetW = displayTargetSize.width * displayBackingScale
            let targetH = displayTargetSize.height * displayBackingScale
            let scaleToFit = min(targetW / sourceWidth, targetH / sourceHeight)

            var ciImage = CIImage(cvPixelBuffer: pixelBuffer)

            // Apply Lanczos scale transform for high-quality resampling
            ciImage = ciImage.applyingFilter("CILanczosScaleTransform", parameters: [
                "inputScale": scaleToFit,
                "inputAspectRatio": 1.0
            ])

            let outputRect = ciImage.extent
            if let cgImage = ciContext.createCGImage(ciImage, from: outputRect) {
                DispatchQueue.main.async { [weak self] in
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    self?.displayLayer?.contents = cgImage
                    CATransaction.commit()
                }
            }
        }

        // Write to recording if active
        if isRecording, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

            if recordingStartTime == nil {
                recordingStartTime = timestamp
            }

            let relativeTime = CMTimeSubtract(timestamp, recordingStartTime!)

            if let input = assetWriterInput, input.isReadyForMoreMediaData {
                assetWriterAdaptor?.append(pixelBuffer, withPresentationTime: relativeTime)
            }
        }
    }
}
