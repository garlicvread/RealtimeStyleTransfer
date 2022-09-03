//
//  ViewController.swift
//  style-transfer
//
//  Created by 김제필 on 8/23/22.
//  Copyright © 2022 Intelligent ATLAS. All rights reserved.
//

import UIKit
import AVFoundation
import CoreMedia
import Vision
import VideoToolbox

enum Styles : String, CaseIterable {
    case style1
    case style2
    case style3
    case style4
    case style5
    case style6
    case style7
}

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    let parentStack = UIStackView()
    let imageView = UIImageView()
    let modelConfigControl = UISegmentedControl(items: ["Off", "On"])
    let styleTransferControl = UISegmentedControl(items: [Styles.style1.rawValue,
                                                          Styles.style2.rawValue,
                                                          Styles.style3.rawValue,
                                                          Styles.style4.rawValue,
                                                          Styles.style5.rawValue,
                                                          Styles.style6.rawValue,
                                                          Styles.style7.rawValue])

    var currentModelConfig = 0
    var currentStyle = Styles.style1

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        configureSession()
    }

    func setupUI() {
        view.addSubview(parentStack)
        parentStack.axis = NSLayoutConstraint.Axis.vertical
        parentStack.distribution = UIStackView.Distribution.fill

        parentStack.addArrangedSubview(styleTransferControl)
        parentStack.addArrangedSubview(imageView)
        parentStack.addArrangedSubview(modelConfigControl)

        imageView.contentMode = UIView.ContentMode.scaleAspectFit

        modelConfigControl.selectedSegmentIndex = 0
        styleTransferControl.selectedSegmentIndex = 0

        modelConfigControl.addTarget(self,
                                     action: #selector(modelConfigChanged(_:)),
                                     for: .valueChanged)
        styleTransferControl.addTarget(self,
                                       action: #selector(styleTransferChanged(_:)),
                                       for: .valueChanged)
    }

    @objc func modelConfigChanged(_ sender: UISegmentedControl) {
        currentModelConfig = sender.selectedSegmentIndex
    }

    @objc func styleTransferChanged(_ sender: UISegmentedControl) {
        currentStyle = Styles.allCases[sender.selectedSegmentIndex]
    }


    func configureSession() {
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.medium

        // Search for available capture devices
        let availableDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
                                                                mediaType: AVMediaType.video,
                                                                position: .back).devices

        do {
            if let captureDevice = availableDevices.first {
                captureSession.addInput(try AVCaptureDeviceInput(device: captureDevice))
            }
        } catch {
            print(error.localizedDescription)
        }

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        guard let connection = videoOutput.connection(with: .video) else { return }
        guard connection.isVideoOrientationSupported else { return }

        connection.videoOrientation = .portrait

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        view.layer.addSublayer(previewLayer)

        captureSession.startRunning()
    }


    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        if currentModelConfig == 0 {
            DispatchQueue.main.async(execute: {
                self.imageView.image = CameraUtil.imageFromSampleBuffer(buffer: sampleBuffer)
            })
        } else {
            let config = MLModelConfiguration()
            switch currentModelConfig {
            case 1:
                config.computeUnits = .all
            case 2:
                config.computeUnits = .cpuAndGPU
            default:
                config.computeUnits = .cpuOnly
            }

            var style : MLModel?

            switch currentStyle {
            case .style1:
                style = try? style1.init(configuration: config).model
            case .style2:
                style = try? style2.init(configuration: config).model
            case .style3:
                style = try? style3.init(configuration: config).model
            case .style4:
                style = try? style4.init(configuration: config).model
            case .style5:
                style = try? style5.init(configuration: config).model
            case .style6:
                style = try? style6.init(configuration: config).model
            case .style7:
                style = try? style7.init(configuration: config).model
            }

            guard let styleModel = style else{ return }

            guard let model = try? VNCoreMLModel(for: styleModel) else { return }

            let request = VNCoreMLRequest(model: model) { (finishedRequest, error) in
                guard let results = finishedRequest.results as? [VNPixelBufferObservation] else { return }

                guard let observation = results.first else { return }

                DispatchQueue.main.async(execute: {
                    self.imageView.image = UIImage(pixelBuffer: observation.pixelBuffer)
                })
            }

            guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        parentStack.frame = CGRect(x: 0, y: 100,
                                   width: view.frame.width,
                                   height: view.frame.height - 200).insetBy(dx: 5, dy: 5)
    }
}

extension UIImage {
    public convenience init?(pixelBuffer: CVPixelBuffer) {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)

        if let cgImage = cgImage {
            self.init(cgImage: cgImage)
        } else {
            return nil
        }
    }
}

class CameraUtil {
    class func imageFromSampleBuffer(buffer: CMSampleBuffer) -> UIImage {
        let pixelBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(buffer)!

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        let pixelBufferWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let pixelBufferHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let imageRect: CGRect = CGRect(x: 0, y: 0,
                                       width: pixelBufferWidth,
                                       height: pixelBufferHeight)
        let ciContext = CIContext.init()
        let cgimage = ciContext.createCGImage(ciImage, from: imageRect )

        let image = UIImage(cgImage: cgimage!)
        return image
    }
}
