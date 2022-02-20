//
//  ContentView.swift
//  SquirrelIOS
//
//  Created by Wong Jin Wei on 19/02/2022.
//

import SwiftUI
import AVFoundation
import Vision

struct ContentView: View {
    @State private var showInstructions: Bool = true
    var body: some View {
        ZStack {
            CameraView(showInstructions: self.$showInstructions)
                .blur(radius: showInstructions ? 5 : 0, opaque: false)
            if showInstructions {
                InstructionsView(showInstructions: self.$showInstructions)
            }
        }
    }
}

struct CameraView: View {
    @StateObject var camera = CameraModel()
    @Binding var showInstructions: Bool
    
    var body: some View {
        ZStack {
            CameraPreview(camera: camera)
                .ignoresSafeArea(.all, edges: .all)
                .onAppear(perform: {
                    camera.Check()
                })
            
            VStack {
                VStack {
                    ZStack {
                        camera.toColor()
                            .frame(width: UIScreen.main.bounds.width, height: 100)
                        Text("\(camera.toText())")
                            .font(.system(size: 28, weight: .regular))
                            .foregroundColor(Color.white)
                            .padding(.top, 45)
                    }
                }
                
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        self.showInstructions = true
                    } label: {
                        Image(systemName: "info.circle.fill")
                            .resizable()
                            .frame(width: 26, height: 26)
                            .foregroundColor(Color.white)
                    }
                }.padding(.bottom, 20)
                    .padding(.trailing, 20)
            }
        }.frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
            .ignoresSafeArea(.all)
    }
}

struct InstructionsView: View {
    @Binding var showInstructions: Bool
    var body: some View {
        Button {
            self.showInstructions = false
        } label: {
            VStack {
                Text("Point the camera at your waste")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(Color.white)
                Text("Tap anywhere on the screen to continue")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(Color.white)
                    .padding(.top, 10)
            }.frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .ignoresSafeArea(.all)
        }
    }
}

class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var session = AVCaptureSession()
    @Published var output = AVCapturePhotoOutput()
    @Published var preview = AVCaptureVideoPreviewLayer()
    @Published var result: WasteType = .landfill
    
    enum WasteType {
        case composte, recycle, landfill
    }
    
    func toText() -> String {
        if self.result == .composte {
            return "Composte"
        } else if self.result == .recycle {
            return "Recycle"
        } else {
            return "Landfill"
        }
    }
    
    func toColor() -> Color {
        if self.result == .composte {
            return Color.brown
        } else if self.result == .recycle {
            return Color.green
        } else {
            return Color.black
        }
    }
    
    func Check() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setUp()
            return
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (status) in
                if status {
                    self.setUp()
                }
            })
        default:
            return
        }
    }
    func setUp() {
        do {
            self.session.beginConfiguration()
            let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back)
            
            let input = try AVCaptureDeviceInput(device: device!)
            if self.session.canAddInput(input) {
                self.session.addInput(input)
            }
            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
            }
            self.session.commitConfiguration()
        }
        catch {
            print(error.localizedDescription)
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let model = try? VNCoreMLModel(for: SquirrelClassifier(configuration: MLModelConfiguration()).model) else { return }
        let request = VNCoreMLRequest(model: model) { finishedReq, error in
            guard let results = finishedReq.results as? [VNClassificationObservation] else { return }
            guard let firstObservation = results.first else { return }
            DispatchQueue.main.async {
                print(firstObservation.identifier)
                if firstObservation.identifier == "O" {
                    self.result = .composte
                } else if firstObservation.identifier == "R" {
                    self.result = .recycle
                } else {
                    self.result = .landfill
                }
            }
        }
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
    }
}

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera: CameraModel
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        camera.preview = AVCaptureVideoPreviewLayer(session: camera.session)
        camera.preview.frame = view.frame
        camera.preview.videoGravity = .resizeAspectFill // Modify
        view.layer.addSublayer(camera.preview)
        camera.session.startRunning()
        
        // Capture video data
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(camera, queue: DispatchQueue(label: "videoOutput"))
        camera.session.addOutput(dataOutput)
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
