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
    var body: some View {
        CameraView()
    }
}

struct CameraView: View {
    @StateObject var camera = CameraModel()
    var body: some View {
        ZStack {
            CameraPreview(camera: camera)
                .ignoresSafeArea(.all, edges: .all)
            VStack {
                if camera.isTaken {
                    HStack {
                        Spacer()
                        Button(action: {
                            camera.reTake()
                        }, label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .foregroundColor(.black)
                                .padding()
                                .background(Color.white)
                                .clipShape(Circle())
                        }).padding(.leading)
                    }
                }
                Spacer()
                HStack {
                    if camera.isTaken {
                        Button(action: {
                            if !camera.isSaved {
                                camera.savePic()
                            }
                        }, label: {
                            Text(camera.isSaved ? "Saved" : "Save")
                                .foregroundColor(Color.black)
                                .fontWeight(.semibold)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }).padding(.leading)
                        Spacer()
                    } else {
                        Button(action: {
                            camera.takePic()
                        }, label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 65, height: 656)
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: 75, height: 75)
                            }
                        })
                    }
                }.frame(height: 75)
            }
        }.onAppear(perform: {
            camera.Check()
        })
    }
}

class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var isTaken: Bool = false
    @Published var session = AVCaptureSession()
    @Published var alert: Bool = false
    @Published var output = AVCapturePhotoOutput()
    @Published var preview = AVCaptureVideoPreviewLayer()
    @Published var isSaved: Bool = false
    @Published var picData = Data(count: 0)
    
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
        case .denied:
            self.alert.toggle()
            return
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
    
    func takePic() {
        DispatchQueue.global(qos: .background).async {
            self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            self.session.stopRunning()
            DispatchQueue.main.async {
                withAnimation {
                    self.isTaken.toggle()
                }
            }
        }
    }
    
    func reTake() {
        DispatchQueue.global(qos: .background).async {
            self.session.startRunning()
            DispatchQueue.main.async {
                withAnimation {
                    self.isTaken.toggle()
                    self.isSaved = false
                }
            }
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if error != nil {
            return
        }
        print("Picture taken")
        guard let imageData = photo.fileDataRepresentation() else {
            return
        }
        self.picData = imageData
    }
    
    func savePic() {
        let image = UIImage(data: self.picData)!
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        self.isSaved = true
        print("Saved image")
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let model = try? VNCoreMLModel(for: Resnet50().model) else { return }
        let request = VNCoreMLRequest(model: model) { finishedReq, error in
            guard let results = finishedReq.results as? [VNClassificationObservation] else { return }
            guard let firstObservation = results.first else { return }
            print(firstObservation.identifier, firstObservation.confidence)
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
