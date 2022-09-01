//
//  ViewController.swift
//  ARCamera
//
//  Created by Hyeonsoo Kim on 2022/08/31.
//

import UIKit
import ARKit
import RealityKit
import SceneKit

class ViewController: UIViewController {
    
    @IBOutlet var arView: ARView!
    
    // coreml model
    private var model: HeartPose1?
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
    
    // smoothly
    private var frameCounter: Int = 0
    private var handPosePredictionInterval: Int = 10
    
    private let cameraAnchor = AnchorEntity(.camera)
    
    var y = 0.1
    
    // to get simd_position
    private var heartFingerPostion: CGPoint? {
        didSet {
            
        }
    }
    
    //    private var heartPreview: Heart
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupModel()
        
        handPoseRequest.maximumHandCount = 1
        handPoseRequest.revision = VNDetectHumanHandPoseRequestRevision1
        
        arView.session.delegate = self
        
        arView.scene.addAnchor(cameraAnchor)
    }
    
    private func setupModel() {
        do {
            let config = MLModelConfiguration()
            self.model = try HeartPose1(configuration: config)
        } catch {
            fatalError("Cannot configure coreml model")
        }
    }
    
    private func addHeartPreview(simd: SIMD3<Float>) {
//        y += 0.05
        
        cameraAnchor.children.removeAll()
        
        let heart = Heart()
        cameraAnchor.addChild(heart)
        
        
        print(simd)
        cameraAnchor.position = SIMD3(SCNVector3(simd.x * 1000, simd.y * 1000, simd.z * 1000))
    }
}

/*
 실제 1m = 화면에서의 200mm라 할 때.
 100mm 이동하면 50cm이동하는 수식.
 */

extension ViewController: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
//        print("ARFrame didUpdate")
        
        frameCounter += 1
        
        if frameCounter % handPosePredictionInterval == 0 {
            
            let pixelBuffer = frame.capturedImage // 1. Image Capture
//            pixelBuffer
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]) // 2. Make Handler
            
            do {
                try handler.perform([handPoseRequest]) // 3. Perform
            } catch {
                assertionFailure("Human Pose Request failed: \(error)")
            }
            
            // 4. Get results.  VNHumanHandPoseObservations.
            guard let handPoses = handPoseRequest.results, !handPoses.isEmpty else {
                return // No effects to draw, so clear out current graphics
            }
            
            let handObservation = handPoses.first // 5. One hand
            
            guard let keypointsMultiArray = try? handObservation?.keypointsMultiArray() else { fatalError() }
            
            // 6. Model Operation
            let handPosePrediction = try? model?.prediction(poses: keypointsMultiArray)
            
            // 7. confidence
            let confidence = handPosePrediction?.labelProbabilities[handPosePrediction?.label ?? "nil이다."]
            
//            print(handPosePrediction!.label)
            
            guard let label = handPosePrediction?.label,
                  let confidence = confidence else { return }
            
            if label == "heartPose" && confidence > 0.9 {
                if let fingerPoint = try? handObservation?.recognizedPoint(.thumbTip) {
                    heartFingerPostion = CGPoint(x: fingerPoint.x * arView.bounds.width,
                                                 y: fingerPoint.y * arView.bounds.height)
//                    print(heartFingerPostion)
                    // Question. x, y 왜 바뀐 느낌이지.
                    // x는 위일수록 0, 아래일수록 1. y는 왼일수록 0, 우일수록 1.
//                    print("fingerXXX: \(fingerPoint.location.x)")
//                    print("finYYYYYY: \(fingerPoint.location.y)")
                    let thumbTip = CGPoint(x: fingerPoint.location.x, y: 1 - fingerPoint.location.y)
//
                    heartFingerPostion = CGPoint(x: fingerPoint.y * arView.bounds.width,
                                                 y: fingerPoint.x * arView.bounds.height)
//                    print("AVCoordinates: \(heartFingerPostion)")
                    let simd = arView.unproject(heartFingerPostion!, viewport: arView.bounds)!
                    addHeartPreview(simd: simd)
//                    print(simd)
                }
            } else {
                heartFingerPostion = nil
                
            }
        }
    }
}
