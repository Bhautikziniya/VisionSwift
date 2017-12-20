//
//  MediaWriter.swift
//  PBJSwiftDemo
//
//  Created by Bhautik Ziniya on 4/20/17.
//  Copyright © 2017 Agile Infoways. All rights reserved.
//

import UIKit
import AVFoundation
import Foundation
import MobileCoreServices

typealias MediaWriteAuthorizationStatusCompletion = (MediaWriter) -> Void

class MediaWriter: NSObject {

    var mediaWriterDidAudioAuthorizationDenied: MediaWriteAuthorizationStatusCompletion?
    var mediaWriterDidVideoAuthorizationDenied: MediaWriteAuthorizationStatusCompletion?
    
    var assetWriter: AVAssetWriter!
    var assetWriterAudioInput: AVAssetWriterInput!
    var assetWriterVideoInput: AVAssetWriterInput!
    var endvideoCapturewithvideoFrame: Bool = false
    
    var outputUrl: URL!
    
    var audioTimeStamp: CMTime!
    var videoTimeStamp: CMTime!
    
    // Getonly Properties
    
    var isAudioReady: Bool {
        get {
            let audioAuthorizationStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeAudio)
            
            let isAudioNotAuthorized = audioAuthorizationStatus == .notDetermined || audioAuthorizationStatus == .denied
            
            let isAudioSetup = assetWriterAudioInput != nil || isAudioNotAuthorized
            
            return isAudioSetup
        }
    }
    
    var isVideoReady: Bool {
        get {
            
            let videoAuthorizationStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
            
            let isVideoNotAuthorized = videoAuthorizationStatus == .notDetermined || videoAuthorizationStatus == .denied
            
            let isVideoSetup = assetWriterVideoInput != nil || isVideoNotAuthorized
            
            return isVideoSetup
        }
    }
    
    var error: Error? {
        get {
            return assetWriter.error
        }
    }
    
    // MARK: Init
    
    convenience init(outputUrl: URL) {
        self.init()
        
        do {
            self.assetWriter = try AVAssetWriter(url: outputUrl, fileType: kUTTypeQuickTimeMovie as String)
        } catch {
            print("Assetwriter error : \(error)")
        }
        
        self.outputUrl = outputUrl
        
        self.assetWriter.shouldOptimizeForNetworkUse = true
        // FIXME: creation date remaining for metadataarray
        self.assetWriter.metadata = self.metaDataArray()
        
        self.audioTimeStamp = kCMTimeInvalid
        self.videoTimeStamp = kCMTimeInvalid
        
        // ensure authorization is permitted, if not already prompted
        // it's possible to capture video without audio or audio without video
        
        if AVCaptureDevice.responds(to: #selector(AVCaptureDevice.authorizationStatus(forMediaType:))) {
            
            let audioAuthorizationStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeAudio)
            
            if audioAuthorizationStatus == .notDetermined || audioAuthorizationStatus == .denied {
                if let validHandler = self.mediaWriterDidAudioAuthorizationDenied, audioAuthorizationStatus == .denied {
                    // FIXME: need to call delegate or block.
                    validHandler(self)
                }
            }
            
            let videoAuthorizationStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
            
            if videoAuthorizationStatus == .notDetermined || videoAuthorizationStatus == .denied {
                if let validHandler = self.mediaWriterDidVideoAuthorizationDenied, videoAuthorizationStatus == .denied {
                    // FIXME: need to call delegate or block.
                    validHandler(self)
                }
            }
        }
        
        print("Prepared to write : \(outputUrl)")
    }
    
    // MARK: Private
    
    fileprivate func metaDataArray() -> [AVMetadataItem] {
        
        let currentDevice = UIDevice.current
        
        // device model
        let modelItem = AVMutableMetadataItem()
        modelItem.keySpace = AVMetadataKeySpaceCommon
        modelItem.key = AVMetadataCommonKeyModel as (NSCopying & NSObjectProtocol)?
        modelItem.value = currentDevice.localizedModel as (NSCopying & NSObjectProtocol)?
        
        // software
        let softwareItem = AVMutableMetadataItem()
        softwareItem.keySpace = AVMetadataKeySpaceCommon
        softwareItem.key = AVMetadataCommonKeySoftware as (NSCopying & NSObjectProtocol)?
        softwareItem.value = "visionSwift" as (NSCopying & NSObjectProtocol)?
        
        // creation date
        let creationDate = AVMutableMetadataItem()
        creationDate.keySpace = AVMetadataKeySpaceCommon
        creationDate.key = AVMetadataCommonKeyCreationDate as (NSCopying & NSObjectProtocol)?
        creationDate.value = String.visionFormattedTimeStamp(date: Date()) as (NSCopying & NSObjectProtocol)?
        
        return [modelItem, softwareItem, creationDate]
    }
    
    // MARK: Setup
    
    func setupAudio(settings: [String : Any]?) -> Bool {
        
        if self.assetWriterAudioInput == nil && self.assetWriter.canApply(outputSettings: settings, forMediaType: AVMediaTypeAudio) {
            self.assetWriterAudioInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: settings)
            self.assetWriterAudioInput.expectsMediaDataInRealTime = true
            
            if self.assetWriterAudioInput != nil && self.assetWriter.canAdd(self.assetWriterAudioInput) {
                self.assetWriter.add(self.assetWriterAudioInput!)
                
                print("setup audio input with settings: sampleRate \(settings![AVSampleRateKey]), channels \(settings![AVNumberOfChannelsKey]), bitRate \(settings![AVEncoderBitRateKey])")
            } else {
                print("couldn't add asset writer audio input")
            }
        } else {
            self.assetWriterAudioInput = nil
            print("couldn't apply audio output settings")
        }
        
        return self.isAudioReady
    }
    
    func setupVideo(settings: [String : Any]?, with additionalSettings: [String : Any]?) -> Bool {
        if self.assetWriterVideoInput == nil && self.assetWriter.canApply(outputSettings: settings, forMediaType: AVMediaTypeVideo) {
            
            self.assetWriterVideoInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: settings)
            self.assetWriterVideoInput.expectsMediaDataInRealTime = true
            self.assetWriterVideoInput.transform = CGAffineTransform.identity
            
            
            if let settings = additionalSettings {
                // FIXME: check for addition settings
                let angle = settings[VisionVideoRotation]
                if let validAngle = angle {
                    self.assetWriterVideoInput.transform = CGAffineTransform(rotationAngle: validAngle as! CGFloat)
                }
//                NSNumber *angle = additional[PBJVisionVideoRotation];
//                if (angle) {
//                    _assetWriterVideoInput.transform = CGAffineTransformMakeRotation([angle floatValue]);
//                }
            }
            
            if self.assetWriterVideoInput != nil && self.assetWriter.canAdd(self.assetWriterVideoInput) {
                self.assetWriter.add(self.assetWriterVideoInput)
                
                let videoCompressionProperties = settings?[AVVideoCompressionPropertiesKey] as? [String : Any]
                if let properties = videoCompressionProperties {
                    print("setup video with compression settings bps \(properties[AVVideoAverageBitRateKey]), frameInterval \(properties[AVVideoMaxKeyFrameIntervalKey])")
                } else {
                    print("setup video")
                }
            } else {
                print("couldn't add asset writer video input")
            }
        } else {
            self.assetWriterVideoInput = nil
            print("couldn't apply video output settings")
        }
        
        return self.isVideoReady
    }
    
    // MARK: Sample buffer writing
    
    func write(sampleBuffer: CMSampleBuffer, withMediaType isVideo: Bool) {
        
        guard CMSampleBufferDataIsReady(sampleBuffer) else {
            return
        }
        
        // setup the writer
        if self.assetWriter.status == .unknown {
            if self.assetWriter.startWriting() {
                let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                self.assetWriter.startSession(atSourceTime: timestamp)
                print("started writing with status \(self.assetWriter.status)")
            } else {
                print("error when starting to write \(self.assetWriter.error)")
                return
            }
        }
        
        // check for completion state
        if self.assetWriter.status == .failed {
            print("writer failure \(self.assetWriter.error?.localizedDescription)")
            return
        }
        
        if self.assetWriter.status == .cancelled {
            print("writer cancelled")
            return
        }
        
        if self.assetWriter.status == .completed {
            print("writer finished and completed")
            return
        }
        
        // perform write
        if self.assetWriter.status == .writing {
            var timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let duration = CMSampleBufferGetDuration(sampleBuffer)
            if duration.value > 0 {
                timestamp = CMTimeAdd(timestamp, duration)
            }
            
            if isVideo {
                if self.assetWriterVideoInput.isReadyForMoreMediaData {
                    if self.assetWriterVideoInput.append(sampleBuffer) {
                        self.videoTimeStamp = timestamp
                    } else {
                        print("writer error appending video \(self.assetWriter.error)")
                    }
                }
            } else {
                if self.assetWriterAudioInput.isReadyForMoreMediaData {
                    if self.assetWriterAudioInput.append(sampleBuffer) {
                        self.audioTimeStamp = timestamp
                    } else {
                        print("writer error appending audio \(self.assetWriter.error)")
                    }
                }
            }
        }
    }
    
    func finishWriting(completionHandler: (() -> Void)?) {
        
        if self.assetWriter.status == .unknown || self.assetWriter.status == .completed {
            print("asset write was in an unexpected state \(self.assetWriter.status)")
            return
        }
        
        self.assetWriterVideoInput.markAsFinished()
        if self.assetWriterAudioInput != nil { // Means Audio Pemission Grandted
            self.assetWriterAudioInput.markAsFinished()
        }
        
        if let validHandler = completionHandler {
            self.assetWriter.finishWriting {
                validHandler()
            }
        }
    }
}
