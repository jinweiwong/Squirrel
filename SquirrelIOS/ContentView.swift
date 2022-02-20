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
                if camera.result != nil {
                    Text("\(camera.result!.identifier == "R" ? "Recyclable" : "Compostable")")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundColor(Color.white)
                        .frame(width: UIScreen.main.bounds.width, height: 50)
                        .background(camera.result!.identifier == "R" ? Color.green : Color.brown)
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
        }
    }
}

struct InstructionsView: View {
    @Binding var showInstructions: Bool
    var body: some View {
        Button {
            self.showInstructions = false
        } label: {
            ZStack {
                Text("Point the camera at your waste")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(Color.white)
                VStack {
                    Spacer()
                    Text("Tap anywhere on the screen to continue")
                        .font(.system(size: 8, weight: .regular))
                        .foregroundColor(Color.white)
                        .padding(.bottom, 60)
                }
            }.ignoresSafeArea(.all)
        }
    }
}

class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var session = AVCaptureSession()
    @Published var output = AVCapturePhotoOutput()
    @Published var preview = AVCaptureVideoPreviewLayer()
    @Published var result: VNClassificationObservation? = nil
    
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
                self.result = firstObservation
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
