//
//  Vision.swift
//  PBJSwiftDemo
//
//  Created by Bhautik Ziniya on 4/20/17.
//  Copyright © 2017 Agile Infoways. All rights reserved.
//

import UIKit
import Foundation
import AVFoundation
import ImageIO

// vision types
enum VisionCameraDevice: Int {
    case back
    case front
}

enum VisionCameraMode: Int {
    case photo
    case video
}

enum VisionCameraOrientation: Int {
    case portrait
    case portraitUpsideDown
    case landscapeRight
    case landscapeLeft
}

enum VisionFocusMode: Int {
    case locked
    case autoFocus
    case continuousAutoFocus
}

enum VisionExposureMode: Int {
    case locked
    case autoExpose
    case continuousAutoExposure
}

enum VisionFlashMode: Int {
    case off
    case on
    case auto
}

enum VisionMirroringMode: Int {
    case auto
    case on
    case off
}

enum VisionAuthorizationStatus: Int {
    case notDetermined
    case authorized
    case audioDenied
}

enum VisionCameraState: Int {
    case ready
    case accessDenied
    case noDeviceFound
    case notDetermined
}

enum VisionOutputFormat: Int {
    case preset
    case square // 1:1
    case widescreen // 16:9
    case standard // 4:3
}

// PBJError

let VisionErrorDomain: String = "VisionErrorDomain"

enum VisionErrorType: Int {
    case unknown = -1
    case cancelled = 100
    case sessionFailed = 101
    case badOutputFile = 102
    case outputFileExists = 103
    case captureFailed = 104
}

// additional video capture keys

let VisionVideoRotation: String = "VisionVideoRotation"

// photo dictionary keys

let VisionPhotoMetadataKey: String = "VisionPhotoMetadataKey"
let VisionPhotoJPEGKey: String = "VisionPhotoJPEGKey"
let VisionPhotoImageKey: String = "VisionPhotoImageKey"
let VisionPhotoThumbnailKey: String = "VisionPhotoThumbnailKey" // 160x120

// video dictionary keys

let VisionVideoPathKey: String = "VisionVideoPathKey"
let VisionVideoThumbnailKey: String = "VisionVideoThumbnailKey"
let VisionVideoThumbnailArrayKey: String = "VisionVideoThumbnailArrayKey"
let VisionVideoCapturedDurationKey: String = "VisionVideoCapturedDurationKey" // Captured duration in seconds

// suggested videoBitRate constants

let VideoBitRate480x360: CGFloat = 87500 * 8
let VideoBitRate640x480: CGFloat = 437500 * 8
let VideoBitRate1280x720: CGFloat = 1312500 * 8
let VideoBitRate1920x1080: CGFloat = 2975000 * 8
let VideoBitRate960x540: CGFloat = 3750000 * 8
let VideoBitRate1280x750: CGFloat = 5000000 * 8

let VisionRequiredMinimumDiskSpaceInBytes: UInt64 = 49999872   // ~ 47 MB
let VisionThumbnailWidth: CGFloat = 160.0

// KVO contexts

var VisionFocusObserverContext = "VisionFocusObserverContext"
var VisionExposureObserverContext = "VisionExposureObserverContext"
var VisionWhiteBalanceObserverContext = "VisionWhiteBalanceObserverContext"
var VisionFlashModeObserverContext = "VisionFlashModeObserverContext"
var VisionTorchModeObserverContext = "VisionTorchModeObserverContext"
var VisionFlashAvailabilityObserverContext = "VisionFlashAvailabilityObserverContext"
var VisionTorchAvailabilityObserverContext = "VisionTorchAvailabilityObserverContext"
var VisionCaptureStillImageIsCapturingStillImageObserverContext = "VisionCaptureStillImageIsCapturingStillImageObserverContext"

// flags
struct Flags {
    var previewRunning = false
    var changingModes = false
    var recording = false
    var paused = false
    var interrupted = false
    var videoWritten = false
    var videoRenderingEnabled = false
    var audioCaptureEnabled = false
    var thumbnailEnabled = false
    var defaultVideoThumbnails = false
    var videoCaptureFrame = false
}

// Blocks
typealias VisionOperationBlock = (Vision) -> Void
typealias VisionChangeCleanAperture = (Vision, CGRect) -> Void
typealias VisionAuthorizationStatusChangeCompletion = (VisionAuthorizationStatus) -> Void
typealias VisionCapturePhotoCompletion = (Vision, NSMutableDictionary?, Error?) -> Void
typealias VisionStartCaptureVideoToFileBlock = (Vision, String) -> String
typealias VisionCaptureVideoCompletion = (Vision, NSMutableDictionary?, Error?) -> Void
typealias VisionCaptureBufferBlock = (Vision, CMSampleBuffer) -> Void

class Vision: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {

    // AV
    
    var captureSession: AVCaptureSession!
    
    var captureDeviceFront: AVCaptureDevice!
    var captureDeviceBack: AVCaptureDevice!
    var captureDeviceAudio: AVCaptureDevice!
    
    var captureDeviceInputFront: AVCaptureDeviceInput!
    var captureDeviceInputBack: AVCaptureDeviceInput!
    var captureDeviceInputAudio: AVCaptureDeviceInput!

    @available(iOS 10.0, *)
    lazy var captureOutputPhoto: AVCapturePhotoOutput? = {
        let tmpcaptureOutputPhoto = AVCapturePhotoOutput()
        tmpcaptureOutputPhoto.isHighResolutionCaptureEnabled = true
        return tmpcaptureOutputPhoto
    }()
    
//    var captureOutputPhoto: AVCapturePhotoOutput!
    var captureOutputImage: AVCaptureStillImageOutput!
    var captureOutputAudio: AVCaptureAudioDataOutput!
    var captureOutputVideo: AVCaptureVideoDataOutput!
    
    // vision core
    
    var mediaWriter : MediaWriter!
    
    var captureSessionDispatchQueue: DispatchQueue!
    var captureCaptureDispatchQueue: DispatchQueue!
    
    private var privateCameraDevice = VisionCameraDevice.back
    private var privateCameraMode = VisionCameraMode.photo
    private var privateCameraOrientation = VisionCameraOrientation.portrait
    
    @available(iOS 10.0, *)
    lazy var capturePhotoSettings : AVCapturePhotoSettings = {
        let settings = AVCapturePhotoSettings()
        return settings
    }()
    
    private var privatePreviewOrientation = VisionCameraOrientation.portrait
    var autoUpdatePreviewOrientation: Bool!
    var autoFreezePreviewDuringCapture: Bool!
    var usesApplicationAudioSession: Bool!
    var automaticallyConfiguresApplicationAudioSession: Bool!
    
    private var privatefocusMode = VisionFocusMode.autoFocus
    private var privateExposureMode = VisionExposureMode.autoExpose
    private var privateFlashMode = VisionFlashMode.off
    private var privateMirroringMode = VisionMirroringMode.off
    
    private var privateCaptureSessionPreset : String = AVCaptureSessionPresetHigh
    var captureDirecotry: String!
    fileprivate var fileIndex : Int = 0
    private var privateOutputFormat = VisionOutputFormat.preset
    var captureThumbnailTimes: NSMutableSet!
    var captureThumbnailFrames: NSMutableSet!
    
    var videoBitRate: CGFloat!
    var audioBitRate: Int!
    private var privateVideoFrameRate: Int!
    var additionalCompressionProperties: [String : Any]!
    var additionalVideoProperties: [String : Any]!
    
    private var privateCurrentDevice: AVCaptureDevice!
    var currentInput: AVCaptureDeviceInput!
    var currentOutput: AVCaptureOutput!
    
    var previewLayer: AVCaptureVideoPreviewLayer!
    var cleanAperture: CGRect!
    
    var startTimestamp: CMTime!
    var timeOffset: CMTime!
    var maximumCaptureDuration: CMTime!
    
    // sample buffer rendering
    
    var bufferDevice: VisionCameraDevice!
    var bufferOrientation: VisionCameraOrientation!
    var bufferWidth: size_t!
    var bufferHeight: size_t!
    var presentationFrame: CGRect!
    
    private var flags = Flags()
    
    // For VYBZ project only.
    fileprivate var totalCapturedDuration : Double = 0.0
    
    // MARK: SharedInstance
    
    static let sharedInstance = Vision()
    
    /**
     Current camera status.
     
     - returns: Current state of the camera: Ready / AccessDenied / NoDeviceFound / NotDetermined
     */
    open var currentCameraStatus: VisionCameraState {
        return checkIfCameraIsAvailable()
    }
    
    var isVideoWritten: Bool {
        get {
            return self.flags.videoWritten
        }
    }
    
    var isCaptureSessionActive: Bool {
        get {
            return self.captureSession.isRunning
        }
    }
    
    var isRecording: Bool {
        get {
            return self.flags.recording
        }
    }
    
    var isPaused: Bool {
        get {
            return self.flags.paused
        }
    }
    
    var videoRenderingEnabled: Bool {
        set {
            self.flags.videoRenderingEnabled = newValue
        }
        get {
            return self.flags.videoRenderingEnabled
        }
    }
    
    var audioCaptureEnabled: Bool {
        set {
            self.flags.audioCaptureEnabled = newValue
        }
        get {
            return self.flags.audioCaptureEnabled
        }
    }
    
    var thumbnailEnabled: Bool {
        set {
            self.flags.thumbnailEnabled = newValue
        }
        get {
            return self.flags.thumbnailEnabled
        }
    }
    
    var defaultVideoThumbnails: Bool {
        set {
            self.flags.defaultVideoThumbnails = newValue
        }
        get {
            return self.flags.defaultVideoThumbnails
        }
    }
    
    var capturedAudioSeconds: Float64 {
        get {
            if let writer = self.mediaWriter, CMTIME_IS_VALID(writer.audioTimeStamp) {
                return CMTimeGetSeconds(CMTimeSubtract(writer.audioTimeStamp, self.startTimestamp))
            } else {
                return 0.0
            }
        }
    }
    
    var capturedVideoSeconds: Float64 {
        get {
            if let writer = self.mediaWriter, CMTIME_IS_VALID(writer.videoTimeStamp) {
                return CMTimeGetSeconds(CMTimeSubtract(writer.videoTimeStamp, self.startTimestamp))
            } else {
                return 0.0
            }
        }
    }
    
    var cameraDevice: VisionCameraDevice {
        set {
            self.setCameraMode(cameraMode: self.privateCameraMode, cameraDevice: newValue, outputFormat: self.privateOutputFormat)
        }
        get {
            return self.privateCameraDevice
        }
    }
    
    var cameraMode: VisionCameraMode {
        set {
            self.setCameraMode(cameraMode: newValue, cameraDevice: self.privateCameraDevice, outputFormat: self.privateOutputFormat)
        }
        get {
            return self.privateCameraMode
        }
    }
    
    var outputFormat: VisionOutputFormat {
        set {
            self.setCameraMode(cameraMode: self.privateCameraMode, cameraDevice: self.privateCameraDevice, outputFormat: newValue)
        }
        get {
            return self.privateOutputFormat
        }
    }
    
    var cameraOrientation: VisionCameraOrientation {
        set {
            guard self.privateCameraOrientation != newValue else {
                return
            }
            self.privateCameraOrientation = newValue
            
            if let _ = self.autoUpdatePreviewOrientation {
                self.privatePreviewOrientation = newValue
            }
        }
        get {
            return self.privateCameraOrientation
        }
    }
    
    var previewOrientation: VisionCameraOrientation {
        set {
            guard self.privatePreviewOrientation != newValue else {
                return
            }
            
            if self.previewLayer.connection.isVideoOrientationSupported {
                self.privatePreviewOrientation = newValue
                self.setOrientation(forConnection: self.previewLayer.connection)
            }
        }
        get {
            return self.privatePreviewOrientation
        }
    }
    
    var captureSessionPreset: String {
        set {
            self.privateCaptureSessionPreset = newValue
            
            if let sess = self.captureSession, sess.canSetSessionPreset(newValue) {
                self.commitBlock {
                    sess.sessionPreset = newValue
                }
            }
        }
        get {
            return self.privateCaptureSessionPreset
        }
    }
    
    //delegateblock
    //session
    var visionSessionWillStart: VisionOperationBlock?
    var visionSessionDidStart: VisionOperationBlock?
    var visionSessionDidStop: VisionOperationBlock?
    var visionSessionWasInterrupted: VisionOperationBlock?
    var visionSessionInterruptionEnded: VisionOperationBlock?
    
    // device / mode / format
    var visionCameraDeviceWillChange: VisionOperationBlock?
    var visionCameraDeviceDidChange: VisionOperationBlock?
    var visionCameraModeWillChange: VisionOperationBlock?
    var visionCameraModeDidChange: VisionOperationBlock?
    var visionOutputFormatWillChange: VisionOperationBlock?
    var visionOutputFormatDidChange: VisionOperationBlock?
    var visiondidChangeCleanAperture: VisionChangeCleanAperture?
    var visionDidChangeVideoFormatAndFrameRate: VisionOperationBlock?
    
    // focus / exposure
    var visionWillStartFocus: VisionOperationBlock?
    var visionDidStopFocus: VisionOperationBlock?
    var visionWillChangeExposure: VisionOperationBlock?
    var visionDidChangeExposure: VisionOperationBlock?
    var visionDidChangeFlashMode: VisionOperationBlock? // flash or torch was changed
    
    // authorization / availability
    var visionDidChangeAuthorizationStatus: VisionAuthorizationStatusChangeCompletion?
    var visionDidChangeFlashAvailablility: VisionOperationBlock? // flash or torch is available
    
    // preview
    var visionSessionDidStartPreview: VisionOperationBlock?
    var visionSessionDidStopPreview: VisionOperationBlock?
    
    // photo
    var visionWillCapturePhoto: VisionOperationBlock?
    var visionDidCapturePhoto: VisionOperationBlock?
    var visioncapturedPhotoCompletion: VisionCapturePhotoCompletion?
    
    // video
    var visionwillStartVideoCaptureToFile: VisionStartCaptureVideoToFileBlock?
    var visionDidStartVideoCapture: VisionOperationBlock?
    var visionDidPauseVideoCapture: VisionOperationBlock?
    var visionDidResumeVideoCapture: VisionOperationBlock?
    var visionDidEndVideoCapture: VisionOperationBlock?
    var visioncapturedVideoCompletion: VisionCaptureVideoCompletion?
    
    // video capture progress
    var visiondidCaptureVideoSampleBuffer: VisionCaptureBufferBlock?
    var visiondidCaptureAudioSample: VisionCaptureBufferBlock?
    
    func setOrientation(forConnection connection: AVCaptureConnection?) {
        guard let conn = connection, conn.isVideoOrientationSupported else {
            return
        }
        
        var orientation = AVCaptureVideoOrientation.portrait
        switch self.privateCameraOrientation {
        case .portraitUpsideDown:
            orientation = .portraitUpsideDown
        case .landscapeRight:
            orientation = .landscapeRight
        case .landscapeLeft:
            orientation = .landscapeLeft
        default:
            break
        }
        
        connection?.videoOrientation = orientation
    }
    
    func isCameraDeviceAvailable(cameraDevice: VisionCameraDevice) -> Bool {
        return UIImagePickerController.isCameraDeviceAvailable(cameraDevice == .back ? .rear : .front)
    }
    
    var isFocusPointOfInterestSupported: Bool {
        get {
            if let device = self.privateCurrentDevice {
                return device.isFocusPointOfInterestSupported
            } else {
                return false
            }
        }
    }
    
    var isFocusLockSupported: Bool {
        get {
            if let device = self.privateCurrentDevice {
                return device.isFocusModeSupported(.locked)
            } else {
                return false
            }
        }
    }
    
    func setCameraMode(cameraMode: VisionCameraMode, cameraDevice: VisionCameraDevice, outputFormat: VisionOutputFormat) {
        let changeMode = self.privateCameraMode != cameraMode
        let changeDevice = self.privateCameraDevice != cameraDevice
        let changeOutputFormat = self.privateOutputFormat != outputFormat
        
        print("change device: \(changeDevice), mode: \(changeMode), outputFormat: \(changeOutputFormat)")
        
        if !changeMode && !changeDevice && !changeOutputFormat {
            return
        }
        
        if let validvisionCameraDeviceWillChange = self.visionCameraDeviceWillChange , changeMode {
            validvisionCameraDeviceWillChange(self)
        }
        
        if let validvisionCameraModeWillChange = self.visionCameraModeWillChange , changeMode {
            validvisionCameraModeWillChange(self)
        }
        
        if let validvisionOutputFormatWillChange = self.visionOutputFormatWillChange , changeMode {
            validvisionOutputFormatWillChange(self)
        }
        
        self.flags.changingModes = true
        
        self.privateCameraDevice = cameraDevice
        self.privateCameraMode = cameraMode
        self.privateOutputFormat = outputFormat
        
        let didChangeBlock : VisionBlock = {
            self.flags.changingModes = false
            
            if let validvisionCameraDeviceDidChange = self.visionCameraDeviceDidChange , changeMode {
                validvisionCameraDeviceDidChange(self)
            }
            
            if let validvisionCameraModeDidChange = self.visionCameraModeDidChange , changeMode {
                validvisionCameraModeDidChange(self)
            }
            
            if let validvisionOutputFormatDidChange = self.visionOutputFormatDidChange , changeMode {
                validvisionOutputFormatDidChange(self)
            }
        }
        
        // since there is no session in progress, set and bail
        if self.captureSession == nil {
            self.flags.changingModes = false
            didChangeBlock()
            return
        }
        
        self.enqueueBlockOnCaptureSessionQueue {
            // camera is already setup, no need to call _setupCamera
            
            self.setupSession()
            
            self.mirroringMode = self.privateMirroringMode
            
            self.enqueueBlockOnMainQueue(block: didChangeBlock)
        }
    }
    
    var focusMode: VisionFocusMode {
        set {
            let shouldChangeFocusMode = self.privatefocusMode != newValue
            
            if let device = self.privateCurrentDevice, device.isFocusModeSupported(AVCaptureFocusMode(rawValue: newValue.rawValue)!) || !shouldChangeFocusMode {
                return
            }
            
            self.privatefocusMode = newValue
            
            if let device = self.privateCurrentDevice {
                do {
                    try device.lockForConfiguration()
                    device.focusMode = AVCaptureFocusMode(rawValue: newValue.rawValue)!
                    device.unlockForConfiguration()
                } catch {
                    print("setting auto focus mode error \(error.localizedDescription)")
                }
            }
        }
        get {
            return self.privatefocusMode
        }
    }
    
    var isExposureLockSupported: Bool {
        get {
            if let device = self.privateCurrentDevice {
                return device.isExposureModeSupported(.locked)
            } else {
                return false
            }
        }
    }
    
    var exposureMode: VisionExposureMode {
        set {
            let shouldChangeExposureMode = self.privateExposureMode != newValue

            if let device = self.privateCurrentDevice, device.isExposureModeSupported(AVCaptureExposureMode(rawValue: newValue.rawValue)!) || !shouldChangeExposureMode {
                return
            }
            
            self.privateExposureMode = newValue
            
            if let device = self.privateCurrentDevice {
                do {
                    try device.lockForConfiguration()
                    device.exposureMode = AVCaptureExposureMode(rawValue: newValue.rawValue)!
                    device.unlockForConfiguration()
                } catch {
                    print("setting exposure mode error \(error.localizedDescription)")
                }
            }
        }
        get {
            return self.privateExposureMode
        }
    }
    
    var currentDevice: AVCaptureDevice! {
        set {
            self.privateCurrentDevice = newValue
            if let device = newValue {
                self.privateExposureMode = VisionExposureMode(rawValue: device.exposureMode.rawValue)!
                self.privatefocusMode = VisionFocusMode(rawValue: device.focusMode.rawValue)!
            }
        }
        get {
            return self.privateCurrentDevice
        }
    }
    
    var isFlashModeAvailable: Bool {
        get {
            if let device = self.privateCurrentDevice {
                return device.hasFlash
            } else {
                return false
            }
        }
    }
    
    var flashMode: VisionFlashMode {
        set {
            let shouldChangeFlashMode = self.privateFlashMode != newValue
            
            if let device = self.privateCurrentDevice, !device.hasFlash || !shouldChangeFlashMode {
                return
            }
            
            self.privateFlashMode = newValue
            
            if let device = self.privateCurrentDevice {
                do {
                    try device.lockForConfiguration()
                    switch self.privateCameraMode {
                    case .photo:
                        if #available(iOS 10.0, *) {
                            if device.isFlashAvailable && self.capturePhotoSettings.flashMode != AVCaptureFlashMode(rawValue: newValue.rawValue)! {
                                self.capturePhotoSettings.flashMode = AVCaptureFlashMode(rawValue: newValue.rawValue)!
                            }
                        } else {
                            // Fallback on earlier versions
                            if device.hasFlash && device.flashMode != AVCaptureFlashMode(rawValue: newValue.rawValue)! {
                                device.flashMode = AVCaptureFlashMode(rawValue: newValue.rawValue)!
                            }
                        }
                        break
                    case .video:
                        if #available(iOS 10.0, *) {
                            if device.isFlashAvailable && self.capturePhotoSettings.flashMode != AVCaptureFlashMode(rawValue: newValue.rawValue)! {
                                self.capturePhotoSettings.flashMode = AVCaptureFlashMode(rawValue: newValue.rawValue)!
                            }
                        } else {
                            // Fallback on earlier versions
                            if device.hasFlash && device.flashMode != AVCaptureFlashMode(rawValue: newValue.rawValue)! {
                                device.flashMode = AVCaptureFlashMode(rawValue: newValue.rawValue)!
                            }
                        }
                        
                        if device.isTorchModeSupported(AVCaptureTorchMode(rawValue: newValue.rawValue)!) {
                            device.torchMode = AVCaptureTorchMode(rawValue: newValue.rawValue)!
                        }
                        break
                    }
                    device.unlockForConfiguration()
                } catch {
                    print("setting flash mode error \(error.localizedDescription)")
                }
            }
        }
        get {
            return self.privateFlashMode
        }
    }
    
    var videoFrameRate: Int {
        set {
            guard self.supportsVideoFrameRate(videoFrameRate: newValue) else {
                print("frame rate range not supported for current device format")
                return
            }
            
            let isRecording = self.flags.recording
            if isRecording {
                self.pauseVideoCapture()
            }
            
            let fps = CMTimeMake(1, Int32(newValue))
            
            let videoDevice = self.currentDevice
            var supportingFormat : AVCaptureDeviceFormat!
            var maxWidth : Int32 = 0
            
            let formats : [AVCaptureDeviceFormat] = videoDevice!.formats as! [AVCaptureDeviceFormat]
            
            for format in formats {
                let videoSupportedFramRateRanges: [AVFrameRateRange] = format.videoSupportedFrameRateRanges as! [AVFrameRateRange]
                for range in videoSupportedFramRateRanges {
                    let desc = format.formatDescription
                    let dimensions = CMVideoFormatDescriptionGetDimensions(desc!)
                    let width = dimensions.width
                    
                    if range.minFrameRate <= Float64(newValue) && Float64(newValue) <= range.maxFrameRate && width >= maxWidth {
                        supportingFormat = format
                        maxWidth = width
                    }
                }
            }
            
            if let format = supportingFormat {
                self.captureSession.beginConfiguration()
                
                if let device = self.privateCurrentDevice {
                    do {
                        try device.lockForConfiguration()
                        device.activeFormat = format
                        device.activeVideoMinFrameDuration = fps
                        device.activeVideoMaxFrameDuration = fps
                        self.privateVideoFrameRate = newValue
                        device.unlockForConfiguration()
                    } catch {
                        print("supporting format error \(error.localizedDescription)")
                    }
                }
            }
            
            if let sess = self.captureSession {
                sess.commitConfiguration()
            }
            
            self.enqueueBlockOnMainQueue {
                if let validvisionDidChangeVideoFormatAndFrameRate = self.visionDidChangeVideoFormatAndFrameRate {
                    validvisionDidChangeVideoFormatAndFrameRate(self)
                }
            }
            
            if isRecording {
                self.resumeVideoCapture()
            }
        }
        get {
            if let device = self.privateCurrentDevice {
                return Int(device.activeVideoMaxFrameDuration.timescale)
            } else {
                return 0
            }
        }
    }
    
    func supportsVideoFrameRate(videoFrameRate: Int) -> Bool {
        var videoDevice : AVCaptureDevice!
        
        if self.privateCameraDevice == .back {
            if #available(iOS 10.0, *) {
                videoDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .back)
            } else {
                // Fallback on earlier versions
                let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as? [AVCaptureDevice]
                if devices != nil {
                    for device in devices! {
                        if device.position == .back {
                            videoDevice = device
                        }
                    }
                }
            }
        } else {
            if #available(iOS 10.0, *) {
                videoDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .front)
            } else {
                // Fallback on earlier versions
                let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as? [AVCaptureDevice]
                if devices != nil {
                    for device in devices! {
                        if device.position == .front {
                            videoDevice = device
                        }
                    }
                }
            }
        }
        
        guard videoDevice != nil else {
            return false
        }
        
        let formats : [AVCaptureDeviceFormat] = videoDevice.formats as! [AVCaptureDeviceFormat]

        for format in formats {
            let videoSupportedFrameRateRanges: [AVFrameRateRange] = format.videoSupportedFrameRateRanges as! [AVFrameRateRange]
            for frameRateRange in videoSupportedFrameRateRanges {
                if frameRateRange.minFrameRate <= Float64(videoFrameRate) && Float64(videoFrameRate) <= frameRateRange.maxFrameRate {
                    return true
                }
            }
        }
        
        return false
    }
    
    var mirroringMode: VisionMirroringMode {
        set {
            self.privateMirroringMode = newValue
            
            var videoConnection : AVCaptureConnection!
            var previewConnection : AVCaptureConnection!
            
            if let validOutput = self.currentOutput {
                videoConnection = validOutput.connection(withMediaType: AVMediaTypeVideo)
                previewConnection = self.previewLayer.connection
            }
            
            switch self.privateMirroringMode {
            case .off:
                if let connection = videoConnection, connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = false
                }
                
                if let connection = previewConnection, connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = false
                }
                break
            case .on:
                if let connection = videoConnection, connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = true
                }
                
                if let connection = previewConnection, connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = true
                }
                break
            case .auto:
                if let connection = videoConnection, connection.isVideoMirroringSupported {
                    let mirror = self.cameraDevice == VisionCameraDevice.front
                    connection.isVideoMirrored = mirror
                }
                
                if let connection = previewConnection, connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = true
                }
                break
            }
        }
        get {
            return self.privateMirroringMode
        }
    }
    
    // MARK: Init 
    
    override init() {
        super.init()
        
        
        self.captureSessionPreset = AVCaptureSessionPresetHigh
        self.captureDirecotry = nil
        
        self.autoUpdatePreviewOrientation = true
        self.autoFreezePreviewDuringCapture = true
        self.usesApplicationAudioSession = false
        self.automaticallyConfiguresApplicationAudioSession = true
        
        // Average bytes per second based on video dimensions
        // lower the bitRate, higher the compression
        self.videoBitRate = VideoBitRate640x480
        
        // default audio/video configuration
        self.audioBitRate = 64000
        
        // default flags
        self.flags.thumbnailEnabled = true
        self.flags.defaultVideoThumbnails = true
        self.flags.audioCaptureEnabled = true
        
        // setup queues
        self.captureSessionDispatchQueue = DispatchQueue(label: "VisionSession") // protects session
        self.captureCaptureDispatchQueue = DispatchQueue(label: "VisionCapture") // protects capture
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: nil)
        
        self.maximumCaptureDuration = kCMTimeInvalid
        
        self.mirroringMode = VisionMirroringMode.auto
        
        NotificationCenter.default.addObserver(self, selector: #selector(Vision.applicationWillEnterForeground(notification:)), name: NSNotification.Name.UIApplicationWillEnterForeground, object: UIApplication.shared)
        NotificationCenter.default.addObserver(self, selector: #selector(Vision.applicationDidEnterBackground(notification:)), name: NSNotification.Name.UIApplicationDidEnterBackground, object: UIApplication.shared)
        
//        self.registerMediaWriterCompletionBlocks()
    }
    
    deinit {
        
        NotificationCenter.default.removeObserver(self)
        
        self.destroyCamera()
    }
    
    // MARK: Camera 
    
    // only call from the session queue
    func setupCamera() {
        guard self.captureSession == nil else {
            return
        }
        
        // create session
        self.captureSession = AVCaptureSession()
        
        if let use = self.usesApplicationAudioSession, use == true {
            self.captureSession.usesApplicationAudioSession = true
        }
        
        self.captureSession.automaticallyConfiguresApplicationAudioSession = self.automaticallyConfiguresApplicationAudioSession!
        
        // capture devices
        self.captureDeviceFront = VisionUtilities.captureDeivce(position: .front)
        self.captureDeviceBack = VisionUtilities.captureDeivce(position: .back)
        
        // capture device inputs
        do {
            self.captureDeviceInputFront = try AVCaptureDeviceInput(device: self.captureDeviceFront!)
        } catch {
            print("error setting up front camera input : \(error.localizedDescription)")
        }
        
        do {
            self.captureDeviceInputBack = try AVCaptureDeviceInput(device: self.captureDeviceBack!)
        } catch {
            print("error setting up back camera input: \(error.localizedDescription)")
        }
        
        if self.cameraMode != VisionCameraMode.photo && flags.audioCaptureEnabled {
            self.captureDeviceAudio = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
            do {
                self.captureDeviceInputAudio = try AVCaptureDeviceInput(device: self.captureDeviceAudio!)
            } catch {
                print("error setting up audio input : \(error.localizedDescription)")
            }
        }
        
        
        // capture device ouputs
        
        if #available(iOS 10.0, *) {
        } else {
            if self.captureOutputImage == nil {
                self.captureOutputImage = AVCaptureStillImageOutput()
            }
            
        }
        
        if self.cameraMode != VisionCameraMode.photo && flags.audioCaptureEnabled {
            self.captureOutputAudio = AVCaptureAudioDataOutput()
        }
        
        self.captureOutputVideo = AVCaptureVideoDataOutput()
        
        if self.cameraMode != VisionCameraMode.photo && flags.audioCaptureEnabled {
            self.captureOutputAudio.setSampleBufferDelegate(self, queue: self.captureCaptureDispatchQueue)
        }
        
        self.captureOutputVideo.setSampleBufferDelegate(self, queue: self.captureCaptureDispatchQueue)
        
        // capture device initial settings
        self.privateVideoFrameRate = 30
        
        // add notification observers
        let notificationCenter = NotificationCenter.default
        
        // session notifications
        notificationCenter.addObserver(self, selector: #selector(Vision.sessionRuntimeErrored(notification:)), name: NSNotification.Name.AVCaptureSessionRuntimeError, object: self.captureSession)
        notificationCenter.addObserver(self, selector: #selector(Vision.sessionStarted(notification:)), name: NSNotification.Name.AVCaptureSessionDidStartRunning, object: self.captureSession)
        notificationCenter.addObserver(self, selector: #selector(Vision.sessionStopped(notification:)), name: NSNotification.Name.AVCaptureSessionDidStopRunning, object: self.captureSession)
        notificationCenter.addObserver(self, selector: #selector(Vision.sessionWasInterrupted(notification:)), name: NSNotification.Name.AVCaptureSessionWasInterrupted, object: self.captureSession)
        notificationCenter.addObserver(self, selector: #selector(Vision.sessionInterruptionEnded(notification:)), name: NSNotification.Name.AVCaptureSessionInterruptionEnded, object: self.captureSession)
        
        // capture input notifications
        notificationCenter.addObserver(self, selector: #selector(Vision.inputPortFormatDescriptionDidChange(notification:)), name: NSNotification.Name.AVCaptureInputPortFormatDescriptionDidChange, object: nil)
        
        // capture device notifications
        notificationCenter.addObserver(self, selector: #selector(Vision.deviceSubjectAreaDidChange(notification:)), name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange, object: nil)
        
        // current device KVO notifications
        self.addObserver(self, forKeyPath: "currentDevice.adjustingFocus", options: .new, context: &VisionFocusObserverContext)
        self.addObserver(self, forKeyPath: "currentDevice.adjustingExposure", options: .new, context: &VisionExposureObserverContext)
        self.addObserver(self, forKeyPath: "currentDevice.adjustingWhiteBalance", options: .new, context: &VisionWhiteBalanceObserverContext)
        self.addObserver(self, forKeyPath: "currentDevice.flashMode", options: .new, context: &VisionFlashModeObserverContext)
        self.addObserver(self, forKeyPath: "currentDevice.torchMode", options: .new, context: &VisionTorchModeObserverContext)
        self.addObserver(self, forKeyPath: "currentDevice.flashAvailable", options: .new, context: &VisionFlashAvailabilityObserverContext)
        self.addObserver(self, forKeyPath: "currentDevice.torchAvailable", options: .new, context: &VisionTorchAvailabilityObserverContext)
        
        
        // KVO is only used to monitor focus and capture events
        if #available(iOS 10.0, *) { // Don't do anything for ios 10
        }
        else {
            self.captureOutputImage.addObserver(self, forKeyPath: "capturingStillImage", options: .new, context: &VisionCaptureStillImageIsCapturingStillImageObserverContext)
        }
        
        print("camera setup")
    }
    
    // only call from the session queue
    func destroyCamera() {
        guard self.captureSession != nil else {
            return
        }
        
        // current device KVO notifications
        self.removeObserver(self, forKeyPath: "currentDevice.adjustingFocus")
        self.removeObserver(self, forKeyPath: "currentDevice.adjustingExposure")
        self.removeObserver(self, forKeyPath: "currentDevice.adjustingWhiteBalance")
        self.removeObserver(self, forKeyPath: "currentDevice.flashMode")
        self.removeObserver(self, forKeyPath: "currentDevice.torchMode")
        self.removeObserver(self, forKeyPath: "currentDevice.flashAvailable")
        self.removeObserver(self, forKeyPath: "currentDevice.torchAvailable")
        
        // capture events KVO notifications
        
        if #available(iOS 10.0, *) { // Don't do anything for ios 10
            
        }
        else {
            self.captureOutputImage.removeObserver(self, forKeyPath: "capturingStillImage")
        }
        
        // remove notification observers (we don't want to just 'remove all' because we're also observing background notifications
        let notificationCenter = NotificationCenter.default
        
        // session notifications
        notificationCenter.removeObserver(self, name: NSNotification.Name.AVCaptureSessionRuntimeError, object: self.captureSession)
        notificationCenter.removeObserver(self, name: NSNotification.Name.AVCaptureSessionDidStartRunning, object: self.captureSession)
        notificationCenter.removeObserver(self, name: NSNotification.Name.AVCaptureSessionDidStopRunning, object: self.captureSession)
        notificationCenter.removeObserver(self, name: NSNotification.Name.AVCaptureSessionWasInterrupted, object: self.captureSession)
        notificationCenter.removeObserver(self, name: NSNotification.Name.AVCaptureSessionInterruptionEnded, object: self.captureSession)
        
        // capture input notifications
        notificationCenter.removeObserver(self, name: NSNotification.Name.AVCaptureInputPortFormatDescriptionDidChange, object: nil)
        
        // capture device notifications
        notificationCenter.removeObserver(self, name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange, object: nil)
        
        if #available(iOS 10.0, *) {
            self.captureOutputPhoto = nil
        } else {
            self.captureOutputImage = nil
        }
        self.captureOutputAudio = nil
        self.captureOutputVideo = nil
        
        self.captureDeviceAudio = nil
        self.captureDeviceInputAudio = nil
        self.captureDeviceInputFront = nil
        self.captureDeviceInputBack = nil
        self.captureDeviceFront = nil
        self.captureDeviceBack = nil
        
        self.captureSession = nil
        self.currentDevice = nil
        self.currentInput = nil
        self.currentOutput = nil
        
        print("camera destroyed")
    }
    
    fileprivate func checkIfCameraIsAvailable() -> VisionCameraState {
        let deviceHasCamera = UIImagePickerController.isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.rear) || UIImagePickerController.isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.front)
        if deviceHasCamera {
            let authorizationStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
            let userAgreedToUseIt = authorizationStatus == .authorized
            if userAgreedToUseIt {
                return .ready
            } else if authorizationStatus == AVAuthorizationStatus.notDetermined {
                return .notDetermined
            } else {
                print("Camera access denied. You need to go to settings app and grant acces to the camera device to use it.")
                return .accessDenied
            }
        } else {
            print("Camera unavailable. The device does not have a camera.")
            return .noDeviceFound
        }
    }
    
    /**
     Asks the user for camera permissions. Only works if the permissions are not yet determined. Note that it'll also automaticaly ask about the microphone permissions if you selected VideoWithMic output.
     
     - parameter completion: Completion block with the result of permission request
     */
    
    open func askUserForCameraPermission(_ completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { (alowedAccess) -> Void in
            if self.cameraMode == .video {
                AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeAudio, completionHandler: { (alowedAccess) -> Void in
                    DispatchQueue.main.sync(execute: { () -> Void in
                        completion(alowedAccess)
                    })
                })
            } else {
                DispatchQueue.main.sync(execute: { () -> Void in
                    completion(alowedAccess)
                })
                
            }
        })
    }

    // MARK: AVCaptureSession
    
    func canSessionCapture(captureOutput: AVCaptureOutput) -> Bool {
        let sessionContainsOutput = self.captureSession.outputs.contains { (obj) -> Bool in
            return (obj as! AVCaptureOutput) == captureOutput
        }
        let outputHasConnection = captureOutput.connection(withMediaType: AVMediaTypeVideo) != nil
        return sessionContainsOutput && outputHasConnection
    }
    
    // _setupSession is always called from the captureSession queue
    func setupSession() {
        
        guard self.captureSession != nil else {
            print("error, no session running to setup")
            return
        }
        
        let shouldSwitchDevice = self.currentDevice == nil || (self.currentDevice == self.captureDeviceFront && self.cameraDevice != VisionCameraDevice.front) || (self.currentDevice == self.captureDeviceBack && self.cameraDevice != VisionCameraDevice.back)
        
        
        let cameraOutput : AVCaptureOutput!
        if #available(iOS 10.0, *) {
            cameraOutput = self.captureOutputPhoto
        } else {
            cameraOutput = self.captureOutputImage
        }
        
        let shouldSwitchMode = self.currentOutput == nil || (self.currentOutput == cameraOutput && self.cameraMode != VisionCameraMode.photo) || (self.currentOutput == self.captureOutputVideo && self.cameraMode != VisionCameraMode.video)
        
        print("switchDevice \(shouldSwitchDevice), switchMode: \(shouldSwitchMode)")
        
        if !shouldSwitchDevice && !shouldSwitchMode {
            return
        }
        
        var newDeviceInput : AVCaptureDeviceInput!
        var newCaptureOutput: AVCaptureOutput!
        var newCaptureDevice: AVCaptureDevice!
        
        self.captureSession.beginConfiguration()
        
        // setup session device
        
        if shouldSwitchDevice {
            switch self.cameraDevice {
            case .front:
                if let validDeviceInput = self.captureDeviceInputBack {
                    self.captureSession.removeInput(validDeviceInput)
                }
                
                if let validDeviceInput = self.captureDeviceInputFront, self.captureSession.canAddInput(validDeviceInput) {
                    self.captureSession.addInput(validDeviceInput)
                    newDeviceInput = validDeviceInput
                    newCaptureDevice = self.captureDeviceFront
                }
                break
            case .back:
                if let validDeviceInput = self.captureDeviceInputFront {
                    self.captureSession.removeInput(validDeviceInput)
                }
                
                if let validDeviceInput = self.captureDeviceInputBack, self.captureSession.canAddInput(validDeviceInput) {
                    self.captureSession.addInput(validDeviceInput)
                    newDeviceInput = validDeviceInput
                    newCaptureDevice = self.captureDeviceBack
                }
                break
            }
        } // shouldSwitchDevice
        
        // setup session input/output
        
        if shouldSwitchMode {
            // disable audio when in use for photos, otherwise enable it
            if self.cameraMode == VisionCameraMode.photo {
                if let validDeviceInput = self.captureDeviceInputAudio {
                    self.captureSession.removeInput(validDeviceInput)
                }
                
                if let validOutputAudio = self.captureOutputAudio {
                    self.captureSession.removeOutput(validOutputAudio)
                }
            } else if self.captureDeviceAudio == nil && self.captureDeviceInputAudio == nil && self.captureOutputAudio == nil && flags.audioCaptureEnabled {
                
                self.captureDeviceAudio = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
                
                do {
                    self.captureDeviceInputAudio = try AVCaptureDeviceInput(device: self.captureDeviceAudio)
                } catch {
                    print("error setting up audio input \(error.localizedDescription)")
                }
                
                self.captureOutputAudio = AVCaptureAudioDataOutput()
                self.captureOutputAudio.setSampleBufferDelegate(self, queue: self.captureCaptureDispatchQueue)
            }
            
            self.captureSession.removeOutput(self.captureOutputVideo)
            
            if #available(iOS 10.0, *) {
                self.captureSession.removeOutput(self.captureOutputPhoto)
            } else {
                self.captureSession.removeOutput(self.captureOutputImage)
            }
            
            switch self.cameraMode {
            case .video:
                // audio input
                if self.captureSession.canAddInput(self.captureDeviceInputAudio) {
                    self.captureSession.addInput(self.captureDeviceInputAudio)
                }
                
                // audio output
                if self.captureSession.canAddOutput(self.captureOutputAudio) {
                    self.captureSession.addOutput(self.captureOutputAudio)
                }
                
                // video output
                if self.captureSession.canAddOutput(self.captureOutputVideo) {
                    self.captureSession.addOutput(self.captureOutputVideo)
                    newCaptureOutput = self.captureOutputVideo
                }
                break
            case .photo:
                // photo output
                if self.captureSession.canAddOutput(cameraOutput) {
                    self.captureSession.addOutput(cameraOutput)
                    newCaptureOutput = cameraOutput
                }
                break
            }
        } // shouldSwitchMode
        
        if newCaptureDevice == nil {
            newCaptureDevice = self.currentDevice
        }
        
        if newCaptureOutput == nil {
            newCaptureOutput = self.currentOutput
        }
        
        // setup video connection
        let videoConnection = self.captureOutputVideo.connection(withMediaType: AVMediaTypeVideo)
        
        // setup input/output
        
        var sessionPreset = self.captureSessionPreset
        
        if newCaptureOutput != nil && (newCaptureOutput == self.captureOutputVideo) && videoConnection != nil {
            // setup video orientation
            self.setOrientation(forConnection: videoConnection)
            
            // setup video stabilization, if available
            if videoConnection!.isVideoStabilizationSupported {
                if videoConnection!.responds(to: #selector(getter: AVCaptureConnection.preferredVideoStabilizationMode)) {
                    videoConnection!.preferredVideoStabilizationMode = AVCaptureVideoStabilizationMode.auto
                }
            }
            
            // discard late frames
            self.captureOutputVideo.alwaysDiscardsLateVideoFrames = true
            
            // specify video preset
            sessionPreset = self.captureSessionPreset

            // setup video settings
            // kCVPixelFormatType_420YpCbCr8BiPlanarFullRange Bi-Planar Component Y'CbCr 8-bit 4:2:0, full-range (luma=[0,255] chroma=[1,255])
            // baseAddr points to a big-endian CVPlanarPixelBufferInfo_YCbCrBiPlanar struct
            var supportsFullRangeYUV = false
            var supportsVideoRangeYUV = false
            
            let supportedPixelFormats: [OSType] = self.captureOutputVideo.availableVideoCVPixelFormatTypes as! [OSType]
            
            for currentPixelFormat in supportedPixelFormats {
                if currentPixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange {
                    supportsFullRangeYUV = true
                }
                
                if currentPixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange {
                    supportsVideoRangeYUV = true
                }
            }
            
            var videoSettings : [AnyHashable : Any]!
            if supportsFullRangeYUV {
                videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
            } else if supportsVideoRangeYUV {
                videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
            }
            
            if videoSettings != nil {
                self.captureOutputVideo.videoSettings = videoSettings
            }
            
            // setup video device configuration
            do {
                try newCaptureDevice.lockForConfiguration()
                if newCaptureDevice.isSmoothAutoFocusSupported {
                    newCaptureDevice.isSmoothAutoFocusEnabled = true
                }
                newCaptureDevice.unlockForConfiguration()
            } catch {
                print("error locking device for video device configuration \(error.localizedDescription)")
            }
        } else if newCaptureOutput != nil && newCaptureOutput == cameraOutput {
            
            // specify photo preset
            sessionPreset = self.captureSessionPreset
            
            // setup photo settings
            if #available(iOS 10.0, *) {
            } else {
                let photoSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
                self.captureOutputImage.outputSettings = photoSettings
            }
            
            // setup photo device configuration
            do {
                try newCaptureDevice.lockForConfiguration()
                if newCaptureDevice.isLowLightBoostSupported {
                    newCaptureDevice.automaticallyEnablesLowLightBoostWhenAvailable = true
                }
                newCaptureDevice.unlockForConfiguration()
            } catch {
                print("error locking device for photo device configuration \(error.localizedDescription)")
            }
        }
        
        // apply presets
        if self.captureSession.canSetSessionPreset(sessionPreset) {
            self.captureSession.sessionPreset = sessionPreset
        }
        
        
        if let input = newDeviceInput {
            self.currentInput = input
        }
        
        if let output = newCaptureOutput {
            self.currentOutput = output
        }
        
        // ensure there is a capture device setup
        if let input = currentInput {
            let device = input.device
            if let validDevice = device {
                self.willChangeValue(forKey: "currentDevice")
                self.currentDevice = validDevice
                self.didChangeValue(forKey: "currentDevice")
            }
        }
        
        self.captureSession.commitConfiguration()
        
        print("capture session setup")
    }
    
    // MARK: - UIGestureRecognizerDelegate
    
    func attachFocus(_ view: UIView) {
        let focus = UITapGestureRecognizer(target: self, action: #selector(Vision.focusStart(_:)))
        view.addGestureRecognizer(focus)
//        focus.delegate = self
    }
    
    @objc fileprivate func focusStart(_ recognizer: UITapGestureRecognizer) {
        
        let device: AVCaptureDevice?
        
        switch cameraDevice {
        case .back:
            device = captureDeviceBack
        case .front:
            device = captureDeviceFront
        }
        
        if let validDevice = device {
            
            if let validPreviewLayer = previewLayer,
                let view = recognizer.view
            {
                let pointInPreviewLayer = view.layer.convert(recognizer.location(in: view), to: validPreviewLayer)
                let pointOfInterest = validPreviewLayer.captureDevicePointOfInterest(for: pointInPreviewLayer)
                
                do {
                    try validDevice.lockForConfiguration()
                    
                    showFocusRectangleAtPoint(pointInPreviewLayer, inLayer: validPreviewLayer)
                    
                    if validDevice.isFocusPointOfInterestSupported {
                        validDevice.focusPointOfInterest = pointOfInterest;
                    }
                    
                    if  validDevice.isExposurePointOfInterestSupported {
                        validDevice.exposurePointOfInterest = pointOfInterest;
                    }
                    
                    if validDevice.isFocusModeSupported(.continuousAutoFocus) {
                        validDevice.focusMode = .continuousAutoFocus
                    }
                    
                    if validDevice.isExposureModeSupported(.continuousAutoExposure) {
                        validDevice.exposureMode = .continuousAutoExposure
                    }
                    
                    validDevice.unlockForConfiguration()
                }
                catch let error {
                    loggingPrint(error)
                }
            }
        }
    }
    
    fileprivate var lastFocusRectangle:CAShapeLayer? = nil
    
    fileprivate func showFocusRectangleAtPoint(_ focusPoint: CGPoint, inLayer layer: CALayer) {
        
        if let lastFocusRectangle = lastFocusRectangle {
            
            lastFocusRectangle.removeFromSuperlayer()
            self.lastFocusRectangle = nil
        }
        
        let size = CGSize(width: 75, height: 75)
        let rect = CGRect(origin: CGPoint(x: focusPoint.x - size.width / 2.0, y: focusPoint.y - size.height / 2.0), size: size)
        
        let endPath = UIBezierPath(rect: rect)
        endPath.move(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.minY))
        endPath.addLine(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.minY + 5.0))
        endPath.move(to: CGPoint(x: rect.maxX, y: rect.minY + size.height / 2.0))
        endPath.addLine(to: CGPoint(x: rect.maxX - 5.0, y: rect.minY + size.height / 2.0))
        endPath.move(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.maxY))
        endPath.addLine(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.maxY - 5.0))
        endPath.move(to: CGPoint(x: rect.minX, y: rect.minY + size.height / 2.0))
        endPath.addLine(to: CGPoint(x: rect.minX + 5.0, y: rect.minY + size.height / 2.0))
        
        let startPath = UIBezierPath(cgPath: endPath.cgPath)
        let scaleAroundCenterTransform = CGAffineTransform(translationX: -focusPoint.x, y: -focusPoint.y).concatenating(CGAffineTransform(scaleX: 2.0, y: 2.0).concatenating(CGAffineTransform(translationX: focusPoint.x, y: focusPoint.y)))
        startPath.apply(scaleAroundCenterTransform)
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = endPath.cgPath
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = UIColor(red:1, green:0.83, blue:0, alpha:0.95).cgColor
        shapeLayer.lineWidth = 1.0
        
        layer.addSublayer(shapeLayer)
        lastFocusRectangle = shapeLayer
        
        CATransaction.begin()
        
        CATransaction.setAnimationDuration(0.2)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut))
        
        CATransaction.setCompletionBlock() {
            if shapeLayer.superlayer != nil {
                shapeLayer.removeFromSuperlayer()
                self.lastFocusRectangle = nil
            }
        }
        
        let appearPathAnimation = CABasicAnimation(keyPath: "path")
        appearPathAnimation.fromValue = startPath.cgPath
        appearPathAnimation.toValue = endPath.cgPath
        shapeLayer.add(appearPathAnimation, forKey: "path")
        
        let appearOpacityAnimation = CABasicAnimation(keyPath: "opacity")
        appearOpacityAnimation.fromValue = 0.0
        appearOpacityAnimation.toValue = 1.0
        shapeLayer.add(appearOpacityAnimation, forKey: "opacity")
        
        let disappearOpacityAnimation = CABasicAnimation(keyPath: "opacity")
        disappearOpacityAnimation.fromValue = 1.0
        disappearOpacityAnimation.toValue = 0.0
        disappearOpacityAnimation.beginTime = CACurrentMediaTime() + 0.8
        disappearOpacityAnimation.fillMode = kCAFillModeForwards
        disappearOpacityAnimation.isRemovedOnCompletion = false
        shapeLayer.add(disappearOpacityAnimation, forKey: "opacity")
        
        CATransaction.commit()
    }
    
    // MARK: Start Preview
    
    func startPreview() {
        self.enqueueBlockOnCaptureSessionQueue {
            if self.captureSession == nil {
                self.setupCamera()
                self.setupSession()
            }
            
            self.mirroringMode = self.privateMirroringMode
            
            if let validLayer = self.previewLayer, validLayer.session != self.captureSession {
                validLayer.session = self.captureSession
                self.setOrientation(forConnection: validLayer.connection)
            }
            
            if let validLayer = self.previewLayer {
                validLayer.connection.isEnabled = true
            }
            
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                
                self.enqueueBlockOnMainQueue {
                    if let validvisionSessionDidStartPreview = self.visionSessionDidStartPreview {
                        validvisionSessionDidStartPreview(self)
                    }
                }
                print("capture session running")
            }
            
            self.flags.previewRunning = true
        }
    }
    
    // MARK: Stop Preivew
    
    func stopPreivew() {
        self.enqueueBlockOnCaptureSessionQueue {
            guard self.flags.previewRunning else {
                return
            }
            
            if let validLayer = self.previewLayer {
                validLayer.connection.isEnabled = false
            }
            
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
            
            self.executeBlockOnMainQueue {
                if let validvisionSessionDidStopPreview = self.visionSessionDidStopPreview {
                    validvisionSessionDidStopPreview(self)
                }
            }
            print("capture session stopped")
            self.flags.previewRunning = false
        }
    }
    
    func freezePreview() {
        if let validLayer = self.previewLayer {
            validLayer.connection.isEnabled = false
        }
    }
    
    func unFreezePreview() {
        if let validLayer = self.previewLayer {
            validLayer.connection.isEnabled = true
        }
    }
    
    // MARK: focus. exposure, white balance
    
    func focusStarted() {
        if let validvisionWillStartFocus = self.visionWillStartFocus {
            validvisionWillStartFocus(self)
        }
    }
    
    func focusEnded() {
        let focusMode = self.currentDevice.focusMode
        let isFocusing = self.currentDevice.isAdjustingFocus
        let isAutoFocusEnabled = focusMode == .autoFocus || focusMode == .continuousAutoFocus
        
        if !isFocusing && isAutoFocusEnabled {
            do {
                try self.currentDevice.lockForConfiguration()
                self.currentDevice.isSubjectAreaChangeMonitoringEnabled  = true
                self.currentDevice.unlockForConfiguration()
            } catch {
                print("error locking device post exposure for subject area change monitoring \(error.localizedDescription)")
            }
        }
        
        if let validvisionDidStopFocus = self.visionDidStopFocus {
            validvisionDidStopFocus(self)
        }
        print("focus ended")
    }
    
    func exposureChangeStarted() {
        if let validvisionWillChangeExposure = self.visionWillChangeExposure {
            validvisionWillChangeExposure(self)
        }
    }
    
    func exposureChangeEnded() {
        let isContinuousAutoExposureEnabled = self.currentDevice.exposureMode == AVCaptureExposureMode.continuousAutoExposure
        let isExposing = self.currentDevice.isAdjustingExposure
//        let isFocusSupported = self.currentDevice.isFocusModeSupported(.continuousAutoFocus)
        let isExposureSupported = self.currentDevice.isExposureModeSupported(.continuousAutoExposure)
    
        if isContinuousAutoExposureEnabled && !isExposing && !isExposureSupported {
            do {
                try currentDevice.lockForConfiguration()
                self.currentDevice.isSubjectAreaChangeMonitoringEnabled = true
                self.currentDevice.unlockForConfiguration()
            } catch {
                print("error locing device post exposure for subject area change monitoring \(error.localizedDescription)")
            }
        }
        
        if let validvisionDidChangeExposure = self.visionDidChangeExposure {
            validvisionDidChangeExposure(self)
        }
        print("exposure change ended")
    }
    
    func whiteBalanceChangeStarted() {
        
    }
    
    func whiteBalanceChangeEnded() {
        
    }
    
    func focusAtAdjustedPointOfInterest(adjustedPoint: CGPoint) {
        if self.currentDevice.isAdjustingFocus || self.currentDevice.isAdjustingExposure {
            return
        }
        
        do {
            try self.currentDevice.lockForConfiguration()
            
            let isFocusAtPointSupported = self.currentDevice.isFocusPointOfInterestSupported

            if isFocusAtPointSupported && self.currentDevice.isFocusModeSupported(.autoFocus) {
                let fm = self.currentDevice.focusMode
                self.currentDevice.focusPointOfInterest = adjustedPoint
                self.currentDevice.focusMode = fm
            }
            self.currentDevice.unlockForConfiguration()
        } catch {
            print("error locking device for focus adjustment \(error)")
        }
    }
    
    func isAdjustingFocus() -> Bool {
        return self.currentDevice.isAdjustingFocus
    }
    
    func exposeAtAdjustedPointOfInterest(adjustedPoint: CGPoint) {
        
        if self.currentDevice.isAdjustingExposure {
            return
        }
        
        do {
            try self.currentDevice.lockForConfiguration()
            
            let isExposureAtPointSupported = self.currentDevice.isExposurePointOfInterestSupported
            
            if isExposureAtPointSupported && self.currentDevice.isExposureModeSupported(.continuousAutoExposure) {
                let em = self.currentDevice.exposureMode
                self.currentDevice.exposurePointOfInterest = adjustedPoint
                self.currentDevice.exposureMode = em
            }
            self.currentDevice.unlockForConfiguration()
        } catch {
            print("error locking device for exposure adjustment \(error.localizedDescription)")
        }
    }
    
    func isAdjustingExposure() -> Bool {
        return self.currentDevice.isAdjustingExposure
    }
    
    func adjustFocusExposureAndWhiteBalance() {
        if self.currentDevice.isAdjustingFocus || self.currentDevice.isAdjustingExposure {
            return
        }
        
        // only notify clients when focus is triggered from an event
        if let validvisionWillStartFocus = self.visionWillStartFocus {
            validvisionWillStartFocus(self)
        }

        let focusPoint = CGPoint(x: 0.5, y: 0.5)
        self.focusAtAdjustedPointOfInterest(adjustedPoint: focusPoint)
    }
    
    // focusExposeAndAdjustWhiteBalanceAtAdjustedPoint: will put focus and exposure into auto
    func focusExposeAndAdjustWhiteBalanceAtAdjustedPoint(adjustedPoint: CGPoint) {
        if self.currentDevice.isAdjustingFocus || self.currentDevice.isAdjustingExposure {
            return
        }
        
        do {
            try self.currentDevice.lockForConfiguration()
            
            let isFocusAtPointSupported = self.currentDevice.isFocusPointOfInterestSupported
            let isExposureAtPointSupported = self.currentDevice.isExposurePointOfInterestSupported
            let isWhiteBalanceModeSupported = self.currentDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance)
            
            if isFocusAtPointSupported && self.currentDevice.isFocusModeSupported(.autoFocus) {
                self.currentDevice.focusPointOfInterest = adjustedPoint
                self.currentDevice.focusMode = .autoFocus
            }
            
            if isExposureAtPointSupported && self.currentDevice.isExposureModeSupported(.continuousAutoExposure) {
                self.currentDevice.exposurePointOfInterest = adjustedPoint
                self.currentDevice.exposureMode = .continuousAutoExposure
            }
            
            if isWhiteBalanceModeSupported {
                self.currentDevice.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            
            self.currentDevice.isSubjectAreaChangeMonitoringEnabled = false
            
            self.currentDevice.unlockForConfiguration()
            
        } catch {
            print("error locking device for focus / exposure / white-balance adjustment \(error.localizedDescription)")
        }
    }
    
    // MARK: Capture photo
    
    var canCapturePhoto: Bool {
        let isDiskSpaceAvailable = VisionUtilities.availableStorageSpaceInBytes() > VisionRequiredMinimumDiskSpaceInBytes
        return self.isCaptureSessionActive && !flags.changingModes && isDiskSpaceAvailable
    }
    
    func thumbnail(jpegData: Data) -> UIImage? {
        
        var thumbnailCGImage : CGImage!
        let provider = CGDataProvider(data: jpegData as CFData)
        
        if let validProvider = provider {
            let imageSource = CGImageSourceCreateWithDataProvider(validProvider, nil)
            if let source = imageSource {
                if CGImageSourceGetCount(source) > 0 {
                    var options : [String : Any] = [:]
                    options[kCGImageSourceCreateThumbnailFromImageAlways as String] = true
                    options[kCGImageSourceThumbnailMaxPixelSize as String] = VisionThumbnailWidth
                    options[kCGImageSourceCreateThumbnailWithTransform as String] = true
                    thumbnailCGImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
                }
            }
        }
        
        var thumbnail : UIImage!
        
        if let thumbnailImage = thumbnailCGImage {
            thumbnail = UIImage(cgImage: thumbnailImage)
        }
        
        return thumbnail
    }
    
    func squareImage(image: UIImage, scaledToSize newSize: CGSize) -> UIImage? {
        var ratio : CGFloat = 0.0
        var delta : CGFloat = 0.0
        var offset : CGPoint = CGPoint.zero
        
        if image.size.width > image.size.height {
            ratio = newSize.width / image.size.width
            delta = (ratio * image.size.width) - (ratio * image.size.height)
            offset = CGPoint(x: delta * 0.5, y: 0)
        } else {
            ratio = newSize.width / image.size.height
            delta = (ratio * image.size.height) - (ratio * image.size.width)
            offset = CGPoint(x: 0, y: delta * 0.5)
        }
        
        let clipRect = CGRect(x: -offset.x, y: -offset.y, width: (ratio * image.size.width) + delta, height: (ratio * image.size.height) + delta)
        
        let squareSize = CGSize(width: newSize.width, height: newSize.width)
        
        UIGraphicsBeginImageContextWithOptions(squareSize, true, 0.0)
        UIRectClip(clipRect)
        image.draw(in: clipRect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    func willCapturePhoto() {
        print("will capture photo")
        if let validvisionWillCapturePhoto = self.visionWillCapturePhoto {
            validvisionWillCapturePhoto(self)
        }
        if self.autoFreezePreviewDuringCapture! {
            self.freezePreview()
        }
    }
    
    func didCapturePhoto() {
        if let validvisionDidCapturePhoto = self.visionDidCapturePhoto {
            validvisionDidCapturePhoto(self)
        }
        print("did capture photo")
    }
    
    func capturePhotoFrom(sampleBuffer: CMSampleBuffer!) {
        guard sampleBuffer != nil else {
            return
        }
        
        print("capturing photo from sample buffer")
        
        // create associated data
        let photoDict = NSMutableDictionary()
        var metaData : NSDictionary!
        
        // add any attachments to propagate
        let tiffDict: [String : Any] = [kCGImagePropertyTIFFSoftware as String : "Vision",
                        kCGImagePropertyTIFFDateTime as String : String.visionFormattedTimeStamp(date: Date())
                        ]
        CMSetAttachment(sampleBuffer, kCGImagePropertyTIFFDictionary, tiffDict as CFTypeRef?, kCMAttachmentMode_ShouldPropagate)
        
        // add photo metadata (ie EXIF: Aperture, Brightness, Exposure, FocalLength, etc)
        metaData = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate)
        
        if metaData != nil {
            photoDict[VisionPhotoMetadataKey] = metaData
        } else {
            print("failed to generate metadata for photo")
        }
        
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        var ciImage : CIImage!
        
        if #available(iOS 9.0, *) {
            ciImage = CIImage(cvImageBuffer: imageBuffer!)
        } else {
            // Fallback on earlier versions
            ciImage = CIImage(cvPixelBuffer: imageBuffer!)
        }
        
        // add UIImage
        var image : UIImage? = UIImage(ciImage: ciImage)
        
        if image != nil {
            if self.outputFormat == VisionOutputFormat.square {
                image = self.squareImage(image: image!, scaledToSize: image!.size)
            }
            // VisionOutputFormatWidescreen
            // VisionOutputFormatStandard
            
            photoDict[VisionPhotoImageKey] = image
            
            // add JPEG, thumbnail
            let jpegData = UIImageJPEGRepresentation(image!, 0)
            
            if jpegData != nil {
                // add JPEG
                photoDict[VisionPhotoJPEGKey] = jpegData
                
                // add thumbnail
                if flags.thumbnailEnabled {
                    let thumbnail = self.thumbnail(jpegData: jpegData!)
                    
                    if thumbnail != nil {
                        photoDict[VisionPhotoThumbnailKey] = thumbnail
                    }
                }
            }
            
            self.enqueueBlockOnMainQueue {
                if let validvisioncapturedPhotoCompletion = self.visioncapturedPhotoCompletion {
                    validvisioncapturedPhotoCompletion(self, photoDict, nil)
                }
            }
            
        } else {
            print("failed to create image from JPEG")
            self.enqueueBlockOnMainQueue {
                if let validvisioncapturedPhotoCompletion = self.visioncapturedPhotoCompletion {
                    validvisioncapturedPhotoCompletion(self, photoDict, NSError(domain: "failed to create image from JPEG", code: 500, userInfo: nil))
                }
            }
        }
    }
    
    func processImage(photoSampleBuffer: CMSampleBuffer?, previewSampleBuffer : CMSampleBuffer?, error: Error?) {
        guard error == nil else {
            if let validvisioncapturedPhotoCompletion = self.visioncapturedPhotoCompletion {
                validvisioncapturedPhotoCompletion(self, nil, error)
            }
            return
        }
        
        guard photoSampleBuffer != nil else {
            print("failed to obtain image data sample buffer")
            return
        }
        
        // add any attachments to propagate
        let tiffDict: [String : Any] = [kCGImagePropertyTIFFSoftware as String : "Vision",kCGImagePropertyTIFFDateTime as String : String.visionFormattedTimeStamp(date: Date())]
        
        CMSetAttachment(photoSampleBuffer!, kCGImagePropertyTIFFDictionary, tiffDict as CFTypeRef?, kCMAttachmentMode_ShouldPropagate)
        
        // create associated data
        let photoDict = NSMutableDictionary()
        var metaData : NSDictionary!
        
        // add photo metadata (ie EXIF: Aperture, Brightness, Exposure, FocalLength, etc)
        metaData = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, photoSampleBuffer!, kCMAttachmentMode_ShouldPropagate)
        
        if metaData != nil {
            photoDict[VisionPhotoMetadataKey] = metaData
        } else {
            print("failed to generate metadata for photo")
        }
        
        var jpegData : Data!
        
        if #available(iOS 10.0, *) {
            jpegData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer!, previewPhotoSampleBuffer: previewSampleBuffer)
        } else {
            jpegData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(photoSampleBuffer)
        }
        
        if jpegData != nil {
            // add JPEG
            photoDict[VisionPhotoJPEGKey] = jpegData
            
            // add image
            let image = VisionUtilities.imageFromJpegData(jpegData: jpegData)
            
            if image != nil {
                
                // FIXME: need to change the image size passed when intitalzing Vision
                
                let width = min(self.previewLayer.bounds.size.width, self.previewLayer.bounds.size.height)
//                let width = min(image!.size.width, image!.size.height)
                
                let squareImage = self.squareImage(image: image!, scaledToSize: CGSize(width: width * 2, height: width * 2))
                
                photoDict[VisionPhotoImageKey] = squareImage
            } else {
                print("failed to create image from JPEG")
            }
            
            // add thumbnail
            if flags.thumbnailEnabled {
                let thumbnail = self.thumbnail(jpegData: jpegData)
                if thumbnail != nil {
                    photoDict[VisionPhotoThumbnailKey] = thumbnail
                }
            }
        }
        

        if let validvisioncapturedPhotoCompletion = self.visioncapturedPhotoCompletion {
            validvisioncapturedPhotoCompletion(self, photoDict, nil)
        }
        
        // run a post shot focus
        self.perform(#selector(Vision.adjustFocusExposureAndWhiteBalance), with: nil, afterDelay: 0.5)
    }
    
    func capturePhoto() {
        
        guard self.currentCameraStatus == .ready else {
            return
        }
        
        if !self.canSessionCapture(captureOutput: self.currentOutput) || self.cameraMode != .photo {
            print("session is not setup properly for capture")
//            [self _failPhotoCaptureWithErrorCode:PBJVisionErrorSessionFailed];
            return
        }
        
        let connection = self.currentOutput.connection(withMediaType: AVMediaTypeVideo)
        self.setOrientation(forConnection: connection)
        
        if #available(iOS 10.0, *) {
            let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecJPEG])
            settings.isHighResolutionPhotoEnabled = true
            settings.flashMode = self.capturePhotoSettings.flashMode
            self.captureOutputPhoto?.capturePhoto(with: settings, delegate: self)
        } else {
            self.captureOutputImage.captureStillImageAsynchronously(from: connection, completionHandler: { (imageSampleBuffer, error) in
                self.processImage(photoSampleBuffer: imageSampleBuffer, previewSampleBuffer: nil, error: error)
            })
        }
    }
    
    // MARK: Video
    
    var isSupportsVideoCapture: Bool {
        get {
            return AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo) != nil
        }
    }
    
    var canCaptureVideo: Bool {
        let isDiskSpaceAvailable = VisionUtilities.availableStorageSpaceInBytes() > VisionRequiredMinimumDiskSpaceInBytes
        return self.isSupportsVideoCapture && self.isCaptureSessionActive && !flags.changingModes && isDiskSpaceAvailable
    }
    
    func startVideoCapture() {
        
        if !self.canSessionCapture(captureOutput: self.currentOutput) || self.cameraMode != .video {
            print("session is not setup properly for capture")
//            [self _failVideoCaptureWithErrorCode:PBJVisionErrorSessionFailed];
            return
        }
        
        print("starting video capture")
        
        self.enqueueBlockOnCaptureVideoQueue {
            
            if self.flags.recording || self.flags.paused {
                return
            }
            
            //let uuid  = UIDevice.current.identifierForVendor?.uuidString
            var outputFile : String? = "/video_\(self.fileIndex).mp4"
            self.fileIndex += 1
            
            if let validvisionwillStartVideoCaptureToFile = self.visionwillStartVideoCaptureToFile {
                outputFile = validvisionwillStartVideoCaptureToFile(self, outputFile!)
                
                if outputFile == nil {
                    // FIXME: Need tp handle error
//                    if (!outputFile) {
//                        [self _failVideoCaptureWithErrorCode:PBJVisionErrorBadOutputFile];
//                        return;
//                    }
                }
            }
            
            let outputDirectory = self.captureDirecotry == nil ? NSTemporaryDirectory() : self.captureDirecotry
            let outputPath = outputDirectory?.appending(outputFile!)
            let outputURL = URL(fileURLWithPath: outputPath!)
            
            if FileManager.default.fileExists(atPath: outputPath!) {
                do {
                    try FileManager.default.removeItem(atPath: outputPath!)
                } catch {
                    print("could not setup an output file (file exists) \(error)")
                    return
                }
            }
            
            if outputPath == nil || outputPath?.characters.count == 0 {
                print("could not setup an output file")
                return
            }
            
            if self.mediaWriter != nil {
                self.mediaWriter = nil
            }
            
            self.mediaWriter = MediaWriter(outputUrl: outputURL)
            self.registerMediaWriterCompletionBlocks()
            
            let videoConnection = self.captureOutputVideo.connection(withMediaType: AVMediaTypeVideo)
            self.setOrientation(forConnection: videoConnection)
            
            self.startTimestamp = CMClockGetTime(CMClockGetHostTimeClock())
            self.timeOffset = kCMTimeInvalid
            
            self.flags.recording = true
            self.flags.paused = false
            self.flags.interrupted = false
            self.flags.videoWritten = false
            
            self.captureThumbnailTimes = NSMutableSet()
            self.captureThumbnailFrames = NSMutableSet()
            
            if self.flags.thumbnailEnabled && self.flags.defaultVideoThumbnails {
                self.captureVideoThumbnailAtFrame(frame: 0)
            }
            
            self.enqueueBlockOnMainQueue {
                if let validvisionDidStartVideoCapture = self.visionDidStartVideoCapture {
                    validvisionDidStartVideoCapture(self)
                }
            }
        }
    }
    
    func pauseVideoCapture() {
        self.enqueueBlockOnCaptureVideoQueue {
            guard self.flags.recording else {
                return
            }
            
            guard self.mediaWriter != nil else {
                print("media writer unavailable to stop")
                return
            }
            
            print("pausing video capture")
            
            self.flags.paused = true
            self.flags.interrupted = true
            
            self.enqueueBlockOnMainQueue {
                if let visionDidPauseVideoCapture = self.visionDidPauseVideoCapture {
                    visionDidPauseVideoCapture(self)
                }
            }
        }
    }
    
    func resumeVideoCapture() {
        self.enqueueBlockOnCaptureVideoQueue {
            guard self.flags.recording || self.flags.paused else {
                return
            }
            
            guard self.mediaWriter != nil else {
                print("media wirter unavailable to resume")
                return
            }
            
            print("resuming video capture")
            
            self.flags.paused = false
            
            self.enqueueBlockOnMainQueue {
                if let validvisionDidResumeVideoCapture = self.visionDidResumeVideoCapture {
                    validvisionDidResumeVideoCapture(self)
                }
            }
        }
    }
    
    
    func endVideoCapture() {
        print("ending video capture")
        
        self.enqueueBlockOnCaptureVideoQueue {
            guard self.flags.recording else {
                return
            }
            
            guard self.mediaWriter != nil else {
                print("media writer unavailable to end")
                return
            }
            
            
            if self.capturedVideoSeconds >= self.capturedAudioSeconds {
                self.manualendVideoCapture()
            }
            else {
                self.mediaWriter.endvideoCapturewithvideoFrame = true
            }
            
        }
    }
    
    fileprivate func manualendVideoCapture() {
        self.flags.recording = false
        self.flags.paused = false
        
        loggingPrint("Capture Audio sec :: \(self.capturedAudioSeconds)")
        loggingPrint("Capture Video sec :: \(self.capturedVideoSeconds)")
        
        let finishWritingCompletionHandler : (() -> Void)? = {
            
            let capturedDuration = self.capturedVideoSeconds
            
            self.timeOffset = kCMTimeInvalid
            self.startTimestamp = CMClockGetTime(CMClockGetHostTimeClock())
            self.flags.interrupted = false
            
            self.enqueueBlockOnMainQueue {
                if let validvisionDidEndVideoCapture = self.visionDidEndVideoCapture {
                    validvisionDidEndVideoCapture(self)
                }
                
                let videoDict = NSMutableDictionary()
                let path = self.mediaWriter.outputUrl.path
                
                // For VYBZ only.
                self.totalCapturedDuration += capturedDuration
                
                self.timeOffset = kCMTimeInvalid
                self.startTimestamp = CMClockGetTime(CMClockGetHostTimeClock())
                self.flags.interrupted = false
                videoDict[VisionVideoPathKey] = path
                
                if self.flags.thumbnailEnabled {
                    if self.flags.defaultVideoThumbnails {
                        self.captureVideoThumbnailAtTime(second: capturedDuration)
                    }
                    
                    // FIXME: call generatethumbnail func
                    //                        [self _generateThumbnailsForVideoWithURL:_mediaWriter.outputURL inDictionary:videoDict];
                }
                
                videoDict[VisionVideoCapturedDurationKey] = capturedDuration
                
                let error = self.mediaWriter.error
                if let validvisioncapturedVideoCompletion = self.visioncapturedVideoCompletion {
                    validvisioncapturedVideoCompletion(self, videoDict, error)
                }
            }
        }
        
        self.mediaWriter.finishWriting(completionHandler: finishWritingCompletionHandler)
    }
    
    func cancelVideoCapture() {
        print("cancel video capture")
        
        self.enqueueBlockOnCaptureVideoQueue {
            self.flags.recording = false
            self.flags.paused = false
            
            self.captureThumbnailTimes.removeAllObjects()
            self.captureThumbnailFrames.removeAllObjects()
            
            let finishWritingCompletionHandler : (() -> Void)? = {
                
                self.timeOffset = kCMTimeInvalid
                self.startTimestamp = CMClockGetTime(CMClockGetHostTimeClock())
                self.flags.interrupted = false
                
                self.enqueueBlockOnMainQueue {
                    if let valid = self.visioncapturedVideoCompletion {
                        valid(self,nil,NSError(domain: VisionErrorDomain, code: VisionErrorType.cancelled.rawValue, userInfo: nil))
                    }
                }
            }
            
            self.mediaWriter.finishWriting(completionHandler: finishWritingCompletionHandler)
        }
    }
    
    func captureVideoFrameAsPhoto() {
        self.flags.videoCaptureFrame = true
    }
    
    func captureCurrentVideoThumbnail() {
        if self.flags.recording {
            self.captureVideoThumbnailAtTime(second: self.capturedVideoSeconds)
        }
    }
    
    func captureVideoThumbnailAtTime(second: Float64) {
        self.captureThumbnailTimes.add(second)
    }
    
    func captureVideoThumbnailAtFrame(frame: Int64) {
        self.captureThumbnailFrames.add(frame)
    }
    
    // MARK: Video writer setup
    
    func setupMediaWriterAudioInput(sampleBuffer: CMSampleBuffer) -> Bool {
        
        let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
        let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription!)
        if asbd == nil {
            print("audio stream description used with noon-audio format descrition")
            return false
        }
        
        let channels = Int(asbd!.pointee.mChannelsPerFrame)
        let sampleRate = asbd!.pointee.mSampleRate
        
        print("audio stream setup, channels \(channels) sampleRate \(sampleRate)")
        
        var aclSize : size_t = 0
        
        let currentChannelLayout = CMAudioFormatDescriptionGetChannelLayout(formatDescription!, &aclSize)
        
        let currentChannelLayoutData = (currentChannelLayout != nil && aclSize > 0) ? Data(bytes: currentChannelLayout!, count: aclSize) : Data()
        
        let audioCompressionSettings = [AVFormatIDKey : kAudioFormatMPEG4AAC, AVNumberOfChannelsKey : channels, AVSampleRateKey : sampleRate, AVEncoderBitRateKey : self.audioBitRate!, AVChannelLayoutKey : currentChannelLayoutData] as [String : Any]
        
        return self.mediaWriter.setupAudio(settings: audioCompressionSettings)
    }
    
    func setupMediaWriterVideoInput(sampleBuffer: CMSampleBuffer) -> Bool {
        
        let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription!)
        
        var videoDimensions = dimensions
        
        switch self.outputFormat {
        case .square:
            let minDimension = min(dimensions.width, dimensions.height)
            videoDimensions.width = minDimension
            videoDimensions.height = minDimension
            break
        case .widescreen:
            videoDimensions.width = dimensions.width
            videoDimensions.height = Int32(dimensions.width * 9 / 16)
            break
        case .standard:
            videoDimensions.width = dimensions.width
            videoDimensions.height = Int32(dimensions.width * 3 / 4)
            break
        default:
            break
        }
        
        var compressionSettings : [String : Any]!
        
        if let additionalProperties = self.additionalVideoProperties, additionalProperties.count > 0 {
            var mutableDict = additionalProperties
            mutableDict[AVVideoAverageBitRateKey] = self.videoBitRate
            mutableDict[AVVideoMaxKeyFrameIntervalKey] = self.privateVideoFrameRate
            compressionSettings = mutableDict
        } else {
            compressionSettings = [
                AVVideoAverageBitRateKey : self.videoBitRate,
                AVVideoMaxKeyFrameIntervalKey : self.privateVideoFrameRate
            ]
        }
        
        let videoSettings = [
            AVVideoCodecKey : AVVideoCodecH264,
            AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill,
            AVVideoWidthKey : videoDimensions.width,
            AVVideoHeightKey : videoDimensions.height,
            AVVideoCompressionPropertiesKey : compressionSettings
        ] as [String : Any]
        
        return self.mediaWriter.setupVideo(settings: videoSettings, with: self.additionalVideoProperties)
    }
    
    func automaticallyEndCaptureIfMaximumDurationReached(sampleBuffer : CMSampleBuffer) {
        
        let currentTimestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        if !self.flags.interrupted && self.isRecording && CMTIME_IS_VALID(currentTimestamp) && CMTIME_IS_VALID(self.startTimestamp) && CMTIME_IS_VALID(maximumCaptureDuration) {
            
            let totalDuration = self.totalCapturedDuration + Double(CMTimeGetSeconds(CMTimeSubtract(self.mediaWriter.videoTimeStamp, self.startTimestamp)))
//            print("totalduration \(totalDuration)")
//            print("maximumduration \(CMTimeGetSeconds(self.maximumCaptureDuration))")
            if totalDuration >= CMTimeGetSeconds(self.maximumCaptureDuration) {
                print("totalduration \(totalDuration)")
                print("maximumduration \(CMTimeGetSeconds(self.maximumCaptureDuration))")
                self.enqueueBlockOnMainQueue {
                    self.endVideoCapture()
                }
            }
        }
        
        /*
        if !flags.interrupted && CMTIME_IS_VALID(currentTimestamp) && CMTIME_IS_VALID(self.startTimestamp) && CMTIME_IS_VALID(self.maximumCaptureDuration) {
            if CMTIME_IS_VALID(self.timeOffset) {
                // Current time stamp is actually timstamp with data from globalClock
                // In case, if we had interruption, then _timeOffset
                // will have information about the time diff between globalClock and assetWriterClock
                // So in case if we had interruption we need to remove that offset from "currentTimestamp"
                currentTimestamp = CMTimeSubtract(currentTimestamp, self.timeOffset)
            }
            
            let currentCaptureDuration = CMTimeSubtract(currentTimestamp, self.startTimestamp)
            if CMTIME_IS_VALID(currentCaptureDuration) {
                print("current Capture duration : ",CMTimeGetSeconds(currentCaptureDuration))
                print("maximum capture duration : ",CMTimeGetSeconds(self.maximumCaptureDuration))
                if currentCaptureDuration >= self.maximumCaptureDuration {
                    self.enqueueBlockOnMainQueue {
                        self.endVideoCapture()
                    }
                }
            }
        }
        */
    }
    
    func removeSeconds(seconds: Double) {
        self.totalCapturedDuration -= seconds
        if self.totalCapturedDuration < 0 {
            self.totalCapturedDuration = 0
        }
    }
    
    func clearSeconds() {
        self.totalCapturedDuration = 0.0
    }
    
    // MARK: AVCapturePhotoCaptureDelegate
    
    @available(iOS 10.0, *)
    func capture(_ captureOutput: AVCapturePhotoOutput, willBeginCaptureForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings) {
        self.willCapturePhoto()
    }
    
    @available(iOS 10.0, *)
    func capture(_ captureOutput: AVCapturePhotoOutput, didCapturePhotoForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings) {
        self.didCapturePhoto()
    }
    
    @available(iOS 10.0, *)
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        self.processImage(photoSampleBuffer: photoSampleBuffer, previewSampleBuffer: previewPhotoSampleBuffer, error: error)
    }
    
    // MARK: AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        
        guard CMSampleBufferDataIsReady(sampleBuffer) else {
            print("sample buffer data is not ready")
            return
        }
        
        guard self.flags.recording || self.flags.paused else {
            return
        }
        
        guard self.mediaWriter != nil else {
            return
        }
        
        // setup media writer
        let isVideo = captureOutput == self.captureOutputVideo
        
        if !isVideo && !self.mediaWriter.isAudioReady {
            let _ = self.setupMediaWriterAudioInput(sampleBuffer: sampleBuffer)
            print("ready for audio \(self.mediaWriter.isAudioReady)")
        }
        
        if isVideo && !self.mediaWriter.isVideoReady {
            let _ = self.setupMediaWriterVideoInput(sampleBuffer: sampleBuffer)
            print("ready for video \(self.mediaWriter.isVideoReady)")
        }
        
        let isReadyToRecord = (!self.flags.audioCaptureEnabled || self.mediaWriter.isAudioReady) && self.mediaWriter.isVideoReady
        
        guard isReadyToRecord else {
            return
        }
        
        var currentTimestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        // calculate the length of the interruption and store the offsets
        if self.flags.interrupted {
            guard !isVideo else {
                return
            }
            
            // calculate the appropriate time offset
            if CMTIME_IS_VALID(currentTimestamp) && CMTIME_IS_VALID(self.mediaWriter.audioTimeStamp) {
                if CMTIME_IS_VALID(self.timeOffset) {
                    currentTimestamp = CMTimeSubtract(currentTimestamp, self.timeOffset)
                }
                let offset = CMTimeSubtract(currentTimestamp, self.mediaWriter.audioTimeStamp)
                self.timeOffset = CMTIME_IS_INVALID(self.timeOffset) ? offset : CMTimeAdd(self.timeOffset, offset)
                print("new calculated offset \(CMTimeGetSeconds(self.timeOffset)) valid \(CMTIME_IS_VALID(self.timeOffset))")
            }
            self.flags.interrupted = false
        }
        
        // adjust the sample buffer if there is a time offset
        var bufferToWrite : CMSampleBuffer!
        
        if CMTIME_IS_VALID(self.timeOffset) {
            //CMTime duration = CMSampleBufferGetDuration(sampleBuffer);
            bufferToWrite = VisionUtilities.createOffSet(sampleBuffer, self.timeOffset)
            if bufferToWrite == nil {
                print("error subtrcting the time offset from the samplebuffer")
            }
        } else {
            bufferToWrite = sampleBuffer
        }
    
        // write the sample buffer
        if bufferToWrite != nil && !self.flags.interrupted {
            if self.mediaWriter.endvideoCapturewithvideoFrame {
                if isVideo {
                    self.mediaWriter.write(sampleBuffer: bufferToWrite, withMediaType: isVideo)
                    self.flags.videoWritten = true
                    
                    if self.capturedVideoSeconds >= self.capturedAudioSeconds {
                        self.manualendVideoCapture()
                    }
                }
                return
            }
            
            if isVideo {
                self.mediaWriter.write(sampleBuffer: bufferToWrite, withMediaType: isVideo)
                self.flags.videoWritten = true
                
                // process the sample buffer for rendering onion layer or capturing video photo
                if (self.flags.videoRenderingEnabled || self.flags.videoCaptureFrame) && self.flags.videoWritten {
                    self.enqueueBlockOnMainQueue {
                        // FIXME: need to call process sample buffer func
//                        [self _processSampleBuffer:bufferToWrite];
                        
                        if self.flags.videoCaptureFrame {
                            self.flags.videoCaptureFrame = false
                            self.willCapturePhoto()
                            self.capturePhotoFrom(sampleBuffer: bufferToWrite)
                            self.didCapturePhoto()
                        }
                    }
                }
                
                if let validvisiondidCaptureVideoSampleBuffer = self.visiondidCaptureVideoSampleBuffer {
                    validvisiondidCaptureVideoSampleBuffer(self, bufferToWrite)
                }
                
            } else if bufferToWrite != nil && self.flags.videoWritten {
                self.mediaWriter.write(sampleBuffer: bufferToWrite, withMediaType: isVideo)
                
                self.enqueueBlockOnMainQueue {
                    if let validvisiondidCaptureAudioSample = self.visiondidCaptureAudioSample {
                        validvisiondidCaptureAudioSample(self, bufferToWrite)
                    }
                }
            }
        }
        
        self.automaticallyEndCaptureIfMaximumDurationReached(sampleBuffer: sampleBuffer)
    }
    
    // MARK: App Notifications
    
    func applicationWillEnterForeground(notification: NSNotification) {
        print("application will enter foreground")
        self.enqueueBlockOnCaptureSessionQueue {
            if !self.flags.previewRunning {
                return
            }
            
            self.enqueueBlockOnMainQueue {
                self.startPreview()
            }
        }
    }
    
    func applicationDidEnterBackground(notification: NSNotification) {
        print("application did enter background")
        
        if self.flags.recording {
            self.pauseVideoCapture()
        }
        
        if self.flags.previewRunning {
            self.stopPreivew()
            self.enqueueBlockOnCaptureSessionQueue {
                self.flags.previewRunning = true
            }
        }
    }
    
    // MARK: Session notification methods
    
    func sessionRuntimeErrored(notification: Notification) {
        self.enqueueBlockOnCaptureSessionQueue {
            
            if (notification.object as! AVCaptureSession) == self.captureSession! {
                let error : AVError? = notification.userInfo?[AVCaptureSessionErrorKey] as! AVError?
                if let err = error {
                    switch err.code {
                    case .mediaServicesWereReset:
                        print("error media services were reset")
                        self.destroyCamera()
                        if self.flags.previewRunning {
                            self.startPreview()
                        }
                        break
                    case .deviceIsNotAvailableInBackground:
                        print("error media services not available in background")
                        break
                    default:
                        print("error media services failed, error \(error)")
                        self.destroyCamera()
                        if self.flags.previewRunning {
                            self.startPreview()
                        }
                        break
                    }
                }
            }
        }
    }
    
    func sessionStarted(notification: Notification) {
        self.enqueueBlockOnMainQueue {
            guard (notification.object as! AVCaptureSession) != self.captureSession! else {
                return
            }
            
            print("session was started")
            
            // ensure there is a capture device setup
            
            if self.currentInput != nil {
                let device = self.currentInput.device
                if device != nil {
                    self.willChangeValue(forKey: "currentDevice")
                    self.currentDevice = device
                    self.didChangeValue(forKey: "currentDevice")
                }
            }
            
            if let validVisionSessionDidStart = self.visionSessionDidStart {
                validVisionSessionDidStart(self)
            }
        }
    }
    
    func sessionStopped(notification: Notification) {
        self.enqueueBlockOnCaptureSessionQueue {
            guard (notification.object as! AVCaptureSession) != self.captureSession! else {
                return
            }
            
            print("session was stopped")
            
            if self.flags.recording {
                self.endVideoCapture()
            }
            
            self.enqueueBlockOnMainQueue {
                if let validVisionSessionDidStop = self.visionSessionDidStop {
                    validVisionSessionDidStop(self)
                }
            }
        }
    }
    
    func sessionWasInterrupted(notification: Notification) {
        self.enqueueBlockOnMainQueue {
            guard (notification.object as! AVCaptureSession) != self.captureSession! else {
                return
            }
            
            print("session was interrupted")
            
            if self.flags.recording {
                self.enqueueBlockOnMainQueue {
                    if let validVisionSessionDidStop = self.visionSessionDidStop {
                        validVisionSessionDidStop(self)
                    }
                }
            }
            
            self.enqueueBlockOnMainQueue {
                if let validVisionSessionWasInterrupted = self.visionSessionWasInterrupted {
                    validVisionSessionWasInterrupted(self)
                }
            }
        }
    }
    
    func sessionInterruptionEnded(notification: Notification) {
        self.enqueueBlockOnMainQueue {
            guard (notification.object as! AVCaptureSession) != self.captureSession! else {
                return
            }
            
            print("session interruption ended")
            
            
            self.enqueueBlockOnMainQueue {
                if let validVisionSessionInterruptionEnded = self.visionSessionInterruptionEnded {
                    validVisionSessionInterruptionEnded(self)
                }
            }
        }
    }
    
    func inputPortFormatDescriptionDidChange(notification: Notification) {
        // when the input format changes, store the clean aperture
        // (clean aperture is the rect that represents the valid image data for this display)
        let inputPort = notification.object as? AVCaptureInputPort
        if inputPort != nil {
            let formatDescription = inputPort?.formatDescription
            if formatDescription != nil {
                self.cleanAperture = CMVideoFormatDescriptionGetCleanAperture(formatDescription!, true)
                if let validVisisonDidChangeCleanAperture = self.visiondidChangeCleanAperture {
                    validVisisonDidChangeCleanAperture(self, self.cleanAperture!)
                }
            }
        }
    }
    
    func deviceSubjectAreaDidChange(notification: Notification) {
        self.adjustFocusExposureAndWhiteBalance()
    }
    
    // MARK: KVO
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if context == &VisionFocusObserverContext {
            let isFocusing = change?[NSKeyValueChangeKey.newKey] as! Bool
            if isFocusing {
                self.focusStarted()
            } else {
                self.focusEnded()
            }
        } else if context == &VisionExposureObserverContext {
            let isChangingExposure = change?[NSKeyValueChangeKey.newKey] as! Bool
            if isChangingExposure {
                self.exposureChangeStarted()
            } else {
                self.exposureChangeEnded()
            }
        } else if context == &VisionWhiteBalanceObserverContext {
            let isWhiteBalanceChanging = change?[NSKeyValueChangeKey.newKey] as! Bool
            if isWhiteBalanceChanging {
                self.whiteBalanceChangeStarted()
            } else {
                self.whiteBalanceChangeEnded()
            }
        } else if context == &VisionFlashAvailabilityObserverContext ||
            context == &VisionTorchAvailabilityObserverContext {
            
            print("flash/torch availability did change")
            self.enqueueBlockOnMainQueue {
                if let validVisionDidChangeFlashAvailablility = self.visionDidChangeFlashAvailablility {
                    validVisionDidChangeFlashAvailablility(self)
                }
            }
        } else if context == &VisionFlashModeObserverContext ||
            context == &VisionTorchModeObserverContext {
            
            print("flash/torch mode did change")
            self.enqueueBlockOnMainQueue {
                if let validVisionDidChangeFlashMode = self.visionDidChangeFlashMode {
                    validVisionDidChangeFlashMode(self)
                }
            }
        } else if context == &VisionCaptureStillImageIsCapturingStillImageObserverContext {
            let isCapturingStillImage = change?[NSKeyValueChangeKey.newKey] as! Bool
            if isCapturingStillImage {
                self.willCapturePhoto()
            } else {
                self.didCapturePhoto()
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    func registerMediaWriterCompletionBlocks() {
        
        self.mediaWriter.mediaWriterDidAudioAuthorizationDenied = { writer in
            self.enqueueBlockOnMainQueue {
                if let valid = self.visionDidChangeAuthorizationStatus {
                    valid(VisionAuthorizationStatus.audioDenied)
                }
            }
        }
        
        self.mediaWriter.mediaWriterDidVideoAuthorizationDenied = { writer in
            
        }
    }
    
    // MARK: Queue Helper
    
    private typealias VisionBlock = () -> Void
    
    private func enqueueBlockOnCaptureSessionQueue(block: @escaping VisionBlock) {
        self.captureSessionDispatchQueue.async {
            block()
        }
    }
    
    private func enqueueBlockOnCaptureVideoQueue(block: @escaping VisionBlock) {
        self.captureCaptureDispatchQueue.async {
            block()
        }
    }
    
    private func enqueueBlockOnMainQueue(block: @escaping VisionBlock) {
        DispatchQueue.main.async {
            block()
        }
    }
    
    private func executeBlockOnMainQueue(block: @escaping VisionBlock) {
        DispatchQueue.main.async {
            block()
        }
    }
    
    private func commitBlock(block: @escaping VisionBlock) {
        self.captureSession.beginConfiguration()
        block()
        self.captureSession.commitConfiguration()
    }
}
