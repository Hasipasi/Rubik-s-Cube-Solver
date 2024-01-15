import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet weak var cameraPreview: UIView!
    var instructionLabel: UILabel!
    var stepLabel: UILabel!

    var videoDataOutput: AVCaptureVideoDataOutput!
    var videoDataOutputQueue: DispatchQueue!
    var previewLayer:AVCaptureVideoPreviewLayer!
    var captureDevice : AVCaptureDevice!
    let session = AVCaptureSession()
    let context = CIContext()
    var arrowImageView: UIImageView!

    
    var solvingStates: [String] = []
    var scannedFaces: [UIImage] = []
    var currentStateIndex: Int = 0
    var sequences: [String] = ["White face", "Orange face", "Green face", "Red face", "Blue face", "Yellow face"]
    var currentSequenceIndex: Int = 0
    
    let delayDuration: TimeInterval = 1.0
    var lastFaceDetectionTime: Date?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        createTappingGesture()
        view.addSubview(cameraPreview)
        createInstructionLabel()
        createStepLabel()
        
        
        
        let direction = String("Right")
        let location = CGRect(x: 50, y: 250, width: 200, height: 50)
        let image = UIImage(named: "arrowImage.png")
        
        // Up = 90, Down = -90, left = 0, Right = 180
        let rotatedImage = image!.rotated(byDegrees: 180.0)
        
        //takes the arrow as an image & location and returns it as a view having that location
        arrowImageView = makeArrowImageView(rotatedImage!, location: location)
        
        //view.addSubview(arrowImageView) //adds the view to the main view
        
        startArrowAnimation(arrowImageView, arrowDirection: direction) //Starts animation on created view and direction
        
        self.setUpAVCapture()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCamera()
    }

    // To add the layer of your preview
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.previewLayer.frame = self.cameraPreview.layer.bounds
    }
    
    // To set the camera and its position to capture
    func setUpAVCapture() {
        session.sessionPreset = AVCaptureSession.Preset.vga640x480
        guard let device = AVCaptureDevice
            .default(AVCaptureDevice.DeviceType.builtInWideAngleCamera,
                     for: .video,
                     position: AVCaptureDevice.Position.back) else {
                        return
        }
        captureDevice = device
        beginSession()
    }
    
    // Function to setup the beginning of the capture session
    func beginSession(){
        var deviceInput: AVCaptureDeviceInput!
        
        do {
            deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            guard deviceInput != nil else {
                print("error: cant get deviceInput")
                return
            }
            
            if self.session.canAddInput(deviceInput){
                self.session.addInput(deviceInput)
            }
            
            videoDataOutput = AVCaptureVideoDataOutput()
            videoDataOutput.alwaysDiscardsLateVideoFrames=true
            videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue")
            videoDataOutput.setSampleBufferDelegate(self, queue:self.videoDataOutputQueue)
            
            if session.canAddOutput(self.videoDataOutput){
                session.addOutput(self.videoDataOutput)
            }
            
            videoDataOutput.connection(with: .video)?.isEnabled = true
            
            previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
            previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
            
            let rootLayer :CALayer = self.cameraPreview.layer
            rootLayer.masksToBounds=true
            
            rootLayer.addSublayer(self.previewLayer)
            session.startRunning()
        } catch let error as NSError {
            deviceInput = nil
            print("error: \(error.localizedDescription)")
        }
    }
    
    func createInstructionLabel() {
        instructionLabel = UILabel()
        instructionLabel.textAlignment = .center
        instructionLabel.textColor = UIColor.red
        instructionLabel.font = UIFont.systemFont(ofSize: 20)
        instructionLabel.frame = CGRect(x: 50, y: 250, width: 200, height: 50)

        view.addSubview(instructionLabel)
    }
    func createStepLabel() {
        stepLabel = UILabel()
        stepLabel.textAlignment = .center
        stepLabel.textColor = UIColor.black
        stepLabel.font = UIFont.systemFont(ofSize: 16)
        stepLabel.frame = CGRect(x: 50, y: -10, width: 200, height: 50)

        view.addSubview(stepLabel)
    }
    
    func createTappingGesture() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tapGestureRecognizer)
    }
        
    @objc func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        print("Tap is detected")
        
        if !solvingStates.isEmpty {
            if gestureRecognizer.state == .ended {
                currentStateIndex += 1
            }
            
            if currentStateIndex >= solvingStates.count {
                currentStateIndex = 0
                print("The cube is solved")
            }
        }
    }
    
    var currentCodeIndex = 0
    var timer: Timer?
    var solutions: [String]?

    // Function to capture the frames again and again
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        //print("Got a frame")
        DispatchQueue.main.async { [unowned self] in
            guard let frame = self.imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
            
            if currentSequenceIndex < sequences.count {
                //SCAN FACES IF FACES < 6
                detectFaceUI(frame: frame)
            } else if currentSequenceIndex == sequences.count {
                solutions = solveCubeUI()
                currentSequenceIndex += 1
                if solutions?.isEmpty == true {
                    currentSequenceIndex += 1
                }
                    
            } else if currentSequenceIndex == sequences.count + 1 {
                if timer == nil {
                    timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
                        self?.currentCodeIndex = (self?.currentCodeIndex ?? 0) + 1
                        if self?.currentCodeIndex == self?.solutions!.count {
                            self?.currentSequenceIndex += 1
                        }
                    }
                }
                
                let current_code = solutions?[currentCodeIndex]
                let coordinates = getCoordinates(frame: frame)
                showArrow(Code: current_code!, coordinates: coordinates)
            } else if currentSequenceIndex == sequences.count + 2 {
                instructionLabel.text = "Cube Solved"
                stepLabel.text = "Well Done!"
                view.subviews.filter { $0 is UIImageView }.forEach { $0.removeFromSuperview() }
            }
            
        }
    }
    
    func detectFaceUI(frame: UIImage) {
        if scannedFaces.count < 6 {
            if self.lastFaceDetectionTime == nil ||
                (self.lastFaceDetectionTime != nil && Date().timeIntervalSince(self.lastFaceDetectionTime!) >= self.delayDuration) {

                let croppedFace: UIImage? = CVWrapper.detectFace(frame)
                instructionLabel.text = sequences[currentSequenceIndex]
                instructionLabel.textColor = UIColor.red
                if croppedFace != nil {
                    print("Face is detected")
                    instructionLabel.text = "Scanned!"
                    instructionLabel.textColor = UIColor.green
                    scannedFaces.append(croppedFace!)
                    currentSequenceIndex += 1
                    
                    self.lastFaceDetectionTime = Date()
                    
                } else {
                    print("Face is not detected")
                }
            }
        }
    }
    
    func solveCubeUI() -> [String]{
        print("Start giving the solution")
        solvingStates = CVWrapper.solveCube(scannedFaces)
        print(solvingStates)
        print("The solution is given succesfully")
        return solvingStates
    }
    
    
    func showArrow(Code: String, coordinates: ([CGFloat], [CGFloat])) {
        print(Code)
        
        let show1: [String: Int] = [
            "U": 1,
            "D": 1,
            "U\\": 1,
            "D\\": 1,
            "L": 0,
            "R": 2,
            "F": 10,
            "B": 0,
            "L\\": 0,
            "R\\": 2,
            "F\\": 10,
            "B\\": 0,
            "M": 1,
            "S": 11,
            "E": 1,
            "M\\": 1,
            "S\\": 11,
            "E\\": 1
        ]

        let show2: [String: Int] = [
            "U": 5,
            "D": 5,
            "U\\": 5,
            "D\\": 5,
            "L": 8,
            "R": 6,
            "F": 6,
            "B": 4,
            "L\\": 8,
            "R\\": 6,
            "F\\": 6,
            "B\\": 4,
            "M": 7,
            "S": 5,
            "E": 5,
            "M\\": 7,
            "S\\": 5,
            "E\\": 5
        ]

        let messages: [String: String] = [
            "U": "Rotate the top layer",
            "D": "Rotate the bottom layer",
            "U\\": "Rotate the top layer",
            "D\\": "Rotate the bottom layer",
            "L": "Rotate the left layer",
            "R": "Rotate the right layer",
            "F": "Rotate the front layer",
            "B": "Rotate the back layer",
            "L\\": "Rotate the left layer",
            "R\\": "Rotate the right layer",
            "F\\": "Rotate the front layer",
            "B\\": "Rotate the back layer",
            "M": "Rotate the middle layer",
            "S": "Rotate the middle layer",
            "E": "Rotate the middle layer",
            "M\\": "Rotate the middle layer",
            "S\\": "Rotate the middle layer",
            "E\\": "Rotate the middle layer"
        ]

        let imageName: [String: String] = [
            "U": "Arrows/ClockW.png",
            "D": "Arrows/ClockW.png",
            "U\\": "Arrows/CounterClockW.png",
            "D\\": "Arrows/CounterClockW.png",
            "L": "Arrows/Down.png",
            "R": "Arrows/Up.png",
            "F": "Arrows/Right.png",
            "B": "Arrows/Left.png",
            "L\\": "Arrows/Up.png",
            "R\\": "Arrows/Down.png",
            "F\\": "Arrows/Left.png",
            "B\\": "Arrows/Right.png",
            "M": "Arrows/Down.png",
            "S": "Arrows/Left.png",
            "E": "Arrows/CounterClockW.png",
            "M\\": "Arrows/Up.png",
            "S\\": "Arrows/Right.png",
            "E\\": "Arrows/ClockW.png"
        ]

        let Xoffset: [String: CGFloat] = [
            "U": 0,
            "D": 0,
            "U\\": 0,
            "D\\": 0,
            "L": 0,
            "R": 0,
            "F": 0,
            "B": 0,
            "L\\": 0,
            "R\\": 0,
            "F\\": 0,
            "B\\": 0,
            "M": 0,
            "S": 0,
            "E": 0,
            "M\\": 0,
            "S\\": 0,
            "E\\": 0
        ]

        let Yoffset: [String: CGFloat] = [
            "U": 0,
            "D": 0,
            "U\\": 0,
            "D\\": 0,
            "L": 0,
            "R": 0,
            "F": 0,
            "B": 0,
            "L\\": 0,
            "R\\": 0,
            "F\\": 0,
            "B\\": 0,
            "M": 0,
            "S": 0,
            "E": 0,
            "M\\": 0,
            "S\\": 0,
            "E\\": 0
        ]

        let X = coordinates.0
        let Y = coordinates.1
        if X.isEmpty {
            return
        }
        view.subviews.filter { $0 is UIImageView }.forEach { $0.removeFromSuperview() }
        stepLabel.text = messages[Code]
        let image = UIImage(named: imageName[Code]!)
        print(show1[Code]!, show2[Code]!)
        var x1 = X[show1[Code]!]
        var y1 = Y[show1[Code]!]
        let x2 = X[show2[Code]!]
        let y2 = Y[show2[Code]!]
        let w = abs(x2 - x1)
        let h = abs(y2 - y1)
        //x1 = x1 + Xoffset[Code]!
        //y1 = y1 + Yoffset[Code]!
        let imageView = UIImageView(image: image)
        imageView.frame = CGRect(x: x1, y: y1, width: w, height: h) // Set the frame of the image view
        view.addSubview(imageView) // Add the image view to the view hierarchy
    }
    
    func getCoordinates(frame: UIImage, showMarkers: Bool = false) -> ([CGFloat], [CGFloat]) {
        instructionLabel.text = "Solving phase"

        // Pass the sharpened frame to get the face coordinates
        let coordinates = CVWrapper.getFaceCoordinates(frame)
        
        
        if coordinates.isEmpty {
            instructionLabel.text = "Show White Face"
            return ([], [])
        } else {
            // Remove old markers
            view.subviews.filter { $0.tag == 999 }.forEach { $0.removeFromSuperview() }
            instructionLabel.text = ""
            var new_coordinates: [NSValue] = []
            //print(coordinates)
            for coordinate in coordinates {
                let coordinateValue = coordinate
                let coordinate2 = coordinateValue.cgPointValue
                let y = coordinate2.x / frame.size.width * 480
                let x = 320 - coordinate2.y / frame.size.height * 320
                new_coordinates.append(NSValue(cgPoint: CGPoint(x: x, y: y)))
            }
            
            //order list of coordinates by x value
            let ordered_coordinates = new_coordinates.sorted(by: { $0.cgPointValue.x < $1.cgPointValue.x })
            //select top two coordinates
            let left_coordinates = ordered_coordinates[0...1]
            //select bottom two coordinates
            let right_coordinates = ordered_coordinates[2...3]
            //order top coordinates by y value
            let ordered_left_coordinates = left_coordinates.sorted(by: { $0.cgPointValue.y < $1.cgPointValue.y })
            //order bottom coordinates by y value
            let ordered_right_coordinates = right_coordinates.sorted(by: { $0.cgPointValue.y < $1.cgPointValue.y })
            //select top left coordinate
            let top_left_coordinate = ordered_left_coordinates[0]
            //select top right coordinate
            let bottom_left_coordinate = ordered_left_coordinates[1]
            //select bottom left coordinate
            let top_right_coordinate = ordered_right_coordinates[0]
            //select bottom right coordinate
            let bottom_right_coordinate = ordered_right_coordinates[1]

            let X_corner = [top_left_coordinate.cgPointValue.x, top_right_coordinate.cgPointValue.x, bottom_right_coordinate.cgPointValue.x, bottom_left_coordinate.cgPointValue.x]
            let Y_corner = [top_left_coordinate.cgPointValue.y, top_right_coordinate.cgPointValue.y, bottom_right_coordinate.cgPointValue.y, bottom_left_coordinate.cgPointValue.y]

            let next = [1,2,3,0]

            var X : [CGFloat] = []
            var Y : [CGFloat] = []

            //add extra points
            for i in 0...3 {
                X.append(X_corner[i])
                Y.append(Y_corner[i])
                X.append(X_corner[i] + ((X_corner[next[i]]-X_corner[i])/3))
                Y.append(Y_corner[i] + ((Y_corner[next[i]]-Y_corner[i])/3))
                X.append(X_corner[i] + ((X_corner[next[i]]-X_corner[i])*2/3))
                Y.append(Y_corner[i] + ((Y_corner[next[i]]-Y_corner[i])*2/3))
            }
            
            if showMarkers {
                for i in 0...11 {
                    let x = X[i]
                    let y = Y[i]
                    let marker = UIView()
                    marker.backgroundColor = UIColor.white
                    marker.frame = CGRect(x: x, y: y, width: 10, height: 10)
                    marker.tag = 999 // Use a tag to identify these views later
                    view.addSubview(marker)
                    // print(X)
                    // print(Y)
                }
            }

            return (X, Y)
        }
    }

 
    
    // Function to process the buffer and return UIImage to be used
    func imageFromSampleBuffer(sampleBuffer : CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
    
    // To stop the session
    func stopCamera(){
        session.stopRunning()
    }
    
    func makeArrowImageView(_ image: UIImage, location: CGRect) -> UIImageView {
        let imageView = UIImageView()
        imageView.frame = location
        imageView.image = image
        return imageView
    }
    
    func startArrowAnimation(_ arrowImageView: UIImageView, arrowDirection: String) {
        UIView.animate(withDuration: 1.0, delay: 0.0, options: [.repeat], animations: {
            switch arrowDirection {
                case "Up":
                arrowImageView.transform = CGAffineTransform(translationX: 0, y: -100)
                case "Down":
                arrowImageView.transform = CGAffineTransform(translationX: 0, y: 100)
                case "Left":
                arrowImageView.transform = CGAffineTransform(translationX: -100, y: 0)
                case "Right":
                arrowImageView.transform = CGAffineTransform(translationX: 100, y: 0)
                default:
                print("No recognized direction as input")
            }
        }, completion: nil)
    }
}

extension UIImage {
    func rotated(byDegrees degrees: CGFloat) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // Move the origin to the center of the image so that it will rotate around the center
        context.translateBy(x: size.width / 2, y: size.height / 2)
        // Rotate the context
        context.rotate(by: degrees * .pi / 180.0)
        // Draw the image into the context
        draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return rotatedImage
    }
}
