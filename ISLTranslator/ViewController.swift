//
//  ViewController.swift
//  ISL Translator
//
//  Created by Michael Slattery on 26/09/2018.
//  Copyright © 2018 Michael Slattery. All rights reserved.
//

import AVKit

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet private weak var label: UILabel!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var buttonImage: UIImageView!
    @IBOutlet private weak var topLabel: UILabel!
    @IBOutlet private weak var midLabel: UILabel!
    @IBOutlet private weak var lowLabel: UILabel!
    
    private var isRecording = false
    private var previousLabel = ""
    private var isCorrect = 0
    
    lazy var cameraSession: AVCaptureSession = {
        
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high
        return captureSession
    }()
    
    lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let preview =  AVCaptureVideoPreviewLayer(session: self.cameraSession)
        preview.bounds = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height)
        preview.position = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
        preview.videoGravity = AVLayerVideoGravity.resize
        return preview
    }()
    
    var model = retrained_graph()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupButtonImage()
        
        let captureDevice = AVCaptureDevice.default(for: .video)!
        
        do {
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            
            cameraSession.beginConfiguration()
            
            if (cameraSession.canAddInput(deviceInput) == true) {
                cameraSession.addInput(deviceInput)
            }
            
            let dataOutput = AVCaptureVideoDataOutput()
            
            dataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange as UInt32)] as [String : Any]
            
            dataOutput.alwaysDiscardsLateVideoFrames = true
            
            if (cameraSession.canAddOutput(dataOutput) == true) {
                cameraSession.addOutput(dataOutput)
            }
            
            cameraSession.commitConfiguration()
            
            let queue = DispatchQueue(label: "com.imageProcessing.Queue")
            dataOutput.setSampleBufferDelegate(self, queue: queue)
            
        }
        catch let error as NSError {
            NSLog("\(error), \(error.localizedDescription)")
        }
    }

    override var shouldAutorotate: Bool {
        return false
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        imageView.layer.addSublayer(previewLayer)
        
        cameraSession.startRunning()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func setupButtonImage() {
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(buttonImageTapped(tapGestureRecognizer:)))
        buttonImage.isUserInteractionEnabled = true
        buttonImage.addGestureRecognizer(tapGestureRecognizer)
        
    }
    
    @objc private func buttonImageTapped(tapGestureRecognizer: UITapGestureRecognizer) {
        
        guard let tappedImage = tapGestureRecognizer.view as? UIImageView else { return }
        
        isRecording = !isRecording
        
        tappedImage.image = isRecording ? UIImage(named: "pauseButton") : UIImage(named: "playButton")
        
        //clears the text after play
        label.text = isRecording ? "" : label.text
    }
    
    private func showTopThree(_ output: [String: Double]?) {
        
        guard let output = output else { return }
        
        var topLabelString = ""
        var midLabelString = ""
        var lowLabelString = ""
        
        var topPercentage: Double = 0
        var midPercentage: Double = 0
        var lowPercentage: Double = 0
        
        for dictionary in output {
            
            if dictionary.value > topPercentage {
                
                topLabelString = dictionary.key
                topPercentage = (dictionary.value).truncate(places: 2)
            } else if dictionary.value < topPercentage && dictionary.value > midPercentage {
                
                midLabelString = dictionary.key
                midPercentage = (dictionary.value).truncate(places: 2)
            } else if dictionary.value < midPercentage && dictionary.value > lowPercentage {
                
                lowLabelString = dictionary.key
                lowPercentage = (dictionary.value).truncate(places: 2)
            }
        }
        
        topLabel.text = topLabelString + " " + String(topPercentage)
        midLabel.text = midLabelString + " " + String(midPercentage)
        lowLabel.text = lowLabelString + " " + String(lowPercentage)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection){
        
        connection.videoOrientation = .portrait
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            
            let ciImage = CIImage(cvImageBuffer: imageBuffer)
            let img = UIImage(ciImage: ciImage).resizeTo(CGSize(width: 224, height: 224))
            if let uiImage = img?.noir, let pixelBuffer = uiImage.buffer() {
                
                let output = try? model.prediction(input__0: pixelBuffer)
                DispatchQueue.main.async {
                    
                    self.imageView.image = uiImage
                    
                    if self.isRecording {
                        
                        guard let label = output?.classLabel, let percentage = output?.final_result__0[label] else { return }
                        
                        self.showTopThree(output?.final_result__0)
                        
                        if self.isCorrect == 5 {
                            
                            self.label.text?.append(percentage > 0.7 ? label : "")
                            self.isCorrect += 1
                        } else if label == self.previousLabel{
                            
                            self.isCorrect += 1
                        } else {
                            
                            self.isCorrect = 0
                            self.previousLabel = percentage > 0.7 ? label : ""
                        }
                    }
                }
            }
        }
    }
}

extension UIImage {
    
    var noir: UIImage? {
        let context = CIContext(options: nil)
        guard let currentFilter = CIFilter(name: "CIPhotoEffectNoir") else { return nil }
        currentFilter.setValue(CIImage(image: self), forKey: kCIInputImageKey)
        if let output = currentFilter.outputImage,
            let cgImage = context.createCGImage(output, from: output.extent) {
            return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
        }
        return nil
    }
    
    func buffer() -> CVPixelBuffer? {
        
        return UIImage.convert(image: self)
    }
    
    static func convert(image: UIImage) -> CVPixelBuffer? {
        
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.size.width), Int(image.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard (status == kCVReturnSuccess) else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        context?.translateBy(x: 0, y: image.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context!)
        image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
    
    func resizeTo(_ size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContext(size)
        draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}

extension Double
{
    func truncate(places : Int)-> Double
    {
        return Double(floor(pow(10.0, Double(places)) * self)/pow(10.0, Double(places)))
    }
}
