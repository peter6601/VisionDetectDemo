//
//  ViewController.swift
//  VisionDetectDemo
//
//  Created by 丁暐哲 on 2018/11/12.
//  Copyright © 2018 PeterDinDin. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {
    
    @IBOutlet weak var tapButton: UIButton!
    @IBOutlet weak var screenView: UIView!
    let stillImageOutput = AVCaptureStillImageOutput()
    var session: AVCaptureSession!
    var request  = [VNRequest]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setSession()
        imageOutput()
        setFace()
        tapButton.addTarget(self, action: #selector(saveImgae), for: .touchUpInside)
    }
    
    func setSession() {
        session = AVCaptureSession()
        //
        session.sessionPreset = AVCaptureSession.Preset.photo
        
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            return
        }
        
        guard let deviceInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            return
        }
        let deviceOutput = AVCaptureVideoDataOutput()
        
        deviceOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        deviceOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .default))
        session.addInput(deviceInput)
        session.addOutput(deviceOutput)
        
        let imageLayer = AVCaptureVideoPreviewLayer(session: session)
        imageLayer.frame = self.view.bounds
        self.screenView.layer.addSublayer(imageLayer)
        session.startRunning()
    }
    
    func imageOutput() {
        stillImageOutput.outputSettings = [AVVideoCodecKey:AVVideoCodecType.jpeg]
        if session.canAddOutput(stillImageOutput) {
            session.addOutput(stillImageOutput)
        }
    }
    
    func setFace() {
        let faceRequest = VNDetectFaceRectanglesRequest { (request, error) in
            guard let content = request.results else {
                return
            }
            let result = content.map{$0 as? VNFaceObservation}
            
            DispatchQueue.main.async {
                self.screenView.subviews.map{$0.removeFromSuperview()}
                self.screenView.layer.sublayers?.removeSubrange(1...)
                for region in result {
                    guard let _result = region else {
                        continue
                    }
                    self.hightlightFace(object: _result)
                }
            }
        }
        
        //        textRequest.reportCharacterBoxes = true
        self.request = [faceRequest]
    }
    
    func setText() {
        let textRequest = VNDetectTextRectanglesRequest { (request, error) in
            guard let content = request.results else {
                return
            }
            let result = content.map{$0 as? VNTextObservation}
            
            DispatchQueue.main.async {
                self.screenView.layer.sublayers?.removeSubrange(1...)
                for region in result {
                    guard let _result = region else {
                        continue
                    }
                    self.hightlightWords(text: _result)
                }
            }
        }
        textRequest.reportCharacterBoxes = true
        self.request = [textRequest]
    }
    
    func hightlightWords(text: VNTextObservation) {
        
        var maxX: CGFloat = 999
        var minX: CGFloat = 0
        var maxY: CGFloat = 999
        var minY: CGFloat = 0
        guard let boxes = text.characterBoxes else {
            return
        }
        
        for char in boxes {
            if char.bottomLeft.x < maxX {
                maxX = char.bottomLeft.x
            }
            if char.bottomRight.x > minX {
                minX = char.bottomRight.x
            }
            if char.bottomRight.y < maxY {
                maxY = char.bottomRight.y
            }
            if char.topRight.y > minY {
                minY = char.topRight.y
            }
        }
        
        let xCord = maxX * self.view.frame.size.width
        let yCord = (1 - minY) * self.view.frame.size.height
        let width = (minX - maxX) * self.view.frame.size.width
        let height = (minY - maxY) * self.view.frame.size.height
        
        let outline = CALayer()
        outline.frame = CGRect(x: xCord, y: yCord, width: width, height: height)
        outline.borderWidth = 2.0
        outline.borderColor = UIColor.red.cgColor
        
        self.screenView.layer.addSublayer(outline)
        
    }
    
    func hightlightFace(object: VNFaceObservation) {
        
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -self.view.frame.height)
        let scale = CGAffineTransform.identity.scaledBy(x: self.view.frame.width, y: self.view.frame.height)
        let facebounds = object.boundingBox.applying(scale).applying(transform)
        
        //        let outline = CAShapeLayer()
        //        outline.frame = facebounds
        //        outline.cornerRadius = 10
        //        outline.borderColor = UIColor.yellow.cgColor
        //        outline.borderWidth = 3
        //        self.view.layer.addSublayer(outline)
        
        let image = UIImage(named: "han")
        let imageView = UIImageView(image: image)
        imageView.frame = facebounds
        self.screenView.addSubview(imageView)
        
    }
    
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        var requestOptions:[VNImageOption : Any] = [:]
        
        if let camData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) {
            requestOptions = [.cameraIntrinsics:camData]
        }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: CGImagePropertyOrientation(rawValue: 6)! , options: requestOptions)
        
        do {
            try imageRequestHandler.perform(self.request)
        } catch {
            print(error)
        }
    }
}

extension ViewController {
    
    @objc func saveImgae(_ sender: UIButton) {
        if let videoConnection = stillImageOutput.connection(with: AVMediaType.video) {
            stillImageOutput.captureStillImageAsynchronously(from: videoConnection) { (buffer, error) in
         
                
                guard let _buffer = buffer else {
                    return
                }
                guard let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(_buffer) else {
                    return
                }
                guard let img = UIImage(data: imageData) else {
                    return
                }
                
                let layer = UIApplication.shared.keyWindow!.layer
                let scale = UIScreen.main.scale
                UIGraphicsBeginImageContextWithOptions(layer.frame.size, false, scale)
                guard let context = UIGraphicsGetCurrentContext() else {return }
                layer.render(in:context)
                
                guard let screenshotImage = UIGraphicsGetImageFromCurrentImageContext() else {
                    return
                }
//                UIGraphicsBeginImageContext(img.size)
                img.draw(in: CGRect(x: 0, y: 0, width: layer.frame.size.width, height: layer.frame.size.height))
             screenshotImage.draw(in: CGRect(x: 0, y: 0, width: layer.frame.size.width, height: layer.frame.size.height), blendMode: .multiply, alpha: 1)
         
//                UIGraphicsEndImageContext()
                
                guard let newImage:UIImage = UIGraphicsGetImageFromCurrentImageContext() else  {
                    return
                }
                UIGraphicsEndImageContext()
                UIImageWriteToSavedPhotosAlbum(newImage, nil, nil, nil)
                
            }
            
            //                UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
        }
        
        //
        //        guard let img = takeScreenshot() else {
        //            return
        //        }
        //        let imgView = UIImageView(image: img)
        //        save(image: imgView)
    }
    
    func takeScreenshot(_ shouldSave: Bool = true) -> UIImage? {
        var screenshotImage :UIImage?
        let layer = UIApplication.shared.keyWindow!.layer
        let scale = UIScreen.main.scale
        UIGraphicsBeginImageContextWithOptions(layer.frame.size, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else {return nil}
        layer.render(in:context)
        screenshotImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        if let image = screenshotImage, shouldSave {
            
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
        return screenshotImage
    }
    
    func save(image content:UIImageView) {
        UIGraphicsBeginImageContext(content.frame.size)
        if let context = UIGraphicsGetCurrentContext() {
            content.layer.render(in: context)
            let output = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            if let qrcodeImg = output {
                UIImageWriteToSavedPhotosAlbum(qrcodeImg, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
            }
        }
    }
    @objc func image(_ image:UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        DispatchQueue.main.async(execute: {() -> Void in
            if let _ = error {
                print("error")
            } else {
                print("success")
            }
        })
    }
}

