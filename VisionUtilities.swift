//
//  VisionUtilities.swift
//  PBJSwiftDemo
//
//  Created by Bhautik Ziniya on 4/20/17.
//  Copyright © 2017 Agile Infoways. All rights reserved.
//

import UIKit
import Foundation
import AVFoundation
import ImageIO

class VisionUtilities: NSObject {

    static func captureDeivce(position: AVCaptureDevicePosition) -> AVCaptureDevice? {
        if #available(iOS 10.0, *) {
            let device = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: position)
            return device
        } else {
            // Fallback on earlier versions
            let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as? [AVCaptureDevice]
            if devices != nil {
                for device in devices! {
                    if device.position == position {
                        return device
                    }
                }
            }
            return nil
        }
    }
    
    static var audioDeice: AVCaptureDevice? {
        return AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
    }
    
    static func connection(mediaType: String, fromConnections connections: [AVCaptureConnection]) -> AVCaptureConnection? {
        for connection in connections {
            for port in connection.inputPorts {
                if (port as! AVCaptureInputPort).mediaType == mediaType {
                    return connection
                }
            }
        }
        
        return nil
    }
    
    static func createOffSet(_ sampleBuffer : CMSampleBuffer,_ timeOffset : CMTime) -> CMSampleBuffer? {
        var count: CMItemCount = 0
        CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, 0, nil, &count);
        
        var info = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(duration: CMTimeMake(0, 0), presentationTimeStamp: CMTimeMake(0, 0), decodeTimeStamp: CMTimeMake(0, 0)), count: count)
        CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, count, &info, &count);
        
        for i in 0..<count {
            info[i].decodeTimeStamp = CMTimeSubtract(info[i].decodeTimeStamp, timeOffset);
            info[i].presentationTimeStamp = CMTimeSubtract(info[i].presentationTimeStamp, timeOffset);
        }
        
        var out: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(nil, sampleBuffer, count, &info, &out);
        return out!
    }
    
    static func angleOffsetFromPortraitOrientationToOrientation(orientation : AVCaptureVideoOrientation) -> CGFloat {
        var angle: CGFloat = 0.0
        switch orientation {
        case .portraitUpsideDown:
            angle = CGFloat(M_PI)
        case .landscapeRight:
            angle = -CGFloat(M_PI_2)
        case .landscapeLeft:
            angle = CGFloat(M_PI_2)
        default:
            break
        }
        
        return angle
    }
    
    static func imageFromJpegData(jpegData: Data) -> UIImage? {
        var jpegCGImage : CGImage!
        let provider = CGDataProvider(data: jpegData as CFData)
        
        var imageOrientation = UIImageOrientation.up
        
        if let validProvider = provider {
            let imageSource = CGImageSourceCreateWithDataProvider(validProvider, nil)
            if let source = imageSource {
                if CGImageSourceGetCount(source) > 0 {
                    
                    jpegCGImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
                    
                    // extract the cgImage properties
                    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                    
                    if properties != nil {
                        // set orientation
 
                        if let orientationProperty = CFDictionaryGetValue(properties, Unmanaged.passUnretained(kCGImagePropertyOrientation).toOpaque()) {
                            let exifOrientation = Unmanaged<NSNumber>.fromOpaque(orientationProperty).takeUnretainedValue()
                            imageOrientation = VisionUtilities.imageOrientationFromExifOrientation(exifOrientation: exifOrientation)
                        }
                    }
                }
            }
        }
        
        var image : UIImage!
        
        if jpegCGImage != nil {
            image = UIImage(cgImage: jpegCGImage, scale: 1.0, orientation: imageOrientation)
        }
        
        return image
    }
    
    static func imageOrientationFromExifOrientation(exifOrientation: NSNumber) -> UIImageOrientation {
        var imageOrientation = UIImageOrientation.up
        
        switch exifOrientation {
        case 2:
            imageOrientation = .upMirrored
            break
        case 3:
            imageOrientation = .down
            break
        case 4:
            imageOrientation = .downMirrored
            break
        case 5:
            imageOrientation = .leftMirrored
            break
        case 6:
            imageOrientation = .right
            break
        case 7:
            imageOrientation = .rightMirrored
            break
        case 8:
            imageOrientation = .left
            break
        case 1:
            break
        default:
            break
        }
        
        return imageOrientation
    }
    
    // MARK: Check available storage
    
    static func availableStorageSpaceInBytes() -> UInt64 {
        var freeSize: UInt64 = 0
        
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        var attributes: [FileAttributeKey : Any]!
        
        do {
            attributes = try FileManager.default.attributesOfFileSystem(forPath: paths.last!)
        } catch {
            print(error)
        }
        
        if let attributes = attributes {
            let freeFileSystemSizeInBytes = attributes[.systemFreeSize]
            if let freeFileSystemSize = freeFileSystemSizeInBytes {
                freeSize = freeFileSystemSize as! UInt64
            }
        }
        
        return freeSize
    }
}

extension String {
    static func visionFormattedTimeStamp(date: Date) -> String {
        let dateFormatter = DateFormatter()
        
        dateFormatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'SSS'Z'"
        dateFormatter.locale = NSLocale.autoupdatingCurrent
        return dateFormatter.string(from: date)
    }
}
