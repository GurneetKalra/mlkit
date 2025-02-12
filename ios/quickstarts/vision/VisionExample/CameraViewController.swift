//
//  Copyright (c) 2018 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import AVFoundation
import CoreVideo
import MLKit

class CameraViewController: UIViewController {
  private var previewLayer: AVCaptureVideoPreviewLayer!
  private lazy var captureSession = AVCaptureSession()
  private lazy var sessionQueue = DispatchQueue(label: Constant.sessionQueueLabel)
  private var isUsingFrontCamera = true

  private lazy var previewOverlayView: UIImageView = {
    precondition(isViewLoaded)
    let previewOverlayView = UIImageView(frame: .zero)
    previewOverlayView.contentMode = UIView.ContentMode.scaleAspectFill
    previewOverlayView.translatesAutoresizingMaskIntoConstraints = false
    return previewOverlayView
  }()

  private lazy var annotationOverlayView: UIView = {
    precondition(isViewLoaded)
    let annotationOverlayView = UIView(frame: .zero)
    annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
    return annotationOverlayView
  }()

  private lazy var switchCameraButton: UIButton = {
    let button = UIButton(type: .system)
    button.setImage(UIImage(systemName: "camera.rotate"), for: .normal)
    button.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  private lazy var cameraView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  override func viewDidLoad() {
    super.viewDidLoad()

    // Add camera view to main view
    view.addSubview(cameraView)
    NSLayoutConstraint.activate([
        // Change to use safe area layout guide for top and bottom
        cameraView.topAnchor.constraint(equalTo: view.topAnchor),
        cameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        cameraView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        cameraView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])

    previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    previewLayer.videoGravity = .resizeAspectFill
    previewLayer.frame = view.layer.bounds
    cameraView.layer.addSublayer(previewLayer)
    
    // Ensure overlay views use the same constraints as camera view
    setUpPreviewOverlayView()
    setUpAnnotationOverlayView()
    setUpSwitchCameraButton()
    setUpCaptureSessionOutput()
    setUpCaptureSessionInput()
    
    // Add these lines to prevent the bars
    view.backgroundColor = .black
    cameraView.backgroundColor = .black
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    startSession()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    stopSession()
  }

  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    previewLayer.frame = view.layer.bounds
  }

  override var prefersStatusBarHidden: Bool {
    return true
  }

  // MARK: - Private

  private func setUpCaptureSessionOutput() {
    sessionQueue.async {
      self.captureSession.beginConfiguration()
      self.captureSession.sessionPreset = AVCaptureSession.Preset.medium

      let output = AVCaptureVideoDataOutput()
      output.videoSettings = [
        (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA
      ]
      output.alwaysDiscardsLateVideoFrames = true
      let outputQueue = DispatchQueue(label: Constant.videoDataOutputQueueLabel)
      output.setSampleBufferDelegate(self, queue: outputQueue)
      guard self.captureSession.canAddOutput(output) else {
        print("Failed to add capture session output.")
        return
      }
      self.captureSession.addOutput(output)
      self.captureSession.commitConfiguration()
    }
  }

  private func setUpCaptureSessionInput() {
    sessionQueue.async {
      let cameraPosition: AVCaptureDevice.Position = self.isUsingFrontCamera ? .front : .back
      guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition) else {
        print("Failed to get capture device")
        return
      }
      do {
        self.captureSession.beginConfiguration()
        let currentInputs = self.captureSession.inputs
        for input in currentInputs {
          self.captureSession.removeInput(input)
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard self.captureSession.canAddInput(input) else {
          print("Failed to add capture session input.")
          return
        }
        self.captureSession.addInput(input)
        self.captureSession.commitConfiguration()
      } catch {
        print("Failed to create capture device input: \(error.localizedDescription)")
      }
    }
  }

  private func startSession() {
    sessionQueue.async {
      self.captureSession.startRunning()
    }
  }

  private func stopSession() {
    sessionQueue.async {
      self.captureSession.stopRunning()
    }
  }

  private func setUpPreviewOverlayView() {
    cameraView.addSubview(previewOverlayView)
    NSLayoutConstraint.activate([
        previewOverlayView.topAnchor.constraint(equalTo: cameraView.topAnchor),
        previewOverlayView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
        previewOverlayView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
        previewOverlayView.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor)
    ])
  }

  private func setUpAnnotationOverlayView() {
    cameraView.addSubview(annotationOverlayView)
    NSLayoutConstraint.activate([
      annotationOverlayView.topAnchor.constraint(equalTo: cameraView.topAnchor),
      annotationOverlayView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
      annotationOverlayView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
      annotationOverlayView.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor),
    ])
  }

  private func setUpSwitchCameraButton() {
    view.addSubview(switchCameraButton)
    NSLayoutConstraint.activate([
      switchCameraButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
      switchCameraButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      switchCameraButton.widthAnchor.constraint(equalToConstant: 44),
      switchCameraButton.heightAnchor.constraint(equalToConstant: 44)
    ])
  }

  @objc private func switchCamera() {
    isUsingFrontCamera.toggle()
    removeDetectionAnnotations()
    setUpCaptureSessionInput()
  }

  private func removeDetectionAnnotations() {
    for annotationView in annotationOverlayView.subviews {
      annotationView.removeFromSuperview()
    }
  }

  private func updatePreviewOverlayViewWithImageBuffer(_ imageBuffer: CVImageBuffer?) {
    guard let imageBuffer = imageBuffer else { return }
    let orientation: UIImage.Orientation = isUsingFrontCamera ? .leftMirrored : .right
    let image = UIUtilities.createUIImage(from: imageBuffer, orientation: orientation)
    previewOverlayView.image = image
  }

  private func normalizedPoint(
    fromVisionPoint point: VisionPoint,
    width: CGFloat,
    height: CGFloat
  ) -> CGPoint {
    let cgPoint = CGPoint(x: point.x, y: point.y)
    var normalizedPoint = CGPoint(x: cgPoint.x / width, y: cgPoint.y / height)
    normalizedPoint = previewLayer.layerPointConverted(fromCaptureDevicePoint: normalizedPoint)
    return normalizedPoint
  }
}

// MARK: - Constants

private enum Constant {
  static let videoDataOutputQueueLabel = "com.google.mlkit.visiondetector.VideoDataOutputQueue"
  static let sessionQueueLabel = "com.google.mlkit.visiondetector.SessionQueue"
  static let smallDotRadius: CGFloat = 4.0
  static let lineWidth: CGFloat = 3.0
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      print("Failed to get image buffer from sample buffer.")
      return
    }
    
    let visionImage = VisionImage(buffer: sampleBuffer)
    let orientation = UIUtilities.imageOrientation(
      fromDevicePosition: isUsingFrontCamera ? .front : .back
    )
    visionImage.orientation = orientation
    
    let imageWidth = CGFloat(CVPixelBufferGetWidth(imageBuffer))
    let imageHeight = CGFloat(CVPixelBufferGetHeight(imageBuffer))
    
    let poseDetector = PoseDetector.poseDetector(options: PoseDetectorOptions())
    
    var poses: [Pose]
    do {
      poses = try poseDetector.results(in: visionImage)
    } catch let error {
      print("Failed to detect poses with error: \(error.localizedDescription).")
      return
    }
    
    DispatchQueue.main.sync {
      self.updatePreviewOverlayViewWithImageBuffer(imageBuffer)
      self.removeDetectionAnnotations()
      
      for pose in poses {
        let poseOverlayView = UIUtilities.createPoseOverlayView(
          forPose: pose,
          inViewWithBounds: self.annotationOverlayView.bounds,
          lineWidth: Constant.smallDotRadius,
          dotRadius: Constant.smallDotRadius,
          positionTransformationClosure: { (position) -> CGPoint in
            return self.normalizedPoint(
              fromVisionPoint: position,
              width: imageWidth,
              height: imageHeight)
          }
        )
        self.annotationOverlayView.addSubview(poseOverlayView)
      }
    }
  }
}
