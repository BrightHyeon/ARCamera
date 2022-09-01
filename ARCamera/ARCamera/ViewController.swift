//
//  ViewController.swift
//  ARCamera
//
//  Created by Hyeonsoo Kim on 2022/08/31.
//

import ARKit
import RealityKit

class ViewController: UIViewController {
    
    @IBOutlet var arView: ARView!
    
    // coreml model
    private var model: HandPose?
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
    
    // smoothly
    private var frameCounter: Int = 0
    private var handPosePredictionInterval: Int = 5
    
    private var cameraAnchor: AnchorEntity?
    private var heart: Heart?
    let configuration = ARWorldTrackingConfiguration()
    
    private var backCount: Int = 0
    private var preX: Float = 0.0
    private var preY: Float = 0.0
    private var count: Int = 0
    private var pick: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupModel()
        
        handPoseRequest.maximumHandCount = 1
        handPoseRequest.revision = VNDetectHumanHandPoseRequestRevision1
        
        arView.session.delegate = self
        
        cameraAnchor = AnchorEntity(.camera)
        arView.scene.addAnchor(cameraAnchor!)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        arView.session.run(configuration)
    }
    
    private func setupModel() {
        do {
            let config = MLModelConfiguration()
            self.model = try HandPose(configuration: config)
        } catch {
            fatalError("Cannot configure coreml model")
        }
    }
    
    private func addHeartPreview() {
        self.cameraAnchor = AnchorEntity(.camera)
        arView.scene.addAnchor(cameraAnchor!)
    }
    
    private func updateHeartPreview(simd: SIMD3<Float>) {
        if let cameraAnchor = cameraAnchor {
            if cameraAnchor.children.count == 0 {
                heart = Heart()
                cameraAnchor.addChild(heart!)
                cameraAnchor.position = SIMD3(SCNVector3(simd.x * 50, simd.y * 50, simd.z * 50))
            } else {
                cameraAnchor.position = SIMD3(SCNVector3(simd.x * 50, simd.y * 50, simd.z * 50))
//                print("X좌표: \(simd.x * 50)")
//                print("Y좌표: \(simd.y * 50)")
                print(count)
                
                if simd.x*50 > preX - 0.03 &&
                    simd.x*50 < preX + 0.03 &&
                    simd.y*50 > preY - 0.03 &&
                    simd.y*50 < preY + 0.03 {
                    count += 1
                } else {
                    count = 0
                    preX = simd.x*50
                    preY = simd.y*50
                }
                
                if count > 20 {
                    count = 0
                    fixHeart()
                }
                
                // 위치가 바뀌지않았어도 몇 번 이상 background가 나올 경우, count reset.
            }
        } else {
            addHeartPreview()
        }
    }
    
    func fixHeart() {
        guard let heart = heart, heart.isEnabled else { return }
        let heartWorldTransform = heart.transformMatrix(relativeTo: nil)
        heart.anchor?.reanchor(.world(transform: heartWorldTransform))
        self.heart = nil
        self.cameraAnchor = nil
    }
}

/*
 실제 1m = 화면에서의 200mm라 할 때.
 100mm 이동하면 50cm이동하는 수식.
 */

extension ViewController: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
    
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
            guard let handPoses = handPoseRequest.results, !handPoses.isEmpty else { return }
            
            let handObservation = handPoses.first // 5. One hand
            
            guard let keypointsMultiArray = try? handObservation?.keypointsMultiArray() else { fatalError() }
            
            // 6. Model Operation
            let handPosePrediction = try? model?.prediction(poses: keypointsMultiArray)
            
            // 7. confidence
            let confidence = handPosePrediction?.labelProbabilities[handPosePrediction?.label ?? "nil이다."]
            
            guard let label = handPosePrediction?.label,
                  let confidence = confidence else { return }
            
            if label == "heart" && confidence > 0.8 {
                if let fingerPoint = try? handObservation?.recognizedPoint(.thumbTip) {
                    // Question. x, y 왜 바뀐 느낌이지.
                    // x는 위일수록 0, 아래일수록 1. y는 왼일수록 0, 우일수록 1.\
                    let heartFingerPostion = CGPoint(x: fingerPoint.y * arView.bounds.width,
                                                     y: fingerPoint.x * arView.bounds.height)
                    let simd = arView.unproject(heartFingerPostion, viewport: arView.bounds)!
                    updateHeartPreview(simd: simd)
                }
                backCount = 0
            } else {
                guard let cameraAnchor = cameraAnchor else { return }
                cameraAnchor.children.removeAll()
                backCount += 1
                if backCount > 7 {
                    count = 0
                }
            }
        }
    }
}
