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
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?
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
    private var hasReportedResolution = false

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

            // Detect device changes for hot-swap support
            let previousIDs = Set(self.connectedDevices.map { $0.uniqueID })
            let currentIDs = Set(iosDevices.map { $0.uniqueID })

            self.connectedDevices = iosDevices

            // If active device was disconnected, stop capture
            if let active = self.activeDevice, !currentIDs.contains(active.uniqueID) {
                self.stopCapture()
            }

            // If a new device appeared (hot-swap), auto-start capture
            let newDeviceIDs = currentIDs.subtracting(previousIDs)
            if !newDeviceIDs.isEmpty, self.activeDevice == nil {
                // Small delay to let the device initialize
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
        hasReportedResolution = false

        let session = AVCaptureSession()

        if session.canSetSessionPreset(.hd1920x1080) {
            session.sessionPreset = .hd1920x1080
        } else {
            session.sessionPreset = .high
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                delegate?.captureManager(self, didStopSession: "Cannot add device as input")
                return
            }
        } catch {
            delegate?.captureManager(self, didStopSession: "Error: \(error.localizedDescription)")
            return
        }

        // Add video data output for frame capture
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: bufferQueue)
        output.alwaysDiscardsLateVideoFrames = true

        if session.canAddOutput(output) {
            session.addOutput(output)
            self.videoOutput = output
        }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspect

        if let connection = layer.connection {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }

        self.captureSession = session
        self.previewLayer = layer
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
        previewLayer?.removeFromSuperlayer()
        captureSession = nil
        previewLayer = nil
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
        let context = CIContext()
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        guard let cgImage = context.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: width, height: height)) else {
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

        // Get resolution from latest frame
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
        // Store latest frame for screenshots
        latestSampleBuffer = sampleBuffer

        // Report resolution on first frame for auto-detect
        if !hasReportedResolution, let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) {
            let dims = CMVideoFormatDescriptionGetDimensions(formatDesc)
            hasReportedResolution = true
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.captureManager(self, didDetectResolution: Int(dims.width), height: Int(dims.height))
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
