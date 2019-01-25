//
//  ViewController.swift
//  NameItPlease
//
//  Created by Nick Gaens on 1/22/19.
//  Copyright © 2019 GPS nv. All rights reserved.
//

import UIKit
import QuartzCore
import AVFoundation
import Vision
import CoreML

class ViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    @IBOutlet var cameraView: UIView!
    
    @IBOutlet var resNet50StackView: UIStackView!
    @IBOutlet var resNet50Label: UILabel!
    @IBOutlet var resNet50TopPredictionLabel: UILabel!
    @IBOutlet var resNet50SecondPredictionLabel: UILabel!
    @IBOutlet var resNet50ActivityIndicatorView: UIActivityIndicatorView!
    
    @IBOutlet var vgg16StackView: UIStackView!
    @IBOutlet var vgg16Label: UILabel!
    @IBOutlet var vgg16TopPredictionLabel: UILabel!
    @IBOutlet var vgg16SecondPredictionLabel: UILabel!
    @IBOutlet var vgg16ActivityIndicatorView: UIActivityIndicatorView!
    
    @IBOutlet var mobileNetStackView: UIStackView!
    @IBOutlet var mobileNetLabel: UILabel!
    @IBOutlet var mobileNetTopPredictionLabel: UILabel!
    @IBOutlet var mobileNetSecondPredictionLabel: UILabel!
    @IBOutlet var mobileNetActivityIndicatorView: UIActivityIndicatorView!
    
    @IBOutlet var nasNetMobileStackView: UIStackView!
    @IBOutlet var nasNetMobileLabel: UILabel!
    @IBOutlet var nasNetMobileTopPredictionLabel: UILabel!
    @IBOutlet var nasNetMobileSecondPredictionLabel: UILabel!
    @IBOutlet var nasNetMobileActivityIndicatorView: UIActivityIndicatorView!
    
    let captureSession = AVCaptureSession()
    let stillImageOutput = AVCaptureStillImageOutput()

    enum ModelEnum: String {
        case ResNet50 = "ResNet50"
        case VGG16 = "VGG16"
        case NASNetMobile = "NASNetMobile"
        case MobileNet = "MobileNet"
    }
    
    let availableModels = [ModelEnum.ResNet50.rawValue: ResNet50().model,
                           ModelEnum.VGG16.rawValue: VGG16().model,
                           ModelEnum.NASNetMobile.rawValue: NASNetMobile().model,
                           ModelEnum.MobileNet.rawValue: MobileNet().model]
    
    var imageData: Data?
    var isStopped = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.cameraView.layer.borderColor = UIColor.darkGray.cgColor
        self.cameraView.layer.borderWidth = 1.0
        self.cameraView.layer.masksToBounds = true
        
        self.resetResultLabels()
        self.stopWaiting()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { // Code below has to be called on the main thread.
                if granted {
                    self.setupAV()
                    self.startScanning()
                }
            }
        }
    }
    
    // MARK: - AV stuff
    
    private func setupAV() {
        if let captureDevice = AVCaptureDevice.default(for: .video) {
            do {
                let input = try AVCaptureDeviceInput(device: captureDevice)
                if captureSession.canAddInput(input) {
                    captureSession.addInput(input)
                }
            } catch {
                fatalError("Could not add input: \(error)")
            }
            captureSession.sessionPreset = AVCaptureSession.Preset.photo
            
            stillImageOutput.outputSettings = [AVVideoCodecKey:AVVideoCodecType.jpeg]
            if captureSession.canAddOutput(stillImageOutput) {
                captureSession.addOutput(stillImageOutput)
            }
            
            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = self.cameraView.bounds
            previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
            
            if let connection = previewLayer.connection {
                switch UIApplication.shared.statusBarOrientation {
                case .landscapeLeft:
                    connection.videoOrientation = .landscapeLeft
                case .landscapeRight:
                    connection.videoOrientation = .landscapeRight
                case .portrait:
                    connection.videoOrientation = .portrait
                case .portraitUpsideDown:
                    connection.videoOrientation = .portraitUpsideDown
                default:
                    break
                }
            }

            cameraView.layer.addSublayer(previewLayer)
            cameraView.addGestureRecognizer(UITapGestureRecognizer(target: self, action:#selector(didTapOnCameraView(_:))))
        }
    }
    
    func startScanning() {
        print("startScanning()")
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onCaptureSessionDidStartRunning(_:)),
                                               name: NSNotification.Name.AVCaptureSessionDidStartRunning,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onCaptureSessionErrorOccured(_:)),
                                               name: NSNotification.Name.AVCaptureSessionRuntimeError,
                                               object: nil)
        self.captureSession.startRunning()
    }
    
    func stopScanning() {
        print("stopScanning()")
        
        NotificationCenter.default.removeObserver(self)
        self.captureSession.stopRunning()
    }
    
    @objc func onCaptureSessionDidStartRunning(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func onCaptureSessionErrorOccured(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)

        if let userInfo = notification.userInfo {
            print("AVCaptureSession error occured: \(userInfo[AVCaptureSessionErrorKey] as! String)")
        }
    }
    
    func startWaiting() {
        self.resNet50StackView.isHidden = true
        self.resNet50ActivityIndicatorView.isHidden = false
        self.resNet50ActivityIndicatorView.startAnimating()
        
        self.vgg16StackView.isHidden = true
        self.vgg16ActivityIndicatorView.isHidden = false
        self.vgg16ActivityIndicatorView.startAnimating()
        
        self.mobileNetStackView.isHidden = true
        self.mobileNetActivityIndicatorView.isHidden = false
        self.mobileNetActivityIndicatorView.startAnimating()
        
        self.nasNetMobileStackView.isHidden = true
        self.nasNetMobileActivityIndicatorView.isHidden = false
        self.nasNetMobileActivityIndicatorView.startAnimating()
    }
    
    func stopWaiting() {
        self.stopWaiting(for: .ResNet50)
        self.stopWaiting(for: .VGG16)
        self.stopWaiting(for: .MobileNet)
        self.stopWaiting(for: .NASNetMobile)
    }
    
    func stopWaiting(for model: ModelEnum) {
        switch model {
        case .ResNet50:
            self.resNet50StackView.isHidden = false
            self.resNet50ActivityIndicatorView.stopAnimating() // Auto-hides.
            break
        case .VGG16:
            self.vgg16StackView.isHidden = false
            self.vgg16ActivityIndicatorView.stopAnimating() // Auto-hides.
            break
        case .NASNetMobile:
            self.nasNetMobileStackView.isHidden = false
            self.nasNetMobileActivityIndicatorView.stopAnimating() // Auto-hides.
            break
        case .MobileNet:
            self.mobileNetStackView.isHidden = false
            self.mobileNetActivityIndicatorView.stopAnimating() // Auto-hides
            break
        }
    }
    
    func resetResultLabels() {
        self.resNet50Label.text = ModelEnum.ResNet50.rawValue
        self.resNet50TopPredictionLabel.text = "Top prediction"
        self.resNet50SecondPredictionLabel.text = "Second best prediction"
        
        self.vgg16Label.text = ModelEnum.VGG16.rawValue
        self.vgg16TopPredictionLabel.text = "Top prediction"
        self.vgg16SecondPredictionLabel.text = "Second best prediction"
        
        self.mobileNetLabel.text = ModelEnum.MobileNet.rawValue
        self.mobileNetTopPredictionLabel.text = "Top prediction"
        self.mobileNetSecondPredictionLabel.text = "Second best prediction"
        
        self.nasNetMobileLabel.text = ModelEnum.NASNetMobile.rawValue
        self.nasNetMobileTopPredictionLabel.text = "Top prediction"
        self.nasNetMobileSecondPredictionLabel.text = "Second best prediction"
    }
    
    // MARK: - UITapGestureRecognizer
    
    @objc func didTapOnCameraView(_ sender: UITapGestureRecognizer) {
        if isStopped {
            self.startScanning()
            self.resetResultLabels()
        } else {
            self.startWaiting()
            
            if let videoConnection = stillImageOutput.connection(with: AVMediaType.video) {
                stillImageOutput.captureStillImageAsynchronously(from: videoConnection) {
                    (imageDataSampleBuffer, error) -> Void in
                    self.stopScanning()

                    if let error = error {
                        print("An error occurred when capturing image: \(error)")
                        self.stopWaiting()
                        self.startScanning()
                    } else if imageDataSampleBuffer == nil {
                        print("Failed to capture image")
                        self.stopWaiting()
                        self.startScanning()
                    } else {
                        self.imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer!)
                        
                        let resNet50Model = self.availableModels.filter {$0.key == ModelEnum.ResNet50.rawValue}.values.first!
                        self.performPrediction(using: resNet50Model,
                                               enumEntry: .ResNet50,
                                               modelNameLabel: self.resNet50Label,
                                               displayResultsIn: [self.resNet50TopPredictionLabel,
                                                                  self.resNet50SecondPredictionLabel])
                        
                        let vgg16Model = self.availableModels.filter {$0.key == ModelEnum.VGG16.rawValue}.values.first!
                        self.performPrediction(using: vgg16Model,
                                               enumEntry: .VGG16,
                                               modelNameLabel: self.vgg16Label,
                                               displayResultsIn: [self.vgg16TopPredictionLabel,
                                                                  self.vgg16SecondPredictionLabel])
                        
                        let nasNetMobileModel = self.availableModels.filter {$0.key == ModelEnum.NASNetMobile.rawValue}.values.first!
                        self.performPrediction(using: nasNetMobileModel,
                                               enumEntry: .NASNetMobile,
                                               modelNameLabel: self.nasNetMobileLabel,
                                               displayResultsIn: [self.nasNetMobileTopPredictionLabel,
                                                                  self.nasNetMobileSecondPredictionLabel])
                        
                        let mobileNetModel = self.availableModels.filter {$0.key == ModelEnum.MobileNet.rawValue}.values.first!
                        self.performPrediction(using: mobileNetModel,
                                               enumEntry: .MobileNet,
                                               modelNameLabel: self.mobileNetLabel,
                                               displayResultsIn: [self.mobileNetTopPredictionLabel,
                                                                  self.mobileNetSecondPredictionLabel])
                    }
                }
            }
        }
        
        isStopped = !isStopped
    }
    
    // MARK: - ML stuff
    
    func performPrediction(using model: MLModel, enumEntry: ModelEnum, modelNameLabel: UILabel, displayResultsIn labels: [UILabel]) {
        guard let imageData = self.imageData else { print("No image data"); return }
        guard let inputImage = CIImage(data: imageData) else { print("Could not create CIImage from data"); return }
        
        // Easier way to do it but not supported in Keras (?)
        guard let mlModel = try? VNCoreMLModel(for: model) else {
            print("Can't load CoreML model \(enumEntry.rawValue)")
            self.stopWaiting(for: enumEntry)
            return
        }
        
        // Process
        let coreMLRequest = VNCoreMLRequest(model: mlModel, completionHandler: { (request: VNRequest, error: Error?) -> Void in
            guard let results = request.results as? [VNClassificationObservation]
                else { fatalError("Unable to process") }
            
            if results.isEmpty {
                print("Model did not yield any results")
                labels.forEach {$0.text = "?"}
            } else {
                let sortedResults = results.sorted(by: {$0.confidence > $1.confidence}).prefix(2)
                sortedResults.forEach {print($0.identifier, ":", $0.confidence * 100)}
                
                if let topResult = sortedResults.first {
                    var identifier: String!
                    if enumEntry == .MobileNet {
                        identifier = self.processMobileNetIdentifier(topResult.identifier)
                    } else {
                        identifier = topResult.identifier
                    }
                    labels.first!.text = String(format: "%@ (%.3f%%)", identifier, topResult.confidence * 100)
                }
                
                if let secondBestResult = sortedResults[safe: 1] {
                    var identifier: String!
                    if enumEntry == .MobileNet {
                        identifier = self.processMobileNetIdentifier(secondBestResult.identifier)
                    } else {
                        identifier = secondBestResult.identifier
                    }
                    labels[1].text = String(format: "%@ (%.3f%%)", identifier, secondBestResult.confidence * 100)
                } else {
                    labels[1].text = "?"
                }                
            }
        })
        let handler = VNImageRequestHandler(ciImage: inputImage)
        do {
            let startingPoint = Date()
            try handler.perform([coreMLRequest])
            modelNameLabel.text = enumEntry.rawValue + String(format: " %.2fs", abs(startingPoint.timeIntervalSinceNow))
            self.stopWaiting(for: enumEntry)
        } catch {
            print("Failed to perform output handler: \(error)")
            modelNameLabel.text = enumEntry.rawValue
            labels.forEach {$0.text = "An error occurred"}
            self.stopWaiting(for: enumEntry)
        }
    }
    
    func processMobileNetIdentifier(_ identifier: String) -> String {
        if let index = identifier.firstIndex(of: " ") {
            let nextIndex = identifier.index(after: index)
            return String(identifier[nextIndex...])
        } else {
            return identifier
        }
    }
}

